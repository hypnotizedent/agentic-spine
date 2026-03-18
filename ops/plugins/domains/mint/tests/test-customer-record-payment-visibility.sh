#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"
CUSTOMER_SNAPSHOT="$REPO_ROOT/ops/plugins/domains/mint/bin/customer-record-snapshot"
PAYMENT_SNAPSHOT="$REPO_ROOT/ops/plugins/domains/mint/bin/payment-record-snapshot"
ARTIFACT_SNAPSHOT="$REPO_ROOT/ops/plugins/domains/mint/bin/artifact-record-snapshot"
PRINTAVO_SNAPSHOT="$REPO_ROOT/ops/plugins/domains/mint/bin/printavo-bridge-snapshot"
QUOTE_POLICY_CONTRACT="$REPO_ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
QUOTE_CONTEXT_CONTRACT="$REPO_ROOT/ops/bindings/mint.customer.quote.context.contract.yaml"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$CUSTOMER_SNAPSHOT" ]] || fail "missing customer-record-snapshot executable"
[[ -x "$PAYMENT_SNAPSHOT" ]] || fail "missing payment-record-snapshot executable"
[[ -x "$ARTIFACT_SNAPSHOT" ]] || fail "missing artifact-record-snapshot executable"
[[ -x "$PRINTAVO_SNAPSHOT" ]] || fail "missing printavo-bridge-snapshot executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fixture="$tmp/customers.json"
test_spine_root="$tmp/spine"
state_root="$tmp/state"
orders_dir="$tmp/orders"
orders_index="$tmp/orders-index.yaml"
artifacts_dir="$tmp/artifacts"
artifacts_index="$tmp/artifacts-index.yaml"
payment_captures_dir="$tmp/payment-captures"
payment_captures_index="$tmp/payment-captures-index.yaml"

mkdir -p "$test_spine_root/bin" "$state_root" "$orders_dir" "$artifacts_dir" "$payment_captures_dir"

cat >"$fixture" <<'JSON'
[
  {
    "record_id": "cust-1",
    "email": "jason.beeker@example.com",
    "name": "Jason Beeker",
    "first_name": "Jason",
    "last_name": "Beeker",
    "company": "Hit Promo"
  }
]
JSON

cat >"$orders_dir/order_order-1.yaml" <<'YAML'
order_id: order-1
current_revision_id: rev-1
active_quote_id: quote-1
customer_identity_state: resolved
customer_id: cust-1
customer_name: Jason Beeker
customer_email: jason.beeker@example.com
lifecycle_state: approved
payment_state: paid
payment_summary:
  schema_version: "1.0"
  visibility_state: confirmed_in_records
  source_kind: manual_operator_capture
  record_kind: payment_capture
  record_id: cap-1
  payment_state: paid
  amount_cents: 24000
  currency: USD
  captured_at: "2026-03-12T17:15:00Z"
  recorded_at: "2026-03-12T17:15:10Z"
  captured_by: ronny
  reference: JASON-BEEKER-HIT-PROMO
  note: customer paid manually
source_quote_packet_id: packet-1
created_at: "2026-03-12T16:00:00Z"
updated_at: "2026-03-12T17:15:10Z"
YAML

cat >"$orders_index" <<'YAML'
orders:
  - order_id: order-1
    current_revision_id: rev-1
    active_quote_id: quote-1
    customer_id: cust-1
    customer_email: jason.beeker@example.com
    customer_name: Jason Beeker
    lifecycle_state: approved
    payment_state: paid
    payment_visibility_state: confirmed_in_records
    payment_source_kind: manual_operator_capture
    payment_record_id: cap-1
    source_quote_packet_id: packet-1
    created_at: "2026-03-12T16:00:00Z"
    updated_at: "2026-03-12T17:15:10Z"
YAML

cat >"$payment_captures_index" <<'YAML'
payment_captures:
  - payment_capture_id: cap-1
    order_id: order-1
    quote_id: quote-1
    customer_id: cust-1
    customer_email: jason.beeker@example.com
    customer_name: Jason Beeker
    source_quote_packet_id: packet-1
    payment_state: paid
    visibility_state: confirmed_in_records
    source_kind: manual_operator_capture
    amount_cents: 24000
    currency: USD
    captured_at: "2026-03-12T17:15:00Z"
    recorded_at: "2026-03-12T17:15:10Z"
    captured_by: ronny
    reference: JASON-BEEKER-HIT-PROMO
YAML

cat >"$test_spine_root/bin/ops" <<EOF
#!/usr/bin/env bash
set -euo pipefail

capability="\${3:-}"
shift 3 || true
if [[ "\${1:-}" == "--" ]]; then
  shift
fi

echo "Receipt: /tmp/\${capability}.receipt.md"

case "\$capability" in
  mint.seeds.query)
    echo '{"rows":[]}'
    ;;
  mint.artifact.record.snapshot)
    MINT_RUNTIME_ROOT="$tmp" \
    MINT_ARTIFACT_DIR="$artifacts_dir" \
    MINT_ARTIFACT_INDEX_FILE="$artifacts_index" \
    "$ARTIFACT_SNAPSHOT" "\$@"
    ;;
  mint.payment.record.snapshot)
    MINT_ORDER_RUNTIME_DIR="$orders_dir" \
    MINT_ORDER_INDEX_FILE="$orders_index" \
    MINT_PAYMENT_CAPTURE_DIR="$payment_captures_dir" \
    MINT_PAYMENT_CAPTURE_INDEX_FILE="$payment_captures_index" \
    "$PAYMENT_SNAPSHOT" "\$@"
    ;;
  mint.printavo.bridge.snapshot)
    cat <<'JSON'
{"capability":"mint.printavo.bridge.snapshot","query_mode":"email","query_value":"jason.beeker@example.com","state":"quote_live","match_count":1,"latest":{"order_id":"order-1","quote_id":"quote-1","seed_id":"seed-jason-1","customer_id":"cust-1","customer_email":"jason.beeker@example.com","customer_name":"Jason Beeker","printavo_state":"quote_live","printavo_summary":{"schema_version":"1.0","printavo_state":"quote_live","printavo_customer_id":"998877","printavo_invoice_url":"https://www.printavo.com/invoices/21990001","printavo_public_invoice_url":"https://mint-prints-4019cb.printavo.com/invoice/jason-hitpromo","printavo_work_order_url":null,"printavo_visual_id":"13842","last_reconciled_at":"2026-03-12T17:18:00Z","source_kind":"legacy_backfill","record_kind":"printavo_bridge","record_id":"pb-jason-1","provenance":{"source":"legacy_backfill","basis":["legacy_orders_export"]}},"latest_printavo_bridge":{"printavo_bridge_id":"pb-jason-1","printavo_state":"quote_live","recorded_at":"2026-03-12T17:18:00Z"},"source_quote_packet_id":"packet-1","updated_at":"2026-03-12T17:18:00Z"},"matches":[{"order_id":"order-1","quote_id":"quote-1","seed_id":"seed-jason-1","customer_id":"cust-1","customer_email":"jason.beeker@example.com","customer_name":"Jason Beeker","printavo_state":"quote_live","printavo_summary":{"schema_version":"1.0","printavo_state":"quote_live","printavo_customer_id":"998877","printavo_invoice_url":"https://www.printavo.com/invoices/21990001","printavo_public_invoice_url":"https://mint-prints-4019cb.printavo.com/invoice/jason-hitpromo","printavo_work_order_url":null,"printavo_visual_id":"13842","last_reconciled_at":"2026-03-12T17:18:00Z","source_kind":"legacy_backfill","record_kind":"printavo_bridge","record_id":"pb-jason-1","provenance":{"source":"legacy_backfill","basis":["legacy_orders_export"]}},"latest_printavo_bridge":{"printavo_bridge_id":"pb-jason-1","printavo_state":"quote_live","recorded_at":"2026-03-12T17:18:00Z"},"source_quote_packet_id":"packet-1","updated_at":"2026-03-12T17:18:00Z"}]}
JSON
    ;;
  mint.artwork.intelligence.snapshot)
    cat <<'JSON'
{"capability":"mint.artwork.intelligence.snapshot","query_mode":"email","query_value":"jason.beeker@example.com","state":"analysis_present_review_required","match_count":1,"latest":{"analysis_id":"analysis-jason-1","seed_id":"seed-jason-1","customer_id":"cust-1","customer_email":"jason.beeker@example.com","customer_name":"Jason Beeker","order_id":"order-1","thread_id":"CONV-JASON","relationship_counts":{"exact_reuse":1},"color_counts":{"unknown":1},"review_required_count":1,"created_at":"2026-03-12T17:20:00Z"},"matches":[{"analysis_id":"analysis-jason-1","seed_id":"seed-jason-1","customer_id":"cust-1","customer_email":"jason.beeker@example.com","customer_name":"Jason Beeker","order_id":"order-1","thread_id":"CONV-JASON","relationship_counts":{"exact_reuse":1},"color_counts":{"unknown":1},"review_required_count":1,"created_at":"2026-03-12T17:20:00Z"}]}
JSON
    ;;
  *)
    echo "unsupported capability: \$capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$test_spine_root/bin/ops"

export SPINE_ROOT="$test_spine_root"
export SPINE_STATE="$state_root"
export MINT_CUSTOMER_RECORD_FIXTURE_FILE="$fixture"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$QUOTE_POLICY_CONTRACT"
export MINT_CUSTOMER_QUOTE_CONTEXT_CONTRACT="$QUOTE_CONTEXT_CONTRACT"

json_snapshot="$(
  MINT_ORDER_RUNTIME_DIR="$orders_dir" \
  MINT_ORDER_INDEX_FILE="$orders_index" \
  MINT_PAYMENT_CAPTURE_DIR="$payment_captures_dir" \
  MINT_PAYMENT_CAPTURE_INDEX_FILE="$payment_captures_index" \
  "$CUSTOMER_SNAPSHOT" --email jason.beeker@example.com --json
)"

[[ "$(echo "$json_snapshot" | jq -r '.payment_visibility.state')" == "confirmed_in_records" ]] || fail "customer snapshot should surface payment visibility state"
[[ "$(echo "$json_snapshot" | jq -r '.artifact_visibility.state')" == "no_artifact_found" ]] || fail "customer snapshot should surface artifact visibility state"
[[ "$(echo "$json_snapshot" | jq -r '.payment_visibility.latest.payment_summary.source_kind')" == "manual_operator_capture" ]] || fail "customer snapshot should surface payment provenance"
[[ "$(echo "$json_snapshot" | jq -r '.payment_visibility.latest.payment_summary.reference')" == "JASON-BEEKER-HIT-PROMO" ]] || fail "customer snapshot should surface payment reference"
[[ "$(echo "$json_snapshot" | jq -r '.artwork_intelligence_visibility.state')" == "analysis_present_review_required" ]] || fail "customer snapshot should surface artwork intelligence state"
[[ "$(echo "$json_snapshot" | jq -r '.artwork_intelligence_visibility.latest.analysis_id')" == "analysis-jason-1" ]] || fail "customer snapshot should surface artwork intelligence id"
[[ "$(echo "$json_snapshot" | jq -r '.printavo_visibility.state')" == "quote_live" ]] || fail "customer snapshot should surface Printavo visibility state"
[[ "$(echo "$json_snapshot" | jq -r '.printavo_visibility.latest.printavo_summary.printavo_visual_id')" == "13842" ]] || fail "customer snapshot should surface Printavo visual id"
[[ "$(echo "$json_snapshot" | jq -r '.receipts.artifact_snapshot_receipt')" == "/tmp/mint.artifact.record.snapshot.receipt.md" ]] || fail "customer snapshot should keep artifact snapshot receipt"
[[ "$(echo "$json_snapshot" | jq -r '.receipts.artwork_intelligence_snapshot_receipt')" == "/tmp/mint.artwork.intelligence.snapshot.receipt.md" ]] || fail "customer snapshot should keep artwork intelligence receipt"
[[ "$(echo "$json_snapshot" | jq -r '.receipts.printavo_snapshot_receipt')" == "/tmp/mint.printavo.bridge.snapshot.receipt.md" ]] || fail "customer snapshot should keep Printavo snapshot receipt"
[[ "$(echo "$json_snapshot" | jq -r '.receipts.payment_snapshot_receipt')" == "/tmp/mint.payment.record.snapshot.receipt.md" ]] || fail "customer snapshot should keep payment snapshot receipt"

pass "customer-record-snapshot surfaces governed artifact, artwork-intelligence, Printavo, and payment visibility for Morpheus"
