#!/usr/bin/env bash
# test-quote-estimate.sh - Validate packet-driven quote estimation before exact pricing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

QUOTE_ESTIMATE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-estimate"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-estimate"
POLICY_CONTRACT="$SPINE_ROOT/ops/bindings/mint.quote.packet.estimate.policy.contract.yaml"
TMP_ROOT="$(mktemp -d)"
PACKETS_DIR="$TMP_ROOT/quote-packets"
INDEX_FILE="$TMP_ROOT/quote-packets-index.yaml"
REQUEST_LOG="$TMP_ROOT/pricing-requests.log"

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

mkdir -p "$PACKETS_DIR"
cp "$FIXTURES_DIR/estimate-screenprint.packet.yaml" "$PACKETS_DIR/quote_packet_estimate-screenprint.yaml"
cp "$FIXTURES_DIR/estimate-missing-quantity.packet.yaml" "$PACKETS_DIR/quote_packet_estimate-missing-quantity.yaml"

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
        if self.path != "/api/v1/pricing/estimate":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8")
        payload = json.loads(raw or "{}")
        with open(request_log, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(payload, sort_keys=True) + "\n")

        qty = int(payload.get("qty", 0))
        total_amount = round(qty * 18.40, 2)
        response = {
            "estimate_id": f"quote-estimate-{qty}",
            "requested_at_utc": payload.get("request_timestamp_utc"),
            "pricing_authority_path": "job_estimator",
            "pricing_source": "contract_table",
            "line_items": [
                {
                    "code": "blank",
                    "description": "Blank garment",
                    "unit_amount": 10.25,
                    "quantity": qty,
                    "total_amount": round(qty * 10.25, 2),
                    "source": "contract_table",
                },
                {
                    "code": "decoration",
                    "description": "Decoration charge",
                    "unit_amount": 8.15,
                    "quantity": qty,
                    "total_amount": round(qty * 8.15, 2),
                    "source": "contract_table",
                },
            ],
            "pricing_trace": [],
            "customer_explanation": {
                "size_tier_label": payload.get("size_tier_label", "standard_print"),
                "setup_mode": payload.get("setup_mode", "new_setup"),
                "rationale": ["mock quote-estimate response"],
            },
            "confidence": {"level": "high", "score": 0.97},
            "receipt": {
                "receipt_id": f"quote-estimate-receipt-{qty}",
                "receipt_generated_at_utc": payload.get("request_timestamp_utc"),
                "total_amount": total_amount,
            },
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

section "Estimate a sourced packet that is not exact-pricing ready yet"
estimate_output="$(
  PRICING_BASE_URL="http://127.0.0.1:${PORT}" \
  PRICING_API_KEY="test-pricing-key" \
  MINT_QUOTE_PACKET_ESTIMATE_POLICY_CONTRACT="$POLICY_CONTRACT" \
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_ESTIMATE" estimate-screenprint
)"
ready_packet="$PACKETS_DIR/quote_packet_estimate-screenprint.yaml"
[[ -f "$ready_packet" ]] || fail "estimate-screenprint packet missing after estimate"
[[ "$(yq '.estimate_snapshot.estimate_state' "$ready_packet")" == "completed" ]] || fail "estimate should complete for a sourced quote-safe packet"
[[ "$(yq '.estimate_snapshot.line_item_estimates | length' "$ready_packet")" == "1" ]] || fail "estimate snapshot should persist one line item"
[[ "$(yq '.estimate_snapshot.line_item_estimates[0].recommended_method' "$ready_packet")" == "screen_print" ]] || fail "estimate should recommend screen_print"
[[ "$(yq '.estimate_snapshot.line_item_estimates[0].estimate_status' "$ready_packet")" == "production_only_exactness_missing" ]] || fail "estimate should distinguish production-only exactness gaps"
[[ "$(yq '.estimate_snapshot.line_item_estimates[0].quote_safe_now' "$ready_packet")" == "true" ]] || fail "estimate should mark the item quote-safe now"
[[ "$(yq '.estimate_snapshot.line_item_estimates[0].estimated_unit_price' "$ready_packet")" == "18.4" ]] || fail "estimate should persist unit price"
[[ "$(yq '.estimate_snapshot.line_item_estimates[0].estimated_decoration_profile.color_count' "$ready_packet")" == "4" ]] || fail "estimate should infer a complex screen print color count"
[[ "$(yq '.estimate_snapshot.line_item_estimates[0].estimated_decoration_profile.size_tier_label' "$ready_packet")" == "standard_print" ]] || fail "estimate should infer standard print sizing"
[[ "$(yq '.confidence.estimate_confidence' "$ready_packet")" == "medium" || "$(yq '.confidence.estimate_confidence' "$ready_packet")" == "high" ]] || fail "estimate confidence should be surfaced on the packet"
[[ "$(request_count)" == "1" ]] || fail "estimate service should be called exactly once for the ready packet"
grep -Fq "estimate_state: completed" <<<"$estimate_output" || fail "estimate output must report completion"
pass "quote-estimate produces a governed quote-safe estimate before exact pricing is ready"

section "Estimate blocks honestly when core customer truth is still missing"
before_blocked="$(request_count)"
blocked_output="$(
  PRICING_BASE_URL="http://127.0.0.1:${PORT}" \
  PRICING_API_KEY="test-pricing-key" \
  MINT_QUOTE_PACKET_ESTIMATE_POLICY_CONTRACT="$POLICY_CONTRACT" \
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_ESTIMATE" estimate-missing-quantity
)"
blocked_packet="$PACKETS_DIR/quote_packet_estimate-missing-quantity.yaml"
[[ "$(yq '.estimate_snapshot.estimate_state' "$blocked_packet")" == "blocked_insufficient_inputs" ]] || fail "estimate should stay blocked when quantity is missing"
[[ "$(yq '.estimate_snapshot.line_item_estimates[0].estimate_status' "$blocked_packet")" == "clarification_needed" ]] || fail "missing quantity should remain clarification_needed"
[[ "$(yq '.estimate_snapshot.line_item_estimates[0].quote_safe_now' "$blocked_packet")" == "false" ]] || fail "blocked item must not be marked quote-safe"
grep -Fq "quantity" "$blocked_packet" || fail "blocked estimate should preserve the missing quantity reason"
[[ "$(request_count)" == "$before_blocked" ]] || fail "estimate service must not be called when quantity is missing"
grep -Fq "still needs clarification" <<<"$blocked_output" || fail "estimate output must report the clarification blocker"
pass "quote-estimate refuses to invent estimates when core customer truth is still missing"

section "Summary"
echo "Quote estimate checks passed"
