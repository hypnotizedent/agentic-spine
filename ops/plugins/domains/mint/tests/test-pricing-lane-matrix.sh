#!/usr/bin/env bash
# test-pricing-lane-matrix.sh - Validate governed lane-matrix pricing capability bridge

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

LANE_MATRIX="$SPINE_ROOT/ops/plugins/domains/mint/bin/pricing-lane-matrix"
TMP_ROOT="$(mktemp -d)"
REQUEST_LOG="$TMP_ROOT/lane-matrix-requests.log"
PAYLOAD_FILE="$TMP_ROOT/lane-matrix-payload.json"

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

cat >"$PAYLOAD_FILE" <<'EOF'
{
  "customer_ref": "lane-matrix-test",
  "supplier_source": "sanmar",
  "blanks_cost": 3.85,
  "garment_markup_multiplier": 1.3,
  "garment_color_tone": "dark",
  "garment_material": "cotton",
  "qty_options": [10, 50],
  "setup_mode_options": ["new_setup"],
  "lanes": [
    {
      "lane_id": "front",
      "item_type": "screen_print",
      "placement_label": "front",
      "colors": 1,
      "color_count": 1,
      "screen_print_size_key": "A4",
      "method_variant": "standard",
      "underbase_needed": true,
      "locations": ["front"]
    },
    {
      "lane_id": "sleeve",
      "item_type": "screen_print",
      "placement_label": "sleeve",
      "colors": 1,
      "color_count": 1,
      "screen_print_size_key": "A6",
      "method_variant": "standard",
      "underbase_needed": true,
      "locations": ["sleeve"]
    }
  ]
}
EOF

PORT="$(python3 - <<'PY'
import socket

sock = socket.socket()
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1])
sock.close()
PY
)"

python3 -u - "$PORT" "$REQUEST_LOG" <<'PY' &
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(sys.argv[1])
request_log = sys.argv[2]


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/api/v1/pricing/lane-matrix":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8")
        payload = json.loads(raw or "{}")
        with open(request_log, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(payload, sort_keys=True) + "\n")

        response = {
            "questions": [],
            "recommendations": [
                {"lane_id": "front", "recommended_screen_print_size_key": "A4"},
                {"lane_id": "sleeve", "recommended_screen_print_size_key": "A6"}
            ],
            "garment_markup_multiplier": payload.get("garment_markup_multiplier", 1.3),
            "scenarios": [
                {
                    "scenario_id": "qty-10__setup-new_setup",
                    "qty": 10,
                    "setup_mode": "new_setup",
                    "blank_customer_unit_amount": 5.005,
                    "customer_unit_amount": 12.455,
                    "lanes": [
                        {
                            "lane_id": "front",
                            "customer_unit_amount": 5.5,
                            "receipt_id": "rcpt-front-10",
                            "pricing_key_type": "screen_print_workbook_size",
                            "pricing_key": "A4"
                        },
                        {
                            "lane_id": "sleeve",
                            "customer_unit_amount": 1.95,
                            "receipt_id": "rcpt-sleeve-10",
                            "pricing_key_type": "screen_print_workbook_size",
                            "pricing_key": "A6"
                        }
                    ]
                },
                {
                    "scenario_id": "qty-50__setup-new_setup",
                    "qty": 50,
                    "setup_mode": "new_setup",
                    "blank_customer_unit_amount": 5.005,
                    "customer_unit_amount": 9.875,
                    "lanes": [
                        {
                            "lane_id": "front",
                            "customer_unit_amount": 3.95,
                            "receipt_id": "rcpt-front-50",
                            "pricing_key_type": "screen_print_workbook_size",
                            "pricing_key": "A4"
                        },
                        {
                            "lane_id": "sleeve",
                            "customer_unit_amount": 0.92,
                            "receipt_id": "rcpt-sleeve-50",
                            "pricing_key_type": "screen_print_workbook_size",
                            "pricing_key": "A6"
                        }
                    ]
                }
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

request_count() {
  if [[ ! -f "$REQUEST_LOG" ]]; then
    echo 0
    return
  fi
  wc -l < "$REQUEST_LOG" | tr -d ' '
}

section "Lane matrix returns text summary through the governed bridge"
summary_output="$(
  PRICING_BASE_URL="http://127.0.0.1:${PORT}" \
  PRICING_API_KEY="test-pricing-key" \
  "$LANE_MATRIX" --payload-file "$PAYLOAD_FILE"
)"
[[ "$(request_count)" == "1" ]] || fail "lane-matrix service should be called once"
grep -Fq "scenario_count: 2" <<<"$summary_output" || fail "text summary should report scenario count"
grep -Fq "lane: scenario_id=qty-10__setup-new_setup lane_id=front customer_unit_amount=5.5 receipt_id=rcpt-front-10 pricing_key=A4" <<<"$summary_output" || fail "text summary should report the front lane receipt"
pass "pricing-lane-matrix prints governed per-scenario lane receipts"

section "Lane matrix emits structured JSON and resolves base URL through services.health + ssh fallback"
FALLBACK_SPINE="$TMP_ROOT/fallback-spine"
mkdir -p "$FALLBACK_SPINE/ops/bindings"
cat >"$FALLBACK_SPINE/ops/bindings/services.health.yaml" <<EOF
endpoints:
  - id: pricing-v2
    host: mint-apps
    url: http://192.0.2.10:${PORT}/health
EOF
cat >"$FALLBACK_SPINE/ops/bindings/ssh.targets.yaml" <<'EOF'
ssh:
  targets:
    - id: mint-apps
      host: 192.0.2.10
      tailscale_ip: 127.0.0.1
      access_policy: lan_first
EOF

json_output="$(
  SPINE_ROOT="$FALLBACK_SPINE" \
  PRICING_API_KEY="test-pricing-key" \
  "$LANE_MATRIX" --payload-file "$PAYLOAD_FILE" --json
)"
[[ "$(printf '%s' "$json_output" | jq -r '.capability')" == "mint.pricing.lane_matrix" ]] || fail "json output should expose capability name"
[[ "$(printf '%s' "$json_output" | jq -r '.pricing_base_url')" == "http://127.0.0.1:${PORT}" ]] || fail "lane-matrix should resolve pricing base URL through services.health + ssh fallback"
[[ "$(printf '%s' "$json_output" | jq -r '.data.scenarios[0].lanes[1].receipt_id')" == "rcpt-sleeve-10" ]] || fail "json output should preserve lane receipts"
pass "pricing-lane-matrix resolves pricing service canonically and emits structured JSON"

section "Summary"
echo "Lane-matrix capability checks passed"
