#!/usr/bin/env bash
# test-quote-source.sh - Validate packet-driven supplier sourcing and end-to-end quote preparation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PREPARE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-prepare"
QUOTE_SOURCE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-source"
QUOTE_PRICE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-price"
QUOTE_RENDER="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-render"
FLOW_FIXTURES="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-flow-e2e"
SOURCE_FIXTURES="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-source"
TMP_ROOT="$(mktemp -d)"
PACKETS_DIR="$TMP_ROOT/quote-packets"
INDEX_FILE="$TMP_ROOT/quote-packets-index.yaml"
SUPPLIER_REQUEST_LOG="$TMP_ROOT/supplier-requests.log"
PRICING_REQUEST_LOG="$TMP_ROOT/pricing-requests.log"

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
cp "$SOURCE_FIXTURES/blocked-generic.packet.yaml" "$PACKETS_DIR/quote_packet_source-blocked-generic.yaml"

PORT="$(python3 - <<'PY'
import socket

sock = socket.socket()
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1])
sock.close()
PY
)"

python3 -u - "$PORT" "$SUPPLIER_REQUEST_LOG" "$PRICING_REQUEST_LOG" <<'PY' &
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

port = int(sys.argv[1])
supplier_log = sys.argv[2]
pricing_log = sys.argv[3]

SEARCH_RESULTS = {
    "query": "PC54",
    "results": [
        {
            "supplier_code": "ssactive",
            "supplier_sku": "PC54-BLACK-L",
            "style_code": "PC54",
            "brand": "Port & Company",
            "color_name": "Black",
            "size_name": "L",
            "piece_price": 4.25,
            "quantity_available": 120,
            "canonical_style_key": "portcompany:PC54",
            "overlap_rank": 1,
            "inventory_fidelity_score": 0.6,
            "in_stock": True,
        },
        {
            "supplier_code": "ssactive",
            "supplier_sku": "PC54-BLACK-M",
            "style_code": "PC54",
            "brand": "Port & Company",
            "color_name": "Black",
            "size_name": "M",
            "piece_price": 4.25,
            "quantity_available": 90,
            "canonical_style_key": "portcompany:PC54",
            "overlap_rank": 2,
            "inventory_fidelity_score": 0.6,
            "in_stock": True,
        },
    ],
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/v1/suppliers/search":
            params = parse_qs(parsed.query)
            query = params.get("q", [""])[0]
            with open(supplier_log, "a", encoding="utf-8") as fh:
                fh.write(json.dumps({"path": parsed.path, "query": query}, sort_keys=True) + "\n")
            body = SEARCH_RESULTS if query == "PC54" else {"query": query, "results": []}
            encoded = json.dumps(body).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)
            return

        if parsed.path == "/api/v1/suppliers/ssactive/products/PC54-BLACK-L/stock":
            with open(supplier_log, "a", encoding="utf-8") as fh:
                fh.write(json.dumps({"path": parsed.path}, sort_keys=True) + "\n")
            body = {
                "supplier": "ssactive",
                "sku": "PC54-BLACK-L",
                "variants": [
                    {"color": "Black", "size": "M", "quantity_available": 60},
                    {"color": "Black", "size": "L", "quantity_available": 60},
                    {"color": "Black", "size": "XL", "quantity_available": 60},
                ],
                "total_available": 180,
                "warehouse_fidelity": {
                    "level": "aggregate_only",
                    "confidence": "medium",
                    "source": "aggregate_quantity_only",
                },
            }
            encoded = json.dumps(body).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)
            return

        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        if self.path != "/api/v1/pricing/estimate":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
        with open(pricing_log, "a", encoding="utf-8") as fh:
          fh.write(json.dumps(payload, sort_keys=True) + "\n")

        qty = int(payload.get("qty", 0))
        wholesale_blank = 4.25
        imprint_unit = 11.41
        raw_subtotal = round(qty * (wholesale_blank + imprint_unit), 2)
        body = {
            "estimate_id": f"estimate-{qty}",
            "requested_at_utc": payload.get("request_timestamp_utc"),
            "pricing_authority_path": "job_estimator",
            "pricing_source": "contract_table",
            "normalized_request": payload,
            "line_items": [
                {
                    "code": "blanks",
                    "description": "Blank garment",
                    "unit_amount": wholesale_blank,
                    "quantity": qty,
                    "total_amount": round(qty * wholesale_blank, 2),
                    "source": "contract_table",
                },
                {
                    "code": "screenprint",
                    "description": "Screen print",
                    "unit_amount": imprint_unit,
                    "quantity": qty,
                    "total_amount": round(qty * imprint_unit, 2),
                    "source": "contract_table",
                },
            ],
            "pricing_trace": [],
            "customer_explanation": {
                "size_tier_label": payload.get("size_tier_label", "standard_print"),
                "size_bounds_inches": {"min_max_side_in": 0, "max_max_side_in": 12},
                "setup_mode": payload.get("setup_mode", "new_setup"),
                "rationale": ["mock pricing response"],
            },
            "receipt": {
                "receipt_id": f"receipt-{qty}",
                "receipt_generated_at_utc": payload.get("request_timestamp_utc"),
                "normalized_input_fingerprint": "mock-input",
                "output_fingerprint": "mock-output",
                "total_amount": raw_subtotal,
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
            "confidence": {"level": "high", "score": 0.99},
        }
        encoded = json.dumps(body).encode("utf-8")
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

packet_id_from_output() {
  awk '/^quote_packet_id:/ {print $2}' <<<"$1"
}

section "Normalize packet from messy evidence"
normalize_output="$(
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_PREPARE" \
    --evidence-file "$FLOW_FIXTURES/acme-screenprint.evidence.yaml" \
    --skip-customer-resolve
)"
packet_id="$(packet_id_from_output "$normalize_output")"
packet_file="$PACKETS_DIR/quote_packet_${packet_id}.yaml"
[[ -f "$packet_file" ]] || fail "normalized packet file missing"
[[ "$(yq '.state' "$packet_file")" == "needs_input" ]] || fail "normalized packet must start as needs_input due to missing supplier truth"
[[ "$(yq '.open_gaps | map(select(.gap_type == "supplier_unresolved")) | length' "$packet_file")" == "1" ]] || fail "normalize must carry supplier_unresolved before sourcing"
pass "normalize preserves the missing garment-source gap instead of inventing a blank cost"

section "Source supplier blank truth and garment cost"
source_output="$(
  SUPPLIERS_BASE_URL="http://127.0.0.1:${PORT}" \
  SUPPLIERS_API_KEY="test-suppliers-key" \
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_SOURCE" "$packet_id"
)"
[[ "$(yq '.state' "$packet_file")" == "drafting" ]] || fail "sourced packet must return to drafting when only warning-level gaps remain"
[[ "$(yq '.line_items[0].supplier_code' "$packet_file")" == "ssactive" ]] || fail "supplier_code must be resolved from suppliers search"
[[ "$(yq '.line_items[0].supplier_sku' "$packet_file")" == "PC54-BLACK-L" ]] || fail "supplier_sku must use the selected canonical blank"
[[ "$(yq '.line_items[0].blanks_cost_cents' "$packet_file")" == "425" ]] || fail "supplier garment price must land in blanks_cost_cents"
[[ "$(yq '.inventory_snapshot.stock_check_state' "$packet_file")" == "completed" ]] || fail "inventory snapshot must record completed stock check"
[[ "$(yq '.open_gaps | map(select(.gap_type == "supplier_unresolved")) | length' "$packet_file")" == "0" ]] || fail "supplier_unresolved gap must clear after sourcing"
grep -Fq "source_state: completed" <<<"$source_output" || fail "source output must report completed sourcing"
pass "quote-source resolves supplier identity, garment price, and stock evidence into the packet"

section "Source honors services.health plus ssh fallback when SUPPLIERS_BASE_URL is unset"
FALLBACK_SPINE="$TMP_ROOT/fallback-spine"
mkdir -p "$FALLBACK_SPINE/ops/bindings"
cat > "$FALLBACK_SPINE/ops/bindings/services.health.yaml" <<EOF
endpoints:
  - id: suppliers-v2
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
fallback_normalize_output="$(
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_PREPARE" \
    --evidence-file "$FLOW_FIXTURES/acme-screenprint.evidence.yaml" \
    --skip-customer-resolve
)"
fallback_packet_id="$(packet_id_from_output "$fallback_normalize_output")"
fallback_packet_file="$PACKETS_DIR/quote_packet_${fallback_packet_id}.yaml"
fallback_source_output="$(
  SPINE_ROOT="$FALLBACK_SPINE" \
  SUPPLIERS_API_KEY="test-suppliers-key" \
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_SOURCE" "$fallback_packet_id"
)"
[[ "$(yq '.inventory_snapshot.stock_check_state' "$fallback_packet_file")" == "completed" ]] || fail "source fallback packet must still complete stock lookup"
[[ "$(yq '.open_gaps | map(select(.gap_type == "supplier_unresolved")) | length' "$fallback_packet_file")" == "0" ]] || fail "supplier_unresolved gap must clear when services.health fallback resolves the reachable host"
grep -Fq "source_state: completed" <<<"$fallback_source_output" || fail "source fallback output must report completed sourcing"
pass "quote-source resolves supplier service reachability through the canonical services.health + ssh fallback path"

section "Source reports connectivity failures honestly without inventing a no-match blocker"
unavailable_normalize_output="$(
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_PREPARE" \
    --evidence-file "$FLOW_FIXTURES/acme-screenprint.evidence.yaml" \
    --skip-customer-resolve
)"
unavailable_packet_id="$(packet_id_from_output "$unavailable_normalize_output")"
unavailable_packet_file="$PACKETS_DIR/quote_packet_${unavailable_packet_id}.yaml"
unavailable_source_output="$(
  SUPPLIERS_BASE_URL="http://127.0.0.1:1" \
  SUPPLIERS_API_KEY="test-suppliers-key" \
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_SOURCE" "$unavailable_packet_id"
)"
[[ "$(yq '.open_gaps | map(select(.gap_type == "supplier_unresolved")) | length' "$unavailable_packet_file")" == "1" ]] || fail "connectivity failure must emit exactly one supplier_unresolved gap"
grep -Fq "supplier search unavailable" "$unavailable_packet_file" || fail "connectivity failure gap must explain supplier search unavailability"
if grep -Fq "no trustworthy supplier candidate matched the packet truth" "$unavailable_packet_file"; then
  fail "connectivity failure must not invent a no-candidate-match blocker"
fi
grep -Fq "supplier search unavailable" <<<"$unavailable_source_output" || fail "source output must surface the connectivity failure"
pass "quote-source distinguishes unreachable supplier infrastructure from genuine no-match sourcing failures"

section "Price packet using sourced garment cost"
price_output="$(
  PRICING_BASE_URL="http://127.0.0.1:${PORT}" \
  PRICING_API_KEY="test-pricing-key" \
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_PRICE" "$packet_id"
)"
[[ "$(yq '.pricing_snapshot.pricing_state' "$packet_file")" == "completed" ]] || fail "pricing snapshot must complete after sourcing"
[[ "$(yq '.pricing_snapshot.calculated_totals.total' "$packet_file")" == "1219.68" ]] || fail "pricing total must persist after sourced pricing"
[[ "$(yq '.pricing_snapshot.line_item_prices[0].pricing_breakdown.garment_markup_total' "$packet_file")" == "92.16" ]] || fail "pricing breakdown must persist garment markup total"
grep -Fq '"blanks_cost": 4.25' "$PRICING_REQUEST_LOG" || fail "pricing request must include the supplier garment price"
grep -Fq "pricing_state: completed" <<<"$price_output" || fail "price output must report completion"
pass "quote-price consumes the sourced blank cost instead of a hand-entered garment price"

section "Render review-ready quote from sourced and priced packet"
render_output="$(
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  "$QUOTE_RENDER" "$packet_id"
)"
[[ "$(yq '.state' "$packet_file")" == "ready_for_review" ]] || fail "end-to-end packet must reach ready_for_review after render"
grep -Fq "Shipping is not included in this draft total" "$packet_file" || fail "rendered customer message must preserve warning-level shipping honesty"
grep -Fq -- "-> ready_for_review" <<<"$render_output" || fail "render output must report the review transition"
pass "normalize -> source -> price -> render now works end to end from a governed packet"

section "Source blocks honestly on generic product descriptions"
before_supplier_calls="$(wc -l < "$SUPPLIER_REQUEST_LOG" | tr -d ' ')"
blocked_output="$(
  SUPPLIERS_BASE_URL="http://127.0.0.1:${PORT}" \
  SUPPLIERS_API_KEY="test-suppliers-key" \
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  "$QUOTE_SOURCE" source-blocked-generic
)"
blocked_packet="$PACKETS_DIR/quote_packet_source-blocked-generic.yaml"
[[ "$(yq '.state' "$blocked_packet")" == "needs_input" ]] || fail "generic packet must remain needs_input"
[[ "$(yq '.open_gaps | map(select(.gap_type == "supplier_unresolved")) | length' "$blocked_packet")" == "1" ]] || fail "generic packet must emit supplier_unresolved"
after_supplier_calls="$(wc -l < "$SUPPLIER_REQUEST_LOG" | tr -d ' ')"
[[ "$after_supplier_calls" == "$before_supplier_calls" ]] || fail "generic packet should not query suppliers without a trustworthy style cue"
grep -Fq "no canonical style code or SKU was available" <<<"$blocked_output" || fail "blocked source output must explain the missing style cue"
pass "quote-source refuses to invent garment sourcing from vague descriptions"

section "Summary"
echo "Packet supplier sourcing and end-to-end flow checks passed"
