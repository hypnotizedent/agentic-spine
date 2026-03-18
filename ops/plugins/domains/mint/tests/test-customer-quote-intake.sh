#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
INTAKE="$ROOT/ops/plugins/domains/mint/bin/customer-quote-intake"
CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$INTAKE" ]] || fail "missing customer-quote-intake executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"; [[ -n "${SERVER_PID:-}" ]] && kill "$SERVER_PID" >/dev/null 2>&1 || true' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_DATA_ROOT="$tmp/mint-runtime"
export MINT_RUNTIME_ROOT="$tmp/mint-runtime"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$CONTRACT"
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_QUOTE_PACKETS_DIR="$tmp/quote-packets"
export MINT_QUOTE_PACKET_INDEX_FILE="$tmp/quote-packets-index.yaml"
export MINT_INLINE_IMAGE_CONTEXT_FIXTURE_JSON='{"summary":"Inline mockup shows a matching tee layout with front chest and full back print placements.","visible_products":["tee"],"set_context":"single_item","colors":["vintage white","pastel mint"],"decoration_method_guess":"screen_print","decoration_confidence":"medium","customer_reference_resolution":"customer appears to be pointing at apparel mockups rather than production-ready art.","operator_relevance":["use the inline imagery as mockup/reference evidence, not print-ready artwork"]}'
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE" "$MINT_QUOTE_PACKETS_DIR"

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
from urllib.parse import parse_qs, urlparse

port = int(sys.argv[1])

SEARCH_RESULTS = {
    "BC3001": {
        "supplier_code": "ssactive",
        "supplier_sku": "BC3001-VINTAGEWHITE-M",
        "style_code": "BC3001",
        "brand": "Bella + Canvas",
        "color_name": "Vintage White",
        "piece_price": 5.45,
    },
    "A4N3165": {
        "supplier_code": "ssactive",
        "supplier_sku": "A4N3165-PASTELMINT-M",
        "style_code": "A4N3165",
        "brand": "A4",
        "color_name": "Pastel Mint",
        "piece_price": 9.75,
    },
}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/v1/suppliers/search":
            params = parse_qs(parsed.query)
            query = params.get("q", [""])[0]
            result = SEARCH_RESULTS.get(query)
            body = {"query": query, "results": [result] if result else []}
            encoded = json.dumps(body).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)
            return
        if parsed.path.startswith("/api/v1/suppliers/ssactive/products/"):
            body = {
                "total_available": 250,
                "variants": [
                    {"color": "Vintage White", "size": "M", "quantity_available": 125},
                    {"color": "Pastel Mint", "size": "M", "quantity_available": 125},
                ],
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
        parsed = urlparse(self.path)
        if parsed.path == "/api/v1/pricing/estimate":
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
            qty = int(payload.get("qty", 0))
            total_amount = round(qty * 19.95, 2)
            body = {
                "estimate_id": f"cove-estimate-{qty}",
                "requested_at_utc": payload.get("request_timestamp_utc"),
                "pricing_authority_path": "job_estimator",
                "pricing_source": "contract_table",
                "line_items": [
                    {
                        "code": "blank",
                        "description": "Blank garment",
                        "unit_amount": 8.75,
                        "quantity": qty,
                        "total_amount": round(qty * 8.75, 2),
                        "source": "contract_table",
                    },
                    {
                        "code": "decoration",
                        "description": "Decoration charge",
                        "unit_amount": 11.20,
                        "quantity": qty,
                        "total_amount": round(qty * 11.20, 2),
                        "source": "contract_table",
                    },
                ],
                "pricing_trace": [],
                "customer_explanation": {
                    "size_tier_label": payload.get("size_tier_label", "standard_print"),
                    "setup_mode": payload.get("setup_mode", "new_setup"),
                    "rationale": ["Cove intake mock estimate response"],
                },
                "confidence": {"level": "high", "score": 0.97},
                "receipt": {
                    "receipt_id": f"cove-estimate-receipt-{qty}",
                    "receipt_generated_at_utc": payload.get("request_timestamp_utc"),
                    "total_amount": total_amount,
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

    def log_message(self, *_args):
        return

HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
SERVER_PID=$!
sleep 1

export SUPPLIERS_BASE_URL="http://127.0.0.1:${PORT}"
export SUPPLIERS_API_KEY="test-suppliers-key"
export PRICING_BASE_URL="http://127.0.0.1:${PORT}"
export PRICING_API_KEY="test-pricing-key"

cat >"$SPINE_ROOT/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

echo "Receipt: /tmp/${capability}.receipt.md"

case "$capability" in
  microsoft.mail.get)
    message_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    case "$message_id" in
      MSG-COVE)
        cat <<'JSON'
{"id":"MSG-COVE","subject":"Merch Quote Request – Cove Brewery","receivedDateTime":"2026-03-11T01:43:05Z","from":{"emailAddress":{"address":"marketing@covebrewery.com","name":"Cove Marketing"}},"body":{"contentType":"Text","content":"Hey Mint Prints Team,\n\nWe have another large merch order coming your way and I wanted to reach out to request a quote for the following items.\n\nI’ve attached a mockup and the design file for each item in this email so you can see the artwork and placement.\n\nDolphin Shirt – Vintage White\n\nBlank: Bella + Canvas BC3001 (Unisex Jersey Tee)\n\nColor: Vintage White\n\nDesign:\n\n• Small Cove Brewery logo on front chest\n\n• Large back graphic featuring a beer pint with dolphins jumping and an orange slice on the rim\n\nPrint Locations:\n\n• Front chest\n\n• Full back\n\nQuantity: 30\n\nSize Breakdown:\n\nS – 5\n\nM – 8\n\nL – 8\n\nXL – 6\n\n2XL – 2\n\n3XL – 1\n\n⸻\n\nShark SPF Long Sleeve – Pastel Mint\n\nBlank: A4 Cooling Performance Long Sleeve (A4N3165)\n\nColor: Pastel Mint\n\nDesign:\n\n• Small Cove Brewery logo on front chest\n\n• Back shark graphic with text “Reel Beer – Deerfield Beach, FL”\n\nPrint Locations:\n\n• Front chest\n\n• Full back\n\nQuantity: 30\n\nSize Breakdown:\n\nS – 5\n\nM – 8\n\nL – 8\n\nXL – 6\n\n2XL – 2\n\n3XL – 1\n\nPlease let me know if you need any additional information from me to prepare the quote.\n\nThanks as always!\n\nSpencer Todd\n\nMarketing / Merchandise\n\nCove Brewery"}}
JSON
        ;;
      MSG-MARWAN)
        cat <<'JSON'
{"id":"MSG-MARWAN","subject":"Print Request","receivedDateTime":"2026-03-17T02:21:00Z","from":{"emailAddress":{"address":"marwan@icosf.org","name":"Marwan"}},"body":{"contentType":"Text","content":"Hi team,\n\nNeed vinyl floor signage for the masjid lobby.\n\nDo you handle floor decals and adhesive signage for concrete floors?\n\nThanks,\nMarwan"}}
JSON
        ;;
      MSG-KYLE)
        cat <<'JSON'
{"id":"MSG-KYLE","subject":"Full color tee art","receivedDateTime":"2026-03-17T15:21:00Z","from":{"emailAddress":{"address":"kyle@example.com","name":"Kyle"}},"body":{"contentType":"Text","content":"Hey team,\n\nPlease quote this front print on black tees.\n\nFestival Tee - Black\n\nBlank: Bella + Canvas BC3001 (Unisex Jersey Tee)\n\nColor: Black\n\nDesign:\n\n• Attached PNG is the actual print art\n\nPrint Locations:\n\n• Front\n\nQuantity: 300\n\nSize Breakdown:\n\nM – 100\n\nL – 100\n\nXL – 100\n\nLet me know the cleanest print lane for this file.\n\nThanks,\nKyle"}}
JSON
        ;;
      *)
        echo "unsupported microsoft.mail.get message_id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  microsoft.mail.attachments.list)
    message_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    case "$message_id" in
      MSG-COVE)
        cat <<'JSON'
{"messageId":"MSG-COVE","value":[
  {"id":"ATT-1","name":"image0.png","contentType":"image/png","size":870919,"isInline":true},
  {"id":"ATT-2","name":"image1.png","contentType":"image/png","size":327143,"isInline":true},
  {"id":"ATT-3","name":"image2.png","contentType":"image/png","size":162057,"isInline":true},
  {"id":"ATT-4","name":"image3.png","contentType":"image/png","size":627947,"isInline":true},
  {"id":"ATT-5","name":"image4.png","contentType":"image/png","size":670933,"isInline":true},
  {"id":"ATT-6","name":"image5.png","contentType":"image/png","size":111965,"isInline":true}
]}
JSON
        ;;
      MSG-MARWAN)
        cat <<'JSON'
{"messageId":"MSG-MARWAN","value":[]}
JSON
        ;;
      MSG-KYLE)
        cat <<'JSON'
{"messageId":"MSG-KYLE","value":[
  {"id":"ATT-KYLE-1","name":"kyle-full-color-art.png","contentType":"image/png","size":552119,"isInline":false}
]}
JSON
        ;;
      *)
        echo "unsupported microsoft.mail.attachments.list message_id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  microsoft.mail.attachment.download)
    attachment_id=""
    output_dir=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --attachment-id) attachment_id="$2"; shift 2 ;;
        --output-dir) output_dir="$2"; shift 2 ;;
        --message-id|--mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    mkdir -p "$output_dir"
    file_path="$output_dir/${attachment_id}.png"
    if [[ "$attachment_id" == "ATT-KYLE-1" ]]; then
      python3 - "$file_path" <<'PY'
from PIL import Image
import sys

path = sys.argv[1]
img = Image.new("RGB", (1200, 1200))
pixels = img.load()
for y in range(img.height):
    for x in range(img.width):
        pixels[x, y] = ((x * 255) // img.width, (y * 255) // img.height, ((x + y) * 255) // (img.width + img.height))
img.save(path, format="PNG")
PY
    else
      python3 - "$file_path" <<'PY'
import base64
import sys
path = sys.argv[1]
png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0ioAAAAASUVORK5CYII=")
open(path, "wb").write(png)
PY
    fi
    printf '{"filePath":"%s","sha256":"fixture-inline-%s"}\n' "$file_path" "$attachment_id"
    ;;
  mint.customer.record.snapshot)
    email=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --email) email="$2"; shift 2 ;;
        --json) shift ;;
        *) shift ;;
      esac
    done
    case "$email" in
      marketing@covebrewery.com)
        cat <<'JSON'
{"data":{"fresh_slate":{"customer":{"record_id":"cust_cove","name":"Spencer Todd","company":"Cove Brewery","email":"marketing@covebrewery.com"},"identity":{"display_name":"Spencer Todd"}},"printavo_visibility":{"state":"drafted_in_printavo","latest":{"printavo_state":"drafted_in_printavo","printavo_invoice_url":"https://printavo.example.com/invoices/13716"}},"legacy_hold":{"latest_order":{"invoice_number":"13716","nickname":"Cove Brewery Merch Reorder","created_at":"2026-01-07T23:05:25Z"}}}}
JSON
        ;;
      marwan@icosf.org)
        cat <<'JSON'
{"data":{"fresh_slate":{"customer":{"record_id":"cust_marwan","name":"Marwan","company":"ICOSF","email":"marwan@icosf.org"},"identity":{"display_name":"Marwan"}},"printavo_visibility":{},"legacy_hold":{}}}
JSON
        ;;
      kyle@example.com)
        cat <<'JSON'
{"data":{"fresh_slate":{"customer":{"record_id":"cust_kyle","name":"Kyle","company":"Kyle Brand","email":"kyle@example.com"},"identity":{"display_name":"Kyle"}},"printavo_visibility":{},"legacy_hold":{}}}
JSON
        ;;
      *)
        echo "unsupported snapshot email: $email" >&2
        exit 1
        ;;
    esac
    ;;
  mint.customer.seed.ensure)
    message_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --mailbox|--json) shift ;;
        *) shift ;;
      esac
    done
    case "$message_id" in
      MSG-COVE)
        cat <<'JSON'
{"data":{"seed":{"id":"seed-cove-001","status":"new","source":"email"}}}
JSON
        ;;
      MSG-MARWAN)
        cat <<'JSON'
{"data":{"seed":{"id":"seed-marwan-001","status":"new","source":"email"}}}
JSON
        ;;
      MSG-KYLE)
        cat <<'JSON'
{"data":{"seed":{"id":"seed-kyle-001","status":"new","source":"email"}}}
JSON
        ;;
      *)
        echo "unsupported seed message_id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$INTAKE" --message-id MSG-COVE --mailbox team@mintprints.com --json)"
record_file="$(echo "$json_out" | jq -r '.data.record_file')"
packet_file="$(echo "$json_out" | jq -r '.data.handoff.packet_file')"

[[ -f "$record_file" ]] || fail "record file should exist"
[[ -f "$packet_file" ]] || fail "packet file should exist"
[[ "$(echo "$json_out" | jq -r '.data.intake_quality.classification')" == "ideal" ]] || fail "Cove-style structured order should classify as ideal"
[[ "$(echo "$json_out" | jq -r '.data.artwork_readiness.classification')" == "mockup_reference" ]] || fail "inline imagery should classify as mockup_reference"
[[ "$(echo "$json_out" | jq -r '.data.artwork_surface.inline_image_context.state')" == "captured" ]] || fail "inline image context should be captured when supported inline images exist"
[[ "$(echo "$json_out" | jq -r '.data.artwork_surface.inline_image_context.summary')" == "Inline mockup shows a matching tee layout with front chest and full back print placements." ]] || fail "inline image summary should be persisted in the artwork surface"
[[ "$(echo "$json_out" | jq -r '.data.invoked_modules[] | select(.module=="microsoft.mail.attachment.download") | .state')" == "captured" ]] || fail "attachment download module state should reflect captured inline image context"
[[ "$(echo "$json_out" | jq -r '.data.qualification_status')" == "qualified_enough_to_quote" ]] || fail "structured ideal order should be qualified enough to quote"
[[ "$(echo "$json_out" | jq -r '.data.handoff.source_state')" == "completed" ]] || fail "supplier handoff should run"
[[ "$(echo "$json_out" | jq -r '.data.handoff.estimate_state')" == "completed" ]] || fail "estimate handoff should run"
[[ "$(echo "$json_out" | jq -r '.data.handoff.pricing_state')" == "blocked_insufficient_inputs" ]] || fail "pricing should report exact missing pricing inputs"
[[ "$(echo "$json_out" | jq -r '.data.pricing_surface.truth_state')" == "estimate_safe_pricing" ]] || fail "operator pricing truth should surface estimate-safe pricing before any draft"
[[ "$(echo "$json_out" | jq -r '.data.pricing_surface.price_lane')" != "" ]] || fail "pricing surface should expose a non-empty estimate-safe price lane"
[[ "$(echo "$json_out" | jq -r '.data.pricing_surface.next_pricing_tier')" == "standard_print" ]] || fail "pricing surface should carry the next pricing tier basis"
[[ "$(echo "$json_out" | jq -r '.data.quote_readiness.state')" == "quote_packet_in_progress" ]] || fail "intake should surface packet-owned quote readiness"
[[ "$(echo "$json_out" | jq -r '.data.quote_readiness.build_ready')" == "true" ]] || fail "Cove should be build-ready from fresh-slate estimate-safe truth"
[[ "$(echo "$json_out" | jq -r '.data.quote_readiness.build_basis')" == "estimate_safe" ]] || fail "Cove build basis should stay estimate_safe when exact pricing is incomplete"
[[ "$(echo "$json_out" | jq -r '.data.quote_readiness.next_step')" == "run_quote_price" ]] || fail "Cove next step should keep exact pricing internal"
[[ "$(echo "$json_out" | jq -r '.data.quote_readiness.missing_for_build | length')" == "0" ]] || fail "estimate-safe intake should not report build blockers"
[[ "$(echo "$json_out" | jq -r '(.data.quote_readiness.missing_for_send | map(.code) | index("exact_pricing")) != null')" == "true" ]] || fail "send blockers should still explain missing exact pricing"
[[ "$(echo "$json_out" | jq -r '.data.external_context.printavo_visibility.state')" == "drafted_in_printavo" ]] || fail "Printavo bridge should remain attached as advisory external context"
[[ "$(echo "$json_out" | jq -r '.data.estimate_surface.quote_safe_line_item_count')" == "2" ]] || fail "both Cove line items should be quote-safe in estimate mode"
[[ "$(echo "$json_out" | jq -r '.data.estimate_surface.line_item_estimates[0].estimate_status')" == "production_only_exactness_missing" ]] || fail "estimate mode should preserve the distinction from exact pricing"
[[ "$(echo "$json_out" | jq -r '.data.customer_reply_guidance.mode')" == "acknowledge_and_process" ]] || fail "ideal order should drive acknowledge_and_process reply guidance"
[[ "$(echo "$json_out" | jq -r '.data.customer_reply_guidance.body_preview')" != *"print-ready artwork"* ]] || fail "ideal order guidance should not fall back to generic print-ready-art re-asks"
[[ "$(yq '.line_items | length' "$packet_file")" == "2" ]] || fail "packet should preserve both parsed line items"
[[ "$(yq '.inventory_snapshot.stock_check_state' "$packet_file")" == "completed" ]] || fail "supplier sourcing should populate inventory truth"
[[ "$(yq '.open_gaps | map(select(.gap_type == "supplier_unresolved")) | length' "$packet_file")" == "0" ]] || fail "supplier_unresolved should clear after sourcing"

kyle_out="$("$INTAKE" --message-id MSG-KYLE --mailbox team@mintprints.com --json)"
kyle_packet="$(echo "$kyle_out" | jq -r '.data.handoff.packet_file')"
kyle_preflight_record="$(echo "$kyle_out" | jq -r '.data.artwork_surface.artwork_preflight.attachments[0].record_file')"
[[ "$(echo "$kyle_out" | jq -r '.data.artwork_surface.attachment_intelligence.state')" == "captured" ]] || fail "non-inline raster artwork should be analyzed"
[[ "$(echo "$kyle_out" | jq -r '.data.artwork_surface.artwork_preflight.owner')" == "Artie" ]] || fail "non-inline artwork truth should come from Artie-owned preflight"
[[ "$(echo "$kyle_out" | jq -r '.data.artwork_surface.attachment_intelligence.recommended_print_method')" == "dtg" ]] || fail "full-color gradient art at 300 pieces should recommend dtg"
[[ "$(echo "$kyle_out" | jq -r '.data.artwork_surface.attachment_intelligence.attachments[0].has_gradients')" == "true" ]] || fail "gradient-heavy artwork should be flagged"
[[ "$(echo "$kyle_out" | jq -r '.data.artwork_surface.attachment_intelligence.attachments[0].estimated_color_count')" -ge 5 ]] || fail "full-color artwork should report a high estimated color count"
[[ -f "$kyle_preflight_record" ]] || fail "Artie preflight should persist a governed record for the non-inline file"
[[ "$(yq '.artwork_analysis.recommended_print_method' "$kyle_packet")" == "dtg" ]] || fail "quote packet should persist attachment intelligence"
[[ "$(yq '.artwork_analysis.attachments[0].has_gradients' "$kyle_packet")" == "true" ]] || fail "packet artwork analysis should preserve gradient detection"

set +e
scope_out="$("$INTAKE" --message-id MSG-MARWAN --mailbox team@mintprints.com --json 2>&1)"
scope_rc=$?
set -e
[[ "$scope_rc" -ne 0 ]] || fail "out-of-scope intake must fail closed instead of creating quote intake truth"
echo "$scope_out" | grep -F "customer-quote-intake only allows customer_actionable mail" >/dev/null || fail "out-of-scope refusal should explain the customer_actionable gate"

pass "customer-quote-intake surfaces real module pricing truth for actionable mail and blocks out-of-scope mail from creating quote-intake truth"
