#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
STATUS_BIN="$ROOT/ops/plugins/domains/mint/bin/mint-money-trace-status"

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
SCENARIO_FILE="$TMP_ROOT/scenario.json"

start_server() {
  python3 - <<'PY' "$SCENARIO_FILE" "$PORT_FILE" &
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

scenario_path, port_path = sys.argv[1], sys.argv[2]

with open(scenario_path, "r", encoding="utf-8") as handle:
    scenario = json.load(handle)

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def _send(self, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path == "/api/v1/finance/reconcile":
            self._send(scenario["finance"])
            return
        self.send_response(404)
        self.end_headers()

    def do_GET(self):
        if self.path.startswith("/api/v1/shipping/history"):
            self._send(scenario["shipping"])
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
    [[ -s "$PORT_FILE" ]] && return 0
    sleep 0.1
  done
  fail "mock server did not start"
  exit 1
}

echo "mint money trace status tests"
echo "════════════════════════════"

cat > "$SCENARIO_FILE" <<'EOF'
{
  "finance": {
    "status": "CLEAN",
    "orphaned_firefly": 0,
    "failed_exhausted": 0,
    "payment_trace": {
      "checked": 2,
      "converged": 2,
      "drifted": 0,
      "skipped_cancelled": 1
    }
  },
  "shipping": {
    "labels": [
      {"refund_status": "refunded"},
      {"refund_status": null}
    ]
  }
}
EOF
start_server
BASE_URL="http://127.0.0.1:$(cat "$PORT_FILE")"

ok_brief="$(
  MINT_FINANCE_ADAPTER_BASE_URL="$BASE_URL" \
  MINT_FINANCE_ADAPTER_API_KEY="test-key" \
  MINT_SHIPPING_BASE_URL="$BASE_URL" \
  MINT_SHIPPING_API_KEY="test-key" \
  "$STATUS_BIN" --brief
)"
assert_contains "$ok_brief" "status=ok" "brief output reports ok"
assert_contains "$ok_brief" "failed_exhausted=0" "brief output reports zero exhausted finance rows"
assert_contains "$ok_brief" "payment_converged=2" "brief output reports converged payment trace"
assert_contains "$ok_brief" "shipping_settled=1" "brief output reports settled shipping refund"

ok_json="$(
  MINT_FINANCE_ADAPTER_BASE_URL="$BASE_URL" \
  MINT_FINANCE_ADAPTER_API_KEY="test-key" \
  MINT_SHIPPING_BASE_URL="$BASE_URL" \
  MINT_SHIPPING_API_KEY="test-key" \
  "$STATUS_BIN" --json
)"
assert_contains "$ok_json" "\"status\":\"ok\"" "json output reports ok"
assert_contains "$ok_json" "\"failed_exhausted\":0" "json output reports zero exhausted finance rows"
assert_contains "$ok_json" "\"drifted\":0" "json output reports zero payment drift"

kill "$SERVER_PID" >/dev/null 2>&1 || true
wait "$SERVER_PID" 2>/dev/null || true
unset SERVER_PID
rm -f "$PORT_FILE"

cat > "$SCENARIO_FILE" <<'EOF'
{
  "finance": {
    "status": "DRIFT_DETECTED",
    "orphaned_firefly": 1,
    "failed_exhausted": 5,
    "payment_trace": {
      "checked": 1,
      "converged": 0,
      "drifted": 1,
      "skipped_cancelled": 0
    }
  },
  "shipping": {
    "labels": [
      {"refund_status": "submitted"}
    ]
  }
}
EOF
start_server
BASE_URL="http://127.0.0.1:$(cat "$PORT_FILE")"

fail_brief="$(
  MINT_FINANCE_ADAPTER_BASE_URL="$BASE_URL" \
  MINT_FINANCE_ADAPTER_API_KEY="test-key" \
  MINT_SHIPPING_BASE_URL="$BASE_URL" \
  MINT_SHIPPING_API_KEY="test-key" \
  "$STATUS_BIN" --brief
)"
assert_contains "$fail_brief" "status=fail" "brief output fails on drift"
assert_contains "$fail_brief" "failed_exhausted=5" "brief output reports exhausted finance rows"
assert_contains "$fail_brief" "payment_drifted=1" "brief output reports payment drift"
assert_contains "$fail_brief" "shipping_submitted=1" "brief output reports submitted shipping refunds"

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS: $PASS"
  exit 0
fi

echo "FAIL: $FAIL assertions failed" >&2
exit 1
