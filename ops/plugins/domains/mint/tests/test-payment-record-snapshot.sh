#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PROMOTE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-promote"
PAYMENT_CAPTURE="$SPINE_ROOT/ops/plugins/domains/mint/bin/payment-record-capture"
PAYMENT_SNAPSHOT="$SPINE_ROOT/ops/plugins/domains/mint/bin/payment-record-snapshot"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-promote"
TMP_ROOT="$(mktemp -d)"
PACKETS_DIR="$TMP_ROOT/quote-packets"
ORDERS_DIR="$TMP_ROOT/orders"
ORDER_REVISIONS_DIR="$TMP_ROOT/order-revisions"
QUOTES_DIR="$TMP_ROOT/quotes"
PRICING_SNAPSHOTS_DIR="$TMP_ROOT/pricing-snapshots"
ARTWORK_BINDINGS_DIR="$TMP_ROOT/artwork-bindings"
PAYMENT_CAPTURES_DIR="$TMP_ROOT/payment-captures"
PACKET_INDEX="$TMP_ROOT/quote-packets-index.yaml"
ORDERS_INDEX="$TMP_ROOT/orders-index.yaml"
ORDER_REVISIONS_INDEX="$TMP_ROOT/order-revisions-index.yaml"
QUOTES_INDEX="$TMP_ROOT/quotes-index.yaml"
PRICING_SNAPSHOTS_INDEX="$TMP_ROOT/pricing-snapshots-index.yaml"
ARTWORK_BINDINGS_INDEX="$TMP_ROOT/artwork-bindings-index.yaml"
PAYMENT_CAPTURES_INDEX="$TMP_ROOT/payment-captures-index.yaml"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

mkdir -p "$PACKETS_DIR"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_payment-snapshot.yaml"
yq -i '.quote_packet_id = "payment-snapshot"' "$PACKETS_DIR/quote_packet_payment-snapshot.yaml"

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

run_capture() {
  MINT_ORDER_RUNTIME_DIR="$ORDERS_DIR" \
  MINT_ORDER_INDEX_FILE="$ORDERS_INDEX" \
  MINT_QUOTES_DIR="$QUOTES_DIR" \
  MINT_QUOTES_INDEX_FILE="$QUOTES_INDEX" \
  MINT_PAYMENT_CAPTURE_DIR="$PAYMENT_CAPTURES_DIR" \
  MINT_PAYMENT_CAPTURE_INDEX_FILE="$PAYMENT_CAPTURES_INDEX" \
  "$PAYMENT_CAPTURE" "$@"
}

run_snapshot() {
  MINT_ORDER_RUNTIME_DIR="$ORDERS_DIR" \
  MINT_ORDER_INDEX_FILE="$ORDERS_INDEX" \
  MINT_QUOTES_DIR="$QUOTES_DIR" \
  MINT_QUOTES_INDEX_FILE="$QUOTES_INDEX" \
  MINT_PAYMENT_CAPTURE_DIR="$PAYMENT_CAPTURES_DIR" \
  MINT_PAYMENT_CAPTURE_INDEX_FILE="$PAYMENT_CAPTURES_INDEX" \
  "$PAYMENT_SNAPSHOT" "$@"
}

section "Promote canonical order before snapshot checks"
run_promote payment-snapshot --approved-by MINT-OPERATOR-01 >/dev/null
packet_file="$PACKETS_DIR/quote_packet_payment-snapshot.yaml"
order_id="$(yq '.order_id' "$packet_file")"
quote_id="$(yq '.quote_id' "$packet_file")"
customer_id="$(yq '.customer_id' "$ORDERS_DIR/order_${order_id}.yaml")"
customer_email="$(yq '.customer_email' "$ORDERS_DIR/order_${order_id}.yaml")"

section "Snapshot distinguishes unpaid truth from confirmed payment"
before_json="$(run_snapshot --email "$customer_email" --json)"
[[ "$(echo "$before_json" | jq -r '.state')" == "not_yet_visible" ]] || fail "snapshot should report not_yet_visible before payment capture"
[[ "$(echo "$before_json" | jq -r '.latest.payment_state')" == "unpaid" ]] || fail "snapshot should surface unpaid order state before capture"
[[ "$(echo "$before_json" | jq -r '.latest.payment_visibility_state')" == "not_yet_visible" ]] || fail "snapshot should surface not_yet_visible before capture"

run_capture --order-id "$order_id" --payment-state partially_paid --amount-cents 50000 --captured-by ronny --captured-at 2026-03-12T17:10:00Z --reference DEPOSIT-001 >/dev/null

after_quote_json="$(run_snapshot --quote-id "$quote_id" --json)"
after_customer_json="$(run_snapshot --customer-id "$customer_id" --json)"

[[ "$(echo "$after_quote_json" | jq -r '.state')" == "confirmed_in_records" ]] || fail "snapshot should report confirmed_in_records after capture"
[[ "$(echo "$after_quote_json" | jq -r '.latest.payment_state')" == "partially_paid" ]] || fail "snapshot should surface partially_paid after deposit capture"
[[ "$(echo "$after_quote_json" | jq -r '.latest.payment_summary.source_kind')" == "manual_operator_capture" ]] || fail "snapshot should surface manual operator provenance"
[[ "$(echo "$after_quote_json" | jq -r '.latest.latest_payment_capture.reference')" == "DEPOSIT-001" ]] || fail "snapshot should surface the latest capture reference"
[[ "$(echo "$after_customer_json" | jq -r '.match_count')" == "1" ]] || fail "customer-id snapshot should resolve the matching order"
pass "payment snapshot distinguishes not-yet-visible from confirmed-in-records truth"

section "Summary"
echo "Payment record snapshot checks passed"
