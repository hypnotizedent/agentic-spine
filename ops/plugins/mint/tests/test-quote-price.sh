#!/usr/bin/env bash
# test-quote-price.sh - Validate packet-driven pricing against a local mock estimator

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PRICE="$SPINE_ROOT/ops/plugins/mint/bin/quote-price"
QUOTE_RENDER="$SPINE_ROOT/ops/plugins/mint/bin/quote-render"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/mint/tests/fixtures/quote-price"
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
cp "$FIXTURES_DIR/ready-warning-shipping.packet.yaml" "$PACKETS_DIR/quote_packet_price-ready-warning.yaml"
cp "$FIXTURES_DIR/blocked-missing-method.packet.yaml" "$PACKETS_DIR/quote_packet_price-blocked-missing-method.yaml"
cp "$FIXTURES_DIR/blocked-clarification.packet.yaml" "$PACKETS_DIR/quote_packet_price-blocked-clarification.yaml"

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
        total_amount = qty * 1694
        response = {
            "estimate_id": f"estimate-{qty}",
            "requested_at_utc": payload.get("request_timestamp_utc"),
            "pricing_version": "mock-pricing-v1",
            "pricing_authority_path": "job_estimator",
            "pricing_source": "contract_table",
            "normalized_request": payload,
            "line_items": [
                {
                    "code": "blank",
                    "description": "Blank garment",
                    "unit_amount": 925,
                    "quantity": qty,
                    "total_amount": qty * 925,
                    "source": "contract_table",
                },
                {
                    "code": "decoration",
                    "description": "Decoration charge",
                    "unit_amount": 769,
                    "quantity": qty,
                    "total_amount": qty * 769,
                    "source": "contract_table",
                },
            ],
            "pricing_trace": [
                {
                    "code": "blank",
                    "description": "Blank garment",
                    "formula": "qty * base_blank",
                    "direction": "increase",
                    "unit_delta_cents": 925,
                    "quantity": qty,
                    "total_delta_cents": qty * 925,
                    "source": "contract_table",
                }
            ],
            "customer_explanation": {
                "size_tier_label": payload.get("size_tier_label", "standard_print"),
                "size_bounds_inches": {"min_max_side_in": 0, "max_max_side_in": 12},
                "setup_mode": payload.get("setup_mode", "new_setup"),
                "rationale": ["mock pricing response"],
            },
            "margin": {"percent": 42},
            "taxes": {"total_amount": 0},
            "receipt": {
                "receipt_id": f"receipt-{qty}",
                "receipt_generated_at_utc": payload.get("request_timestamp_utc"),
                "normalized_input_fingerprint": "mock-input",
                "output_fingerprint": "mock-output",
                "total_amount": total_amount,
                "version_snapshot": {
                    "pricing_authority_version": "mock-v1",
                    "rate_table_version": "mock-v1",
                    "screen_print_variant_table_version": "mock-v1",
                    "method_decision_table_version": "mock-v1",
                    "screen_print_rate_table_version": "mock-v1",
                    "embroidery_rate_table_version": "mock-v1",
                    "laser_etching_rate_table_version": "mock-v1",
                    "transfers_rate_table_version": "mock-v1",
                    "extras_rate_table_version": "mock-v1",
                },
            },
            "turnaround_window": {"min_days": 7, "max_days": 9},
            "confidence": {"level": "high", "score": 0.98},
            "integration_handoff": {},
            "burn_in_readiness": {"ready": True},
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

section "Price a packet with warning-only shipping posture"
price_output="$(
  PRICING_BASE_URL="http://127.0.0.1:${PORT}" \
  PRICING_API_KEY="test-pricing-key" \
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_PRICE" price-ready-warning
)"
ready_packet="$PACKETS_DIR/quote_packet_price-ready-warning.yaml"
[[ -f "$ready_packet" ]] || fail "price-ready-warning packet missing after pricing"
[[ "$(yq '.state' "$ready_packet")" == "drafting" ]] || fail "price-ready-warning must return to drafting after pricing"
[[ "$(yq '.pricing_snapshot.pricing_state' "$ready_packet")" == "completed" ]] || fail "pricing state must be completed"
[[ "$(yq '.pricing_snapshot.line_item_prices | length' "$ready_packet")" == "1" ]] || fail "completed pricing must persist one line_item_prices entry"
[[ "$(yq '.pricing_snapshot.calculated_totals.total' "$ready_packet")" == "1219.68" ]] || fail "mock total must persist in calculated_totals"
[[ "$(yq '.quote_draft_ref' "$ready_packet")" == "null" ]] || fail "stale quote_draft_ref must be cleared after pricing"
[[ "$(yq '.customer_message_draft' "$ready_packet")" == "null" ]] || fail "review draft message must be cleared so render can regenerate it"
[[ "$(request_count)" == "1" ]] || fail "pricing service should be called exactly once for the ready packet"
grep -Fq "pricing_state: completed" <<<"$price_output" || fail "pricing output must report completion"
pass "quote-price persists real pricing_snapshot evidence and invalidates stale drafts"

section "Render can now promote the priced packet to ready_for_review"
render_output="$(
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  "$QUOTE_RENDER" price-ready-warning
)"
[[ "$(yq '.state' "$ready_packet")" == "ready_for_review" ]] || fail "priced packet must become ready_for_review after render"
[[ "$(yq '.quote_draft_ref.draft_type' "$ready_packet")" == "inline" ]] || fail "render must rebuild quote_draft_ref"
grep -Fq -- "-> ready_for_review" <<<"$render_output" || fail "render output must report the transition to ready_for_review"
pass "quote-render consumes the persisted pricing snapshot and moves the packet to review"

section "Price blocks honestly when method-specific estimator inputs are missing"
before_missing_method="$(request_count)"
blocked_method_output="$(
  PRICING_BASE_URL="http://127.0.0.1:${PORT}" \
  PRICING_API_KEY="test-pricing-key" \
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_PRICE" price-blocked-missing-method
)"
blocked_method_packet="$PACKETS_DIR/quote_packet_price-blocked-missing-method.yaml"
[[ "$(yq '.state' "$blocked_method_packet")" == "needs_input" ]] || fail "missing-method packet must stay in needs_input"
[[ "$(yq '.pricing_snapshot.pricing_state' "$blocked_method_packet")" == "blocked_insufficient_inputs" ]] || fail "missing-method packet must record blocked_insufficient_inputs"
[[ "$(yq '.open_gaps | map(select(.gap_type == "decoration_unresolved")) | length' "$blocked_method_packet")" == "1" ]] || fail "missing-method packet must emit decoration_unresolved"
[[ "$(request_count)" == "$before_missing_method" ]] || fail "estimator must not be called when canonical pricing fields are missing"
grep -Fq "method variant" "$blocked_method_packet" || fail "decoration gap must mention the missing method variant"
pass "quote-price refuses to invent method-specific pricing fields"

section "Price blocks on existing clarification gaps without overwriting the ask"
before_clarification="$(request_count)"
blocked_clarification_output="$(
  PRICING_BASE_URL="http://127.0.0.1:${PORT}" \
  PRICING_API_KEY="test-pricing-key" \
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_PRICE" price-blocked-clarification
)"
blocked_clarification_packet="$PACKETS_DIR/quote_packet_price-blocked-clarification.yaml"
[[ "$(yq '.state' "$blocked_clarification_packet")" == "needs_input" ]] || fail "clarification-blocked packet must remain needs_input"
[[ "$(yq '.pricing_snapshot.pricing_state' "$blocked_clarification_packet")" == "blocked_insufficient_inputs" ]] || fail "clarification-blocked packet must remain blocked_insufficient_inputs"
[[ "$(request_count)" == "$before_clarification" ]] || fail "estimator must not be called when blocking clarification remains"
grep -Fq "Please confirm whether the hoodie quantity should stay at 24" "$blocked_clarification_packet" || fail "clarification draft must be preserved when pricing blocks"
grep -Fq "Customer must confirm whether this is the updated hoodie quantity" <<<"$blocked_clarification_output" || fail "pricing output must report the blocking clarification"
pass "quote-price respects blocking clarification instead of pricing through it"

section "Summary"
echo "Packet pricing checks passed"
