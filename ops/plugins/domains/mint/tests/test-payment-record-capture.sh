#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PROMOTE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-promote"
PAYMENT_CAPTURE="$SPINE_ROOT/ops/plugins/domains/mint/bin/payment-record-capture"
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
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_payment-capture.yaml"
yq -i '.quote_packet_id = "payment-capture"' "$PACKETS_DIR/quote_packet_payment-capture.yaml"

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

section "Promote a canonical order before payment capture"
run_promote payment-capture --approved-by MINT-OPERATOR-01 >/dev/null
packet_file="$PACKETS_DIR/quote_packet_payment-capture.yaml"
order_id="$(yq '.order_id' "$packet_file")"
quote_id="$(yq '.quote_id' "$packet_file")"
order_file="$ORDERS_DIR/order_${order_id}.yaml"

section "Manual payment capture persists immutable evidence and projects order truth"
capture_json="$(run_capture --quote-id "$quote_id" --payment-state paid --captured-by ronny --captured-at 2026-03-12T17:00:00Z --reference MANUAL-CHK-001 --note "check received at front desk" --json)"
capture_id="$(echo "$capture_json" | jq -r '.payment_capture_id')"
capture_file="$PAYMENT_CAPTURES_DIR/payment_capture_${capture_id}.yaml"

[[ -f "$capture_file" ]] || fail "payment capture record should exist"
[[ "$(echo "$capture_json" | jq -r '.capture_state')" == "recorded" ]] || fail "first capture should report recorded"
[[ "$(echo "$capture_json" | jq -r '.amount_cents')" == "121968" ]] || fail "paid capture should infer amount_cents from the canonical quote"
[[ "$(yq '.payment_state' "$order_file")" == "paid" ]] || fail "manual capture must project order payment_state=paid"
[[ "$(yq '.payment_summary.visibility_state' "$order_file")" == "confirmed_in_records" ]] || fail "manual capture must mark payment visibility confirmed"
[[ "$(yq '.payment_summary.source_kind' "$order_file")" == "manual_operator_capture" ]] || fail "manual capture must record source_kind"
[[ "$(yq '.payment_summary.record_id' "$order_file")" == "$capture_id" ]] || fail "manual capture must link the immutable capture id"
[[ "$(yq '.payment_summary.reference' "$order_file")" == "MANUAL-CHK-001" ]] || fail "manual capture must persist reference"
[[ "$(yq '.lifecycle_state' "$order_file")" == "approved" ]] || fail "manual paid capture must advance quoted orders to approved"
[[ "$(yq '.orders[0].payment_visibility_state' "$ORDERS_INDEX")" == "confirmed_in_records" ]] || fail "orders index must surface payment visibility"
[[ "$(yq '.orders[0].payment_source_kind' "$ORDERS_INDEX")" == "manual_operator_capture" ]] || fail "orders index must surface payment source"
[[ "$(yq '.payment_captures | length' "$PAYMENT_CAPTURES_INDEX")" == "1" ]] || fail "payment capture index must record the capture"
pass "manual payment capture creates immutable evidence and updates canonical order truth"

section "Re-running the same capture is idempotent"
rerun_json="$(run_capture --quote-id "$quote_id" --payment-state paid --captured-by ronny --captured-at 2026-03-12T17:00:00Z --reference MANUAL-CHK-001 --note "check received at front desk" --json)"
[[ "$(echo "$rerun_json" | jq -r '.capture_state')" == "existing" ]] || fail "identical capture rerun should report existing"
[[ "$(yq '.payment_captures | length' "$PAYMENT_CAPTURES_INDEX")" == "1" ]] || fail "identical capture rerun must not duplicate capture index entries"
pass "manual payment capture is idempotent for identical receipts"

section "Summary"
echo "Payment record capture checks passed"
