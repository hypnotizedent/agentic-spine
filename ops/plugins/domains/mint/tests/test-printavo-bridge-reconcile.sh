#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PROMOTE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-promote"
PRINTAVO_RECONCILE="$SPINE_ROOT/ops/plugins/domains/mint/bin/printavo-bridge-reconcile"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-promote"
TMP_ROOT="$(mktemp -d)"
PACKETS_DIR="$TMP_ROOT/quote-packets"
ORDERS_DIR="$TMP_ROOT/orders"
ORDER_REVISIONS_DIR="$TMP_ROOT/order-revisions"
QUOTES_DIR="$TMP_ROOT/quotes"
PRICING_SNAPSHOTS_DIR="$TMP_ROOT/pricing-snapshots"
ARTWORK_BINDINGS_DIR="$TMP_ROOT/artwork-bindings"
PRINTAVO_BRIDGES_DIR="$TMP_ROOT/printavo-bridges"
PACKET_INDEX="$TMP_ROOT/quote-packets-index.yaml"
ORDERS_INDEX="$TMP_ROOT/orders-index.yaml"
ORDER_REVISIONS_INDEX="$TMP_ROOT/order-revisions-index.yaml"
QUOTES_INDEX="$TMP_ROOT/quotes-index.yaml"
PRICING_SNAPSHOTS_INDEX="$TMP_ROOT/pricing-snapshots-index.yaml"
ARTWORK_BINDINGS_INDEX="$TMP_ROOT/artwork-bindings-index.yaml"
PRINTAVO_BRIDGES_INDEX="$TMP_ROOT/printavo-bridges-index.yaml"
CUSTOMER_FIXTURE="$TMP_ROOT/customers.json"
ORDERS_EXPORT="$TMP_ROOT/ExportsOrdersJob_export_fixture.csv"
EXTRACT_ROOT="$TMP_ROOT/printavo-extract"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

mkdir -p "$PACKETS_DIR" "$EXTRACT_ROOT/invoices" "$EXTRACT_ROOT/quotes"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_printavo-reconcile.yaml"
yq -i '.quote_packet_id = "printavo-reconcile" | .customer_ref.customer_id = "cust_promote_ready" | .customer_ref.resolved_name = "Acme Events" | .customer_ref.resolved_email = "hello@acme.example.com"' "$PACKETS_DIR/quote_packet_printavo-reconcile.yaml"

cat >"$CUSTOMER_FIXTURE" <<'JSON'
[
  {
    "record_id": "cust_promote_ready",
    "email": "hello@acme.example.com",
    "name": "Acme Events",
    "company": "Acme Events",
    "legacy_customer_id": 27949,
    "metadata": {
      "legacy_row": {
        "printavo_id": "5276540"
      }
    }
  }
]
JSON

cat >"$ORDERS_EXPORT" <<'CSV'
Invoice #,Nickname,Created Date,Production Due Date,Customer Email,Customer Company,Customer Id,Paid?,Invoice Status,Public Invoice View URL,Invoice URL
13799,Acme Events Tees,2026-03-12 10:00:00 -0500,2026-03-20,hello@acme.example.com,Acme Events,5276540,false,COMPLETE,https://mint-prints-4019cb.printavo.com/invoice/public-acme-13799,https://www.printavo.com/invoices/21599999
CSV

cat >"$EXTRACT_ROOT/invoices/13799.json" <<'JSON'
{
  "type": "invoice",
  "visualId": "13799",
  "id": "21599999",
  "url": "https://www.printavo.com/invoices/21599999",
  "publicUrl": "https://mint-prints-4019cb.printavo.com/invoice/public-acme-13799",
  "workorderUrl": "https://mint-prints-4019cb.printavo.com/work_orders/acme-13799",
  "paidInFull": true,
  "status": {
    "name": "COMPLETE",
    "type": "INVOICE"
  },
  "contact": {
    "customer": {
      "id": "5276540"
    }
  }
}
JSON

run_promote() {
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$PACKET_INDEX" \
  MINT_ORDER_RUNTIME_DIR="$ORDERS_DIR" \
  MINT_ORDER_INDEX_FILE="$ORDERS_INDEX" \
  MINT_ORDER_REVISIONS_DIR="$ORDER_REVISIONS_DIR" \
  MINT_ORDER_REVISION_INDEX_FILE="$ORDER_REVISIONS_INDEX" \
  MINT_QUOTES_DIR="$QUOTES_DIR" \
  MINT_QUOTES_INDEX_FILE="$QUOTES_INDEX" \
  MINT_PRICING_SNAPSHOTS_DIR="$PRICING_SNAPSHOTS_DIR" \
  MINT_PRICING_SNAPSHOT_INDEX_FILE="$PRICING_SNAPSHOTS_INDEX" \
  MINT_ARTWORK_BINDINGS_DIR="$ARTWORK_BINDINGS_DIR" \
  MINT_ARTWORK_BINDINGS_INDEX_FILE="$ARTWORK_BINDINGS_INDEX" \
  "$QUOTE_PROMOTE" "$@"
}

run_reconcile() {
  MINT_CUSTOMER_RECORD_FIXTURE_FILE="$CUSTOMER_FIXTURE" \
  MINT_ORDER_RUNTIME_DIR="$ORDERS_DIR" \
  MINT_ORDER_INDEX_FILE="$ORDERS_INDEX" \
  MINT_QUOTES_DIR="$QUOTES_DIR" \
  MINT_QUOTES_INDEX_FILE="$QUOTES_INDEX" \
  MINT_PRINTAVO_BRIDGES_DIR="$PRINTAVO_BRIDGES_DIR" \
  MINT_PRINTAVO_BRIDGES_INDEX_FILE="$PRINTAVO_BRIDGES_INDEX" \
  MINT_PRINTAVO_BRIDGE_ORDERS_EXPORT="$ORDERS_EXPORT" \
  MINT_PRINTAVO_BRIDGE_EXTRACT_ROOT="$EXTRACT_ROOT" \
  "$PRINTAVO_RECONCILE" "$@"
}

run_promote printavo-reconcile --approved-by MINT-OPERATOR-01 >/dev/null
packet_file="$PACKETS_DIR/quote_packet_printavo-reconcile.yaml"
order_id="$(yq '.order_id' "$packet_file")"
order_file="$ORDERS_DIR/order_${order_id}.yaml"

reconcile_json="$(run_reconcile --order-id "$order_id" --invoice-number 13799 --captured-by Dutchman --note 'legacy import' --evidence-ref "$ORDERS_EXPORT" --receipt /tmp/printavo-reconcile.receipt.md --json)"
bridge_id="$(echo "$reconcile_json" | jq -r '.printavo_bridge_id')"
bridge_file="$PRINTAVO_BRIDGES_DIR/printavo_bridge_${bridge_id}.yaml"

[[ -f "$bridge_file" ]] || fail "reconcile should persist a bridge record"
[[ "$(echo "$reconcile_json" | jq -r '.reconcile_state')" == "recorded" ]] || fail "reconcile should create a new bridge record"
[[ "$(yq '.printavo_summary.printavo_state' "$order_file")" == "converted_to_work_order" ]] || fail "reconcile should project converted_to_work_order from recovered workorderUrl"
[[ "$(yq '.printavo_summary.printavo_invoice_url' "$order_file")" == "https://www.printavo.com/invoices/21599999" ]] || fail "reconcile should project invoice url"
[[ "$(yq '.printavo_summary.printavo_work_order_url' "$order_file")" == "https://mint-prints-4019cb.printavo.com/work_orders/acme-13799" ]] || fail "reconcile should project recovered work order url"
[[ "$(yq '.printavo_summary.printavo_customer_id' "$order_file")" == "5276540" ]] || fail "reconcile should project fresh customer printavo id"
grep -Fq -- "legacy_orders_export" "$bridge_file" || fail "bridge provenance should include legacy orders export"
grep -Fq -- "printavo_extraction_recovery" "$bridge_file" || fail "bridge provenance should include extraction recovery"
[[ "$(yq '.evidence_refs[0]' "$bridge_file")" == "$ORDERS_EXPORT" ]] || fail "reconcile should persist evidence refs"
[[ "$(yq '.receipts[0]' "$bridge_file")" == "/tmp/printavo-reconcile.receipt.md" ]] || fail "reconcile should persist receipt refs"
pass "legacy-first Printavo reconcile backfills bridge truth and projects canonical order visibility"
