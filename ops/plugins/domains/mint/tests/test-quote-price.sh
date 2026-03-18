#!/usr/bin/env bash
# test-quote-price.sh - Validate packet-driven pricing against a local mock estimator

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PRICE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-price"
QUOTE_RENDER="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-render"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-price"
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
        if self.path != "/api/v1/pricing/lane-matrix":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8")
        payload = json.loads(raw or "{}")
        with open(request_log, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(payload, sort_keys=True) + "\n")

        qty = int((payload.get("qty_options") or [0])[0])
        response = {
            "questions": [],
            "recommendations": [
                {"lane_id": "li-price-1__front__1", "recommended_screen_print_size_key": "A4"},
                {"lane_id": "li-price-1__back__2", "recommended_screen_print_size_key": "A4"},
            ],
            "garment_markup_multiplier": 1.3,
            "scenarios": [
                {
                    "scenario_id": f"qty-{qty}__setup-new_setup",
                    "qty": qty,
                    "setup_mode": "new_setup",
                    "blank_customer_unit_amount": 5.53,
                    "customer_unit_amount": 16.94,
                    "lanes": [
                        {
                            "lane_id": "li-price-1__front__1",
                            "placement_label": "front",
                            "customer_unit_amount": 7.41,
                            "production_unit_amount": 6.8,
                            "setup_total_amount": 25.0,
                            "underbase_total_amount": 0.0,
                            "receipt_id": f"receipt-{qty}-front",
                            "pricing_key_type": "screen_print_workbook_size",
                            "pricing_key": "A4",
                            "screen_print_size_key": "A4",
                            "requested_method_variant": "standard",
                            "workbook_base_variant": "standard",
                            "variant_pricing_mode": "workbook_exact",
                        },
                        {
                            "lane_id": "li-price-1__back__2",
                            "placement_label": "back",
                            "customer_unit_amount": 4.0,
                            "production_unit_amount": 3.55,
                            "setup_total_amount": 0.0,
                            "underbase_total_amount": 0.0,
                            "receipt_id": f"receipt-{qty}-back",
                            "pricing_key_type": "screen_print_workbook_size",
                            "pricing_key": "A4",
                            "screen_print_size_key": "A4",
                            "requested_method_variant": "standard",
                            "workbook_base_variant": "standard",
                            "variant_pricing_mode": "workbook_exact",
                        },
                    ],
                }
            ],
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
[[ "$(yq '.pricing_snapshot.line_item_prices[0].pricing_breakdown.wholesale_blank_unit' "$ready_packet")" == "4.25" ]] || fail "pricing breakdown must expose wholesale blank"
[[ "$(yq '.pricing_snapshot.line_item_prices[0].pricing_breakdown.garment_markup_unit' "$ready_packet")" == "1.28" ]] || fail "pricing breakdown must expose garment markup"
[[ "$(yq '.pricing_snapshot.line_item_prices[0].pricing_breakdown.imprint_unit' "$ready_packet")" == "11.41" ]] || fail "pricing breakdown must expose imprint unit"
[[ "$(yq '.pricing_snapshot.line_item_prices[0].unit_price' "$ready_packet")" == "16.94" ]] || fail "customer unit price must reflect markup plus imprint"
[[ "$(yq '.pricing_snapshot.decoration_prices[0].lane_prices | length' "$ready_packet")" == "2" ]] || fail "lane-matrix pricing must persist separate lane proofs"
[[ "$(yq '.pricing_snapshot.decoration_prices[0].lane_prices[0].receipt_id' "$ready_packet")" == "receipt-72-front" ]] || fail "lane proof must persist the front receipt id"
[[ "$(yq '.quote_draft_ref' "$ready_packet")" == "null" ]] || fail "stale quote_draft_ref must be cleared after pricing"
[[ "$(yq '.customer_message_draft' "$ready_packet")" == "null" ]] || fail "review draft message must be cleared so render can regenerate it"
[[ "$(yq '.quote_readiness.state' "$ready_packet")" == "quote_packet_in_progress" ]] || fail "priced packet should report in-progress send readiness before render"
[[ "$(yq '.quote_readiness.build_basis' "$ready_packet")" == "exact_pricing_ready" ]] || fail "completed pricing must upgrade build basis to exact_pricing_ready"
[[ "$(yq '.quote_readiness.next_step' "$ready_packet")" == "render_quote_review" ]] || fail "priced packet should point the next step at render"
[[ "$(request_count)" == "1" ]] || fail "pricing service should be called exactly once for the ready packet"
[[ "$(jq -r '.lanes | length' < "$REQUEST_LOG")" == "2" ]] || fail "lane-matrix request should split multi-location pricing into two lanes"
grep -Fq "pricing_state: completed" <<<"$price_output" || fail "pricing output must report completion"
pass "quote-price persists real lane-based pricing proof and invalidates stale drafts"

section "Price honors services.health plus ssh fallback when PRICING_BASE_URL is unset"
FALLBACK_SPINE="$TMP_ROOT/fallback-spine"
mkdir -p "$FALLBACK_SPINE/ops/bindings"
cat > "$FALLBACK_SPINE/ops/bindings/services.health.yaml" <<EOF
endpoints:
  - id: pricing-v2
    host: mint-apps
    url: http://192.0.2.10:${PORT}/health
EOF
cat > "$FALLBACK_SPINE/ops/bindings/ssh.targets.yaml" <<'EOF'
ssh:
  targets:
    - id: mint-apps
      host: 192.0.2.10
      tailscale_ip: 127.0.0.1
      access_policy: lan_first
EOF
cp "$FIXTURES_DIR/ready-warning-shipping.packet.yaml" "$PACKETS_DIR/quote_packet_price-ready-warning-fallback.yaml"
fallback_price_output="$(
  SPINE_ROOT="$FALLBACK_SPINE" \
  PRICING_API_KEY="test-pricing-key" \
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_PRICE" price-ready-warning-fallback
)"
fallback_packet="$PACKETS_DIR/quote_packet_price-ready-warning-fallback.yaml"
[[ "$(yq '.pricing_snapshot.pricing_state' "$fallback_packet")" == "completed" ]] || fail "pricing fallback packet must complete through the resolved host"
grep -Fq "pricing_state: completed" <<<"$fallback_price_output" || fail "pricing fallback output must report completion"
pass "quote-price resolves the pricing service through the canonical services.health + ssh fallback path"

section "Render can now promote the priced packet to ready_for_review"
render_output="$(
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  "$QUOTE_RENDER" price-ready-warning
)"
[[ "$(yq '.state' "$ready_packet")" == "ready_for_review" ]] || fail "priced packet must become ready_for_review after render"
[[ "$(yq '.quote_draft_ref.draft_type' "$ready_packet")" == "inline" ]] || fail "render must rebuild quote_draft_ref"
[[ "$(yq '.quote_readiness.state' "$ready_packet")" == "ready_for_operator_review" ]] || fail "rendered packet should be ready for operator review"
[[ "$(yq '.quote_readiness.next_step' "$ready_packet")" == "operator_review" ]] || fail "rendered packet should wait on operator review"
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
