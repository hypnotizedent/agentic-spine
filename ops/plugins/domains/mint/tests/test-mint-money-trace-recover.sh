#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "${ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
BIN="$ROOT/ops/plugins/domains/mint/bin/mint-money-trace-recover"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (missing: $needle)"
  fi
}

TMP_ROOT="$(mktemp -d)"
cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

PORT_FILE="$TMP_ROOT/port"
REQUEST_FILE="$TMP_ROOT/request.txt"

python3 - <<'PY' "$PORT_FILE" "$REQUEST_FILE" &
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port_path, request_path = sys.argv[1], sys.argv[2]

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def do_POST(self):
        with open(request_path, "w", encoding="utf-8") as handle:
            handle.write(self.path)
        if self.path.startswith("/api/v1/finance/reconcile/recover-exhausted"):
            payload = {
                "dry_run": "dry_run=1" in self.path,
                "match_error": "Unauthenticated",
                "candidate_count": 3,
                "reset_count": 0 if "dry_run=1" in self.path else 3,
                "candidates": [{"id": "row-1"}],
                "reconciliation": None if "dry_run=1" in self.path else {
                    "status": "CLEAN",
                    "failed_exhausted": 0,
                    "orphaned_firefly": 0
                }
            }
            body = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(404)
        self.end_headers()

server = HTTPServer(("127.0.0.1", 0), Handler)
with open(port_path, "w", encoding="utf-8") as handle:
    handle.write(str(server.server_port))
server.serve_forever()
PY
SERVER_PID=$!

for _ in $(seq 1 50); do
  [[ -s "$PORT_FILE" ]] && break
  sleep 0.1
done

BASE_URL="http://127.0.0.1:$(cat "$PORT_FILE")"

dry_brief="$(
  MINT_FINANCE_ADAPTER_BASE_URL="$BASE_URL" \
  MINT_FINANCE_ADAPTER_API_KEY="test-key" \
  "$BIN" --dry-run --brief
)"
assert_contains "$dry_brief" "dry_run=1" "brief output reports dry run"
assert_contains "$dry_brief" "candidates=3" "brief output reports candidate count"
assert_contains "$dry_brief" "finance=NONE" "brief output reports no reconciliation in dry run"
assert_contains "$(cat "$REQUEST_FILE")" "dry_run=1" "request includes dry_run query"

live_json="$(
  MINT_FINANCE_ADAPTER_BASE_URL="$BASE_URL" \
  MINT_FINANCE_ADAPTER_API_KEY="test-key" \
  "$BIN" --json
)"
if jq -e '.reset_count == 3' >/dev/null <<<"$live_json"; then
  pass "json output reports reset count"
else
  fail "json output reports reset count"
fi
if jq -e '.reconciliation.status == "CLEAN"' >/dev/null <<<"$live_json"; then
  pass "json output reports clean post-recovery reconcile"
else
  fail "json output reports clean post-recovery reconcile"
fi
assert_contains "$(cat "$REQUEST_FILE")" "match_error=Unauthenticated" "request includes default auth error filter"

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS: $PASS"
  exit 0
fi

echo "FAIL: $FAIL assertions failed" >&2
exit 1
