#!/usr/bin/env bash
# test-production-readiness-check.sh - Validate canonical Mint production readiness evaluation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PROMOTE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-promote"
PRODUCTION_READINESS_CHECK="$SPINE_ROOT/ops/plugins/domains/mint/bin/production-readiness-check"
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
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_prod-ready.yaml"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_prod-blocked.yaml"
yq -i '.quote_packet_id = "prod-ready"' "$PACKETS_DIR/quote_packet_prod-ready.yaml"
yq -i '.quote_packet_id = "prod-blocked"' "$PACKETS_DIR/quote_packet_prod-blocked.yaml"

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

run_check() {
  MINT_ORDER_RUNTIME_DIR="$ORDERS_DIR" \
  MINT_ORDER_REVISIONS_DIR="$ORDER_REVISIONS_DIR" \
  MINT_ARTWORK_BINDINGS_DIR="$ARTWORK_BINDINGS_DIR" \
  "$PRODUCTION_READINESS_CHECK" "$@"
}

promote_fixture() {
  local packet_id="$1"
  run_promote "$packet_id" --approved-by MINT-OPERATOR-01 >/dev/null
  local packet_file="$PACKETS_DIR/quote_packet_${packet_id}.yaml"
  local order_id
  local order_revision_id
  local binding_id
  order_id="$(yq '.order_id' "$packet_file")"
  order_revision_id="$(yq '.order_revision_id' "$packet_file")"
  binding_id="$(yq '.line_items[0].artwork_binding_ref' "$packet_file")"
  echo "$order_id|$order_revision_id|$binding_id"
}

section "Ready order reports ready for governed production handoff"
IFS='|' read -r ready_order_id ready_revision_id ready_binding_id <<<"$(promote_fixture prod-ready)"
yq -i '.lifecycle_state = "approved" | .payment_state = "paid"' "$ORDERS_DIR/order_${ready_order_id}.yaml"
yq -i '.selection_state = "approved" | .asset_refs = ["minio://client-assets/Acme%20Events/30100/3.%20Production%20Files/acme-front.eps"]' \
  "$ARTWORK_BINDINGS_DIR/artwork_binding_${ready_binding_id}.yaml"

ready_output="$(run_check "$ready_order_id" --json)"
echo "$ready_output" | jq -e '.production_readiness_state == "ready"' >/dev/null || fail "ready order must report readiness_state=ready"
echo "$ready_output" | jq -e '.recommended_next_step == "mint.production.handoff.create"' >/dev/null || fail "ready order must recommend handoff creation"
echo "$ready_output" | jq -e '.target_classes == ["screen_print_press"]' >/dev/null || fail "ready order must infer screen_print_press target class"
echo "$ready_output" | jq -e '.lines[0].artwork_selection_state == "approved"' >/dev/null || fail "ready line must report approved artwork"
echo "$ready_output" | jq -e '.lines[0].production_asset_refs[0] | endswith(".eps")' >/dev/null || fail "ready line must surface production asset refs"
pass "production readiness check reports a paid approved order as ready"

section "Blocked order reports honest payment and artwork blockers"
IFS='|' read -r blocked_order_id blocked_revision_id blocked_binding_id <<<"$(promote_fixture prod-blocked)"
blocked_output="$(run_check "$blocked_order_id" --json)"
echo "$blocked_output" | jq -e '.production_readiness_state == "blocked"' >/dev/null || fail "blocked order must report readiness_state=blocked"
echo "$blocked_output" | jq -e '.blocking_reasons | any(. == "order payment_state is unpaid (must be paid)")' >/dev/null || fail "blocked order must explain unpaid payment state"
echo "$blocked_output" | jq -e '.blocking_reasons | any(contains("artwork_binding selection_state is mapped"))' >/dev/null || fail "blocked order must explain non-approved artwork"
echo "$blocked_output" | jq -e '.recommended_next_step == "collect full payment and reconcile canonical order payment state"' >/dev/null || fail "blocked order must recommend payment reconciliation first"
pass "production readiness check blocks unpaid or unapproved production truth honestly"

section "Summary"
echo "Production readiness checks passed"
