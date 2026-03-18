#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

PRINTAVO_RECONCILE="$SPINE_ROOT/ops/plugins/domains/mint/bin/printavo-bridge-reconcile"
TMP_ROOT="$(mktemp -d)"
FAKE_SPINE_ROOT="$TMP_ROOT/fake-spine"
STATE_ROOT="$TMP_ROOT/state"
ORDERS_DIR="$TMP_ROOT/orders"
PRINTAVO_BRIDGES_DIR="$TMP_ROOT/printavo-bridges"
PAYMENT_CAPTURES_DIR="$TMP_ROOT/payment-captures"
ORDERS_INDEX="$TMP_ROOT/orders-index.yaml"
PRINTAVO_BRIDGES_INDEX="$TMP_ROOT/printavo-bridges-index.yaml"
PAYMENT_CAPTURES_INDEX="$TMP_ROOT/payment-captures-index.yaml"
CUSTOMER_FIXTURE="$TMP_ROOT/customers.json"
ORDERS_EXPORT="$TMP_ROOT/ExportsOrdersJob_export_fixture.csv"
FINANCE_INDEX="$STATE_ROOT/mint/finance-cogs-evidence/index.ndjson"
VENDOR_COGS_CONTRACT="$SPINE_ROOT/ops/bindings/mint.finance.vendor.receipt.cogs.contract.yaml"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

mkdir -p "$FAKE_SPINE_ROOT/bin" "$STATE_ROOT/mint/finance-cogs-evidence" "$ORDERS_DIR" "$PRINTAVO_BRIDGES_DIR" "$PAYMENT_CAPTURES_DIR"

cat >"$FAKE_SPINE_ROOT/bin/ops" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
capability="${3:-}"
case "$capability" in
  mint.seeds.query)
    if printf '%s\n' "$*" | grep -F -- '--seed-id seed-needs-1' >/dev/null; then
      printf '{"rows":[{"seed_id":"seed-needs-1","customer_email":"hello@acme.example.com"}]}\n'
    elif printf '%s\n' "$*" | grep -F -- '--email hello@acme.example.com' >/dev/null; then
      printf '{"rows":[{"seed_id":"seed-needs-1","customer_email":"hello@acme.example.com"}]}\n'
    else
      printf '{"rows":[]}\n'
    fi
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
SH
chmod +x "$FAKE_SPINE_ROOT/bin/ops"

cat >"$ORDERS_DIR/order_order-needs-1.yaml" <<'YAML'
order_id: order-needs-1
customer_id: cust-acme
customer_email: hello@acme.example.com
customer_name: Acme Events
intake_seed_refs:
  - seed-needs-1
printavo_summary:
  schema_version: "1.0"
  printavo_state: needs_more_info_before_printavo
  printavo_customer_id: null
  printavo_invoice_url: null
  printavo_public_invoice_url: null
  printavo_work_order_url: null
  printavo_visual_id: null
  last_reconciled_at: null
  source_kind: none
  record_kind: none
  record_id: null
  provenance:
    source: none
    basis: []
YAML

cat >"$PRINTAVO_BRIDGES_INDEX" <<'YAML'
printavo_bridges: []
YAML

cat >"$PAYMENT_CAPTURES_INDEX" <<'YAML'
payment_captures:
  - payment_capture_id: pay-1
    order_id: order-needs-1
    seed_id: seed-needs-1
    customer_id: cust-acme
    customer_email: hello@acme.example.com
    payment_state: paid
YAML

cat >"$FINANCE_INDEX" <<'NDJSON'
{"finance_evidence_id":"finance-1","seed_id":"seed-needs-1","customer_id":"cust-acme","customer_email":"hello@acme.example.com","printavo_bridge_id":null}
NDJSON

cat >"$CUSTOMER_FIXTURE" <<'JSON'
[
  {
    "record_id": "cust-acme",
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

audit_json="$(
  SPINE_ROOT="$FAKE_SPINE_ROOT" \
  SPINE_STATE="$STATE_ROOT" \
  MINT_CUSTOMER_RECORD_FIXTURE_FILE="$CUSTOMER_FIXTURE" \
  MINT_ORDER_RUNTIME_DIR="$ORDERS_DIR" \
  MINT_ORDER_INDEX_FILE="$ORDERS_INDEX" \
  MINT_PRINTAVO_BRIDGES_DIR="$PRINTAVO_BRIDGES_DIR" \
  MINT_PRINTAVO_BRIDGES_INDEX_FILE="$PRINTAVO_BRIDGES_INDEX" \
  MINT_PAYMENT_CAPTURE_DIR="$PAYMENT_CAPTURES_DIR" \
  MINT_PAYMENT_CAPTURE_INDEX_FILE="$PAYMENT_CAPTURES_INDEX" \
  MINT_PRINTAVO_BRIDGE_ORDERS_EXPORT="$ORDERS_EXPORT" \
  MINT_VENDOR_RECEIPT_COGS_CONTRACT="$VENDOR_COGS_CONTRACT" \
  "$PRINTAVO_RECONCILE" --audit --email hello@acme.example.com --json
)"

[[ "$(echo "$audit_json" | jq -r '.state')" == "needs_attention" ]] || fail "audit should flag missing linkage"
[[ "$(echo "$audit_json" | jq -r '.audit_mode')" == "true" ]] || fail "audit mode should be true"
echo "$audit_json" | jq -e 'any(.issues[]; .issue_type == "seed_exists_but_no_printavo_bridge")' >/dev/null || fail "audit should flag missing bridge for seed/order context"
echo "$audit_json" | jq -e 'any(.issues[]; .issue_type == "payment_visible_without_printavo_bridge")' >/dev/null || fail "audit should flag payment evidence without bridge"
echo "$audit_json" | jq -e 'any(.issues[]; .issue_type == "vendor_evidence_without_printavo_link")' >/dev/null || fail "audit should flag vendor evidence without bridge"
echo "$audit_json" | jq -e 'any(.issues[]; .issue_type == "legacy_history_unpromoted")' >/dev/null || fail "audit should flag legacy Printavo history not yet promoted"
pass "printavo bridge audit surfaces missing seed/order/payment/vendor/legacy linkage without reopening Printavo"
