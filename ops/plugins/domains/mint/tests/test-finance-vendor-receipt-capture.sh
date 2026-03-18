#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
CAPTURE="$ROOT/ops/plugins/domains/mint/bin/finance-vendor-receipt-capture"
SNAPSHOT="$ROOT/ops/plugins/domains/mint/bin/finance-cogs-evidence-snapshot"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$CAPTURE" ]] || fail "missing finance-vendor-receipt-capture executable"
[[ -x "$SNAPSHOT" ]] || fail "missing finance-cogs-evidence-snapshot executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_VENDOR_RECEIPT_COGS_CONTRACT="$ROOT/ops/bindings/mint.finance.vendor.receipt.cogs.contract.yaml"
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE"

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
      MSG-SANMAR)
        cat <<'JSON'
{"id":"MSG-SANMAR","subject":"SanMar Order Confirmation for Order #SO-159108817, PO# 13831 RIVA Motorsports service center","receivedDateTime":"2026-03-13T19:34:27Z","bodyPreview":"We have received your order, please see attached for details.","body":{"contentType":"HTML","content":"<p>We have received your order, please see attached for details.</p>"},"from":{"emailAddress":{"address":"Sales@SanMar.com","name":"Sales@SanMar.com"}},"conversationId":"CONV-SANMAR","internetMessageId":"<sanmar-13831@example.test>","hasAttachments":true}
JSON
        ;;
      *)
        echo "unexpected mail.get message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  microsoft.mail.attachments.list)
    cat <<'JSON'
{"value":[{"id":"ATT-SANMAR-PDF","name":"sanmar-13831.pdf","contentType":"application/pdf","size":4096,"lastModifiedDateTime":"2026-03-13T19:34:27Z","isInline":false}]}
JSON
    ;;
  microsoft.mail.attachment.download)
    output_dir=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --output-dir) output_dir="$2"; shift 2 ;;
        --attachment-id) shift 2 ;;
        --mailbox) shift 2 ;;
        --message-id) shift 2 ;;
        *) shift ;;
      esac
    done
    [[ -n "$output_dir" ]] || fail "missing output dir"
    mkdir -p "$output_dir"
    cat >"$output_dir/sanmar-13831.pdf" <<'PDF'
From:
 sales@sanmar.com
Sent:
 Friday, March 13, 2026 7:32:16 PM
Subject:
 SanMar Order Confirmation for PO#
13831 RIVA Motorsports service center
-- Order#
SO-159108817
Billing Information
MINT PRINTS LLC
Shipping Information
Mint Prints
Order Number:
 SO-159108817
PO Number:
 13831 RIVA Motorsports service center
Total Pieces:
 80
Total Weight:
 25.10
Terms:
 Net30

Line Item Information
ITEM #
Color
Description
Size
Quantity
Unit Price
Amount
DC
ST640
True Navy
ST PosiCharge RacerMesh Polo
M
5
$
7.81
$
39.05
FL
ST640
True Navy
ST PosiCharge RacerMesh Polo
L
10
$
7.81
$
78.10
FL
ST350
Grey Concrete
Heather
ST PosiCharge Competitor Tee
L
15
$
5.16
$
77.40
FL
ST350
Grey Concrete
Heather
ST PosiCharge Competitor Tee
M
30
$
5.16
$
154.80
FL
ST350
Grey Concrete
Heather
ST PosiCharge Competitor Tee
XL
5
$
5.16
$
25.80
FL
ST350
True Navy
ST PosiCharge Competitor Tee
M
10
$
4.13
$
41.30
FL
ST350
True Navy
ST PosiCharge Competitor Tee
L
5
$
4.13
$
20.65
FL
Order Totals
Subtotal
:
$
437.10
Freight
:
$
0.00
Estimated Sales Tax:
$
0.00
Total
:
$
437.10
Freight Savings
:
$
41.43
PDF
    sha="$(shasum -a 256 "$output_dir/sanmar-13831.pdf" | awk '{print $1}')"
    cat <<JSON
{"id":"ATT-SANMAR-PDF","messageId":"MSG-SANMAR","name":"sanmar-13831.pdf","contentType":"application/pdf","size":$(wc -c <"$output_dir/sanmar-13831.pdf" | tr -d ' '),"sha256":"$sha","filePath":"$output_dir/sanmar-13831.pdf","lastModifiedDateTime":"2026-03-13T19:34:27Z"}
JSON
    ;;
  communications.mail.search)
    query=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --query) query="$2"; shift 2 ;;
        --top) shift 2 ;;
        --mailbox) shift 2 ;;
        --json) shift ;;
        *) shift ;;
      esac
    done
    [[ "$query" == "13831" ]] || {
      echo "unexpected search query: $query" >&2
      exit 1
    }
    cat <<'JSON'
{"data":{"microsoft":{"value":[{"id":"MSG-CUSTOMER","subject":"Re: 13831 RIVA Motorsports service center","receivedDateTime":"2026-03-13T19:38:58Z","from":{"emailAddress":{"address":"earenas@rivaracing.com","name":"Erick Arenas"}}},{"id":"MSG-TEAM","subject":"RE: 13831 RIVA Motorsports service center","receivedDateTime":"2026-03-13T19:36:48Z","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Team"}}},{"id":"MSG-SANMAR","subject":"SanMar Order Confirmation for Order #SO-159108817, PO# 13831 RIVA Motorsports service center","receivedDateTime":"2026-03-13T19:34:27Z","from":{"emailAddress":{"address":"Sales@SanMar.com","name":"Sales@SanMar.com"}}},{"id":"MSG-PAYMENT","subject":"Invoice #13831 - Erick Arenas, Riva Motor Sports - Successful Payment","receivedDateTime":"2026-03-13T14:56:29Z","from":{"emailAddress":{"address":"hit-reply@messages.printavo.com","name":"Printavo"}}},{"id":"MSG-APPROVED","subject":"#13831 - RIVA Motorsports service center - Erick Arenas, Riva Motor Sports - Quote Approved","receivedDateTime":"2026-03-12T20:26:18Z","from":{"emailAddress":{"address":"messages@messages.printavo.com","name":"Printavo"}}}]}}}
JSON
    ;;
  mint.customer.seed.ensure)
    cat <<'JSON'
{"seed":{"id":"seed-riva-1","status":"new","source":"email","has_line_item":false},"customer_email":"earenas@rivaracing.com","customer_display_name":"Erick Arenas"}
JSON
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"fresh_slate":{"customer":{"record_id":"cust-riva-1","name":"Erick Arenas","printavo_customer_id":"4003209"}}}
JSON
    ;;
  mint.printavo.bridge.snapshot)
    cat <<'JSON'
{"latest":{"printavo_summary":{"record_id":null,"printavo_state":"needs_more_info_before_printavo","printavo_visual_id":null,"printavo_customer_id":null}}}
JSON
    ;;
  mint.printavo.bridge.capture)
    printf '%s\n' "$*" >"$SPINE_STATE/printavo-bridge-capture.log"
    cat <<'JSON'
{"printavo_bridge_id":"bridge-13831","printavo_state":"paid","record_file":"/tmp/printavo-bridge-13831.yaml"}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_out="$("$CAPTURE" MSG-SANMAR --mailbox team@mintprints.com --json)"
vendor_record_file="$(echo "$json_out" | jq -r '.vendor_receipt.record_file')"
finance_record_file="$(echo "$json_out" | jq -r '.finance_evidence.record_file')"
vendor_index_file="$SPINE_STATE/mint/vendor-email-evidence/index.ndjson"
finance_index_file="$SPINE_STATE/mint/finance-cogs-evidence/index.ndjson"
evidence_file="$(echo "$json_out" | jq -r '.vendor_receipt.attachments[0].evidence_file')"
text_file="$(echo "$json_out" | jq -r '.vendor_receipt.attachments[0].extracted_text_file')"

[[ -f "$vendor_record_file" ]] || fail "vendor receipt record should exist"
[[ -f "$finance_record_file" ]] || fail "finance evidence record should exist"
[[ -f "$vendor_index_file" ]] || fail "vendor receipt index should exist"
[[ -f "$finance_index_file" ]] || fail "finance evidence index should exist"
[[ -f "$evidence_file" ]] || fail "attachment evidence file should exist"
[[ -f "$text_file" ]] || fail "attachment extracted text file should exist"
[[ "$(echo "$json_out" | jq -r '.vendor_receipt.vendor_id')" == "sanmar" ]] || fail "vendor id should resolve from sender domain"
[[ "$(echo "$json_out" | jq -r '.vendor_receipt.event_primary')" == "order_acknowledgment" ]] || fail "event should classify as order acknowledgment"
[[ "$(echo "$json_out" | jq -r '.finance_evidence.external_order_ref.external_order_number')" == "13831" ]] || fail "external order number should resolve from PO"
[[ "$(echo "$json_out" | jq -r '.finance_evidence.normalized_extract.vendor_order_number')" == "SO-159108817" ]] || fail "vendor order number should resolve"
[[ "$(echo "$json_out" | jq -r '.finance_evidence.normalized_extract.total_pieces')" == "80" ]] || fail "total pieces should parse"
[[ "$(echo "$json_out" | jq -r '.finance_evidence.normalized_extract.totals.total_cents')" == "43710" ]] || fail "total_cents should parse"
[[ "$(echo "$json_out" | jq -r '.finance_evidence.cogs_visibility_state')" == "vendor_cost_visible" ]] || fail "cost visibility should show priced evidence"
[[ "$(echo "$json_out" | jq -r '.finance_evidence.cost_basis_status')" == "provisional_vendor_acknowledgment" ]] || fail "order confirmation should remain provisional cost basis"
[[ "$(echo "$json_out" | jq -r '.finance_evidence.external_order_ref.seed_id')" == "seed-riva-1" ]] || fail "seed bridge should be preserved"
[[ "$(echo "$json_out" | jq -r '.finance_evidence.external_order_ref.customer_email')" == "earenas@rivaracing.com" ]] || fail "customer email should resolve from anchor thread"
[[ "$(echo "$json_out" | jq -r '.finance_evidence.external_order_ref.printavo_customer_id')" == "4003209" ]] || fail "printavo customer id should resolve from customer snapshot"
[[ "$(echo "$json_out" | jq -r '.finance_evidence.external_order_ref.printavo_bridge_id')" == "bridge-13831" ]] || fail "printavo bridge id should be linked"
[[ "$(echo "$json_out" | jq -r '.finance_evidence.normalized_extract.line_items | length')" == "7" ]] || fail "all SanMar line items should parse"
[[ "$(echo "$json_out" | jq -r '.finance_evidence.normalized_extract.ship_nodes | join(",")')" == "DC,FL" ]] || fail "ship nodes should dedupe"
[[ "$(jq -r '.event_primary' "$vendor_record_file")" == "order_acknowledgment" ]] || fail "vendor record should persist event classification"
[[ "$(jq -r '.external_order_ref.external_order_number' "$finance_record_file")" == "13831" ]] || fail "finance record should persist external order number"
[[ "$(tail -n 1 "$finance_index_file" | jq -r '.external_order_number')" == "13831" ]] || fail "finance index should capture query key"
grep -F -- '--printavo-state paid' "$SPINE_STATE/printavo-bridge-capture.log" >/dev/null || fail "bridge capture should carry inferred paid state"
pass "finance-vendor-receipt-capture writes governed vendor receipt and finance evidence records"

snapshot_json="$("$SNAPSHOT" --external-order-number 13831 --json)"
[[ "$(echo "$snapshot_json" | jq -r '.state')" == "vendor_cost_visible" ]] || fail "snapshot should expose cost-visible state"
[[ "$(echo "$snapshot_json" | jq -r '.latest.external_order_ref.external_order_number')" == "13831" ]] || fail "snapshot should return the bridged external order"
[[ "$(echo "$snapshot_json" | jq -r '.latest.normalized_extract.vendor_order_number')" == "SO-159108817" ]] || fail "snapshot should return vendor order number"
pass "finance-cogs-evidence-snapshot reads the governed bridge by external order number"
