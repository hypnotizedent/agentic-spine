#!/usr/bin/env bash
# test-quote-promote.sh - Validate governed quote_packet promotion into canonical order truth records

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PROMOTE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-promote"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-promote"
TMP_ROOT="$(mktemp -d)"
PACKETS_DIR="$TMP_ROOT/quote-packets"
ORDERS_DIR="$TMP_ROOT/orders"
ORDER_REVISIONS_DIR="$TMP_ROOT/order-revisions"
QUOTES_DIR="$TMP_ROOT/quotes"
PRICING_SNAPSHOTS_DIR="$TMP_ROOT/pricing-snapshots"
ARTWORK_BINDINGS_DIR="$TMP_ROOT/artwork-bindings"
PACKET_INDEX="$TMP_ROOT/quote-packets-index.yaml"
ORDERS_INDEX="$TMP_ROOT/orders-index.yaml"
ORDER_REVISIONS_INDEX="$TMP_ROOT/order-revisions-index.yaml"
QUOTES_INDEX="$TMP_ROOT/quotes-index.yaml"
PRICING_SNAPSHOTS_INDEX="$TMP_ROOT/pricing-snapshots-index.yaml"
ARTWORK_BINDINGS_INDEX="$TMP_ROOT/artwork-bindings-index.yaml"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

mkdir -p "$PACKETS_DIR"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_promote-approved.yaml"
cp "$FIXTURES_DIR/missing-seed.packet.yaml" "$PACKETS_DIR/quote_packet_promote-missing-seed.yaml"

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

section "Promote approved packet into canonical order truth"
promote_output="$(run_promote promote-approved --approved-by MINT-OPERATOR-01 --approval-note "reviewed for canonical promotion")"
approved_packet="$PACKETS_DIR/quote_packet_promote-approved.yaml"
order_id="$(yq '.order_id' "$approved_packet")"
order_revision_id="$(yq '.order_revision_id' "$approved_packet")"
quote_id="$(yq '.quote_id' "$approved_packet")"
pricing_snapshot_id="$(yq '.pricing_snapshot.pricing_snapshot_id' "$approved_packet")"

[[ -n "$order_id" && "$order_id" != "null" ]] || fail "promotion must persist order_id back to packet"
[[ -n "$order_revision_id" && "$order_revision_id" != "null" ]] || fail "promotion must persist order_revision_id back to packet"
[[ -n "$quote_id" && "$quote_id" != "null" ]] || fail "promotion must persist quote_id back to packet"
[[ "$(yq '.state' "$approved_packet")" == "approved_to_send" ]] || fail "promotion must preserve approved_to_send state"
[[ -f "$ORDERS_DIR/order_${order_id}.yaml" ]] || fail "canonical order file missing"
[[ -f "$ORDER_REVISIONS_DIR/order_revision_${order_revision_id}.yaml" ]] || fail "canonical order_revision file missing"
[[ -f "$QUOTES_DIR/quote_${quote_id}.yaml" ]] || fail "canonical quote file missing"
[[ -f "$PRICING_SNAPSHOTS_DIR/pricing_snapshot_${pricing_snapshot_id}.yaml" ]] || fail "canonical pricing_snapshot file missing"
[[ "$(yq '.lifecycle_state' "$ORDERS_DIR/order_${order_id}.yaml")" == "quoted" ]] || fail "order lifecycle_state must be quoted after promotion"
[[ "$(yq '.payment_state' "$ORDERS_DIR/order_${order_id}.yaml")" == "unpaid" ]] || fail "order payment_state must start unpaid"
[[ "$(yq '.payment_summary.visibility_state' "$ORDERS_DIR/order_${order_id}.yaml")" == "not_yet_visible" ]] || fail "order payment_summary must start not_yet_visible"
[[ "$(yq '.payment_summary.source_kind' "$ORDERS_DIR/order_${order_id}.yaml")" == "none" ]] || fail "order payment_summary must start with neutral source_kind"
[[ "$(yq '.printavo_summary.printavo_state' "$ORDERS_DIR/order_${order_id}.yaml")" == "needs_more_info_before_printavo" ]] || fail "order printavo_summary must start with the boring needs_more_info state"
[[ "$(yq '.printavo_summary.source_kind' "$ORDERS_DIR/order_${order_id}.yaml")" == "none" ]] || fail "order printavo_summary must start with neutral source_kind"
[[ "$(yq '.quote_state' "$QUOTES_DIR/quote_${quote_id}.yaml")" == "draft" ]] || fail "promoted quote must start in draft state"
[[ "$(yq '.quote_readiness.state' "$approved_packet")" == "ready_for_operator_send" ]] || fail "approved packet should surface ready_for_operator_send readiness"
[[ "$(yq '.quote_readiness.send_ready' "$approved_packet")" == "true" ]] || fail "approved packet should be send_ready after promotion"
[[ "$(yq '.line_items[0].order_line_id' "$ORDER_REVISIONS_DIR/order_revision_${order_revision_id}.yaml")" == "550e8400-e29b-41d4-a716-446655440000" ]] || fail "first promotion must reuse quote_packet line_item_id as canonical order_line_id"
[[ "$(yq '.line_items[0].artwork_binding_ref' "$approved_packet")" != "null" ]] || fail "promotion must write artwork_binding_ref back to packet line items when bindings exist"
[[ "$(yq '.artwork_bindings | length' "$ARTWORK_BINDINGS_INDEX")" == "1" ]] || fail "artwork binding index must record the promoted binding"
[[ "$(yq '.orders[0].payment_visibility_state' "$ORDERS_INDEX")" == "not_yet_visible" ]] || fail "orders index must surface default payment visibility"
[[ "$(yq '.orders[0].printavo_state' "$ORDERS_INDEX")" == "needs_more_info_before_printavo" ]] || fail "orders index must surface default printavo state"
[[ "$(yq '.orders[0].customer_email' "$ORDERS_INDEX")" == "hello@acme.example.com" ]] || fail "orders index must surface customer_email for payment visibility reads"
grep -Fq "promotion_state: promoted" <<<"$promote_output" || fail "promote output must report a promoted transition"
pass "quote-promote persists canonical order/revision/quote/pricing truth from an approved packet"

section "Re-running promote stays idempotent"
rerun_output="$(run_promote promote-approved --approved-by MINT-OPERATOR-01)"
[[ "$(yq '.orders | length' "$ORDERS_INDEX")" == "1" ]] || fail "idempotent rerun must not duplicate order index entries"
[[ "$(yq '.quotes | length' "$QUOTES_INDEX")" == "1" ]] || fail "idempotent rerun must not duplicate quote index entries"
grep -Fq "promotion_state: existing" <<<"$rerun_output" || fail "rerun output must report existing promotion state"
pass "quote-promote reuses existing canonical refs on rerun"

section "Promotion blocks honestly when seed evidence is missing"
set +e
blocked_output="$(run_promote promote-missing-seed --approved-by MINT-OPERATOR-01 2>&1)"
blocked_rc=$?
set -e
[[ "$blocked_rc" -ne 0 ]] || fail "missing seed packet should not promote successfully"
grep -Fq "packet has no intake seed reference to promote" <<<"$blocked_output" || fail "blocked promote must explain the missing seed reference"
[[ "$(yq '.order_id' "$PACKETS_DIR/quote_packet_promote-missing-seed.yaml")" == "null" ]] || fail "blocked promote must not stamp canonical refs onto the packet"
pass "quote-promote refuses packets that still lack canonical intake seed lineage"

section "Summary"
echo "Quote promotion checks passed"
