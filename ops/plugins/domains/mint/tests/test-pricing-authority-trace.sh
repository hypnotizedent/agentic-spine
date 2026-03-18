#!/usr/bin/env bash
# test-pricing-authority-trace.sh - Validate governed pricing authority trace capability bridge

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

AUTH_TRACE="$SPINE_ROOT/ops/plugins/domains/mint/bin/pricing-authority-trace"
TMP_ROOT="$(mktemp -d)"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

PORT="$(python3 - <<'PY'
import socket

sock = socket.socket()
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1])
sock.close()
PY
)"

python3 -u - "$PORT" <<'PY' &
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(sys.argv[1])


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/api/v1/pricing/authority-trace":
            self.send_response(404)
            self.end_headers()
            return

        response = {
            "generated_at_utc": "2026-03-17T20:00:00.000Z",
            "pricing_authority_version": "pricing-authority-v1",
            "workbook": {
                "sha256": "abc123",
                "source_generation_mode": "local_workbook_path"
            },
            "methods": {
                "screen_print": {
                    "authority_mode": {
                        "exact": "workbook_exact",
                        "overlay": "workbook_plus_variant_delta",
                        "unsupported": "authority_gap"
                    },
                    "disconnects": [
                        "A5 gap",
                        "3 color gap"
                    ]
                },
                "embroidery": {
                    "authority_mode": {
                        "exact": "contract_policy_from_workbook_ranges",
                        "fallback": "default_policy"
                    },
                    "disconnects": [
                        "stitch band policy"
                    ]
                }
            },
            "boringness_blockers": [
                "workbook path is local",
                "non-screen-print methods are policy based"
            ]
        }

        encoded = json.dumps(response).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, *_args):
        return


HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
SERVER_PID=$!
sleep 1

section "Authority trace returns text summary through the governed bridge"
summary_output="$(
  PRICING_BASE_URL="http://127.0.0.1:${PORT}" \
  PRICING_API_KEY="test-pricing-key" \
  "$AUTH_TRACE"
)"
grep -Fq "method_count: 2" <<<"$summary_output" || fail "text summary should report method count"
grep -Fq "method: screen_print disconnect_count=2" <<<"$summary_output" || fail "text summary should report screen_print disconnect count"
pass "pricing-authority-trace prints governed summary"

section "Authority trace supports method focus and structured JSON"
json_output="$(
  PRICING_BASE_URL="http://127.0.0.1:${PORT}" \
  PRICING_API_KEY="test-pricing-key" \
  "$AUTH_TRACE" --method screen_print --json
)"
[[ "$(printf '%s' "$json_output" | jq -r '.capability')" == "mint.pricing.authority_trace" ]] || fail "json output should expose capability name"
[[ "$(printf '%s' "$json_output" | jq -r '.data.selected_method')" == "screen_print" ]] || fail "json output should preserve selected method"
[[ "$(printf '%s' "$json_output" | jq -r '.data.method.disconnects[1]')" == "3 color gap" ]] || fail "json output should preserve method disconnects"
pass "pricing-authority-trace supports governed method focus"

section "Summary"
echo "Authority trace capability checks passed"
