#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"
SNAPSHOT="$REPO_ROOT/ops/plugins/domains/mint/bin/printavo-bridge-snapshot"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$SNAPSHOT" ]] || fail "missing printavo-bridge-snapshot executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

test_spine_root="$tmp/spine"
orders_dir="$tmp/orders"
quotes_dir="$tmp/quotes"
bridges_index="$tmp/printavo-bridges-index.yaml"
customer_fixture="$tmp/customers.json"

mkdir -p "$test_spine_root/bin" "$orders_dir" "$quotes_dir"

cat >"$customer_fixture" <<'JSON'
[
  {
    "record_id": "cust-acme",
    "email": "hello@acme.example.com",
    "name": "Acme Events",
    "company": "Acme Events",
    "metadata": {
      "legacy_row": {
        "printavo_id": "5276540"
      }
    }
  }
]
JSON

cat >"$orders_dir/order_order-needs.yaml" <<'YAML'
order_id: order-needs
current_revision_id: rev-needs
active_quote_id: quote-needs
customer_id: cust-acme
customer_email: hello@acme.example.com
customer_name: Acme Events
lifecycle_state: quoted
payment_state: unpaid
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
intake_seed_refs:
  - seed-needs-1
source_quote_packet_id: packet-needs
updated_at: "2026-03-13T16:00:00Z"
YAML

cat >"$quotes_dir/quote_quote-needs.yaml" <<'YAML'
quote_id: quote-needs
order_id: order-needs
YAML

cat >"$bridges_index" <<'YAML'
printavo_bridges:
  - printavo_bridge_id: pb-1
    seed_id: seed-bridge-1
    order_id: null
    quote_id: null
    customer_id: cust-acme
    customer_email: hello@acme.example.com
    customer_name: Acme Events
    printavo_customer_id: "5276540"
    printavo_invoice_url: https://www.printavo.com/invoices/21599999
    printavo_public_invoice_url: https://mint-prints-4019cb.printavo.com/invoice/public-acme-13799
    printavo_work_order_url: https://mint-prints-4019cb.printavo.com/work_orders/acme-13799
    printavo_visual_id: "13799"
    printavo_state: converted_to_work_order
    source_kind: legacy_backfill
    source_quote_packet_id: null
    last_reconciled_at: "2026-03-13T16:10:00Z"
    recorded_at: "2026-03-13T16:10:00Z"
YAML

cat >"$test_spine_root/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi
case "$capability" in
  mint.seeds.query)
    if [[ "${1:-}" == "--json" && "${2:-}" == "--seed-id" && "${3:-}" == "seed-bridge-1" ]]; then
      echo '{"rows":[{"seed_id":"seed-bridge-1","customer_email":"hello@acme.example.com"}]}'
    elif [[ "${1:-}" == "--json" && "${2:-}" == "--seed-id" && "${3:-}" == "seed-needs-1" ]]; then
      echo '{"rows":[{"seed_id":"seed-needs-1","customer_email":"hello@acme.example.com"}]}'
    elif [[ "${1:-}" == "--json" && "${2:-}" == "--email" && "${3:-}" == "hello@acme.example.com" ]]; then
      echo '{"rows":[{"seed_id":"seed-needs-1","customer_email":"hello@acme.example.com"}]}'
    else
      echo '{"rows":[]}'
    fi
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$test_spine_root/bin/ops"

export SPINE_ROOT="$test_spine_root"
export MINT_CUSTOMER_RECORD_FIXTURE_FILE="$customer_fixture"

order_json="$(
  MINT_ORDER_RUNTIME_DIR="$orders_dir" \
  MINT_QUOTES_DIR="$quotes_dir" \
  MINT_PRINTAVO_BRIDGES_INDEX_FILE="$bridges_index" \
  "$SNAPSHOT" --order-id order-needs --json
)"
[[ "$(echo "$order_json" | jq -r '.state')" == "needs_more_info_before_printavo" ]] || fail "order snapshot should preserve boring default Printavo state"
[[ "$(echo "$order_json" | jq -r '.latest.printavo_summary.printavo_state')" == "needs_more_info_before_printavo" ]] || fail "order snapshot should surface default summary state"

seed_json="$(
  MINT_ORDER_RUNTIME_DIR="$orders_dir" \
  MINT_QUOTES_DIR="$quotes_dir" \
  MINT_PRINTAVO_BRIDGES_INDEX_FILE="$bridges_index" \
  "$SNAPSHOT" --seed-id seed-bridge-1 --json
)"
[[ "$(echo "$seed_json" | jq -r '.state')" == "converted_to_work_order" ]] || fail "seed snapshot should surface recovered bridge state"
[[ "$(echo "$seed_json" | jq -r '.latest.printavo_summary.printavo_work_order_url')" == "https://mint-prints-4019cb.printavo.com/work_orders/acme-13799" ]] || fail "seed snapshot should surface recovered work order url"

email_json="$(
  MINT_ORDER_RUNTIME_DIR="$orders_dir" \
  MINT_QUOTES_DIR="$quotes_dir" \
  MINT_PRINTAVO_BRIDGES_INDEX_FILE="$bridges_index" \
  "$SNAPSHOT" --email hello@acme.example.com --json
)"
[[ "$(echo "$email_json" | jq -r '.latest.printavo_summary.printavo_customer_id')" == "5276540" ]] || fail "email snapshot should surface fresh customer printavo id"
pass "printavo bridge snapshot distinguishes default needs-more-info state from bridged Printavo truth"
