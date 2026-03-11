#!/usr/bin/env bash
# test-production-handoff-create.sh - Validate canonical Mint production handoff creation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PROMOTE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-promote"
PRODUCTION_HANDOFF_CREATE="$SPINE_ROOT/ops/plugins/domains/mint/bin/production-handoff-create"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-promote"
TMP_ROOT="$(mktemp -d)"
PACKETS_DIR="$TMP_ROOT/quote-packets"
ORDERS_DIR="$TMP_ROOT/orders"
ORDER_REVISIONS_DIR="$TMP_ROOT/order-revisions"
QUOTES_DIR="$TMP_ROOT/quotes"
PRICING_SNAPSHOTS_DIR="$TMP_ROOT/pricing-snapshots"
ARTWORK_BINDINGS_DIR="$TMP_ROOT/artwork-bindings"
PRODUCTION_HANDOFFS_DIR="$TMP_ROOT/production-handoffs"
PACKET_INDEX="$TMP_ROOT/quote-packets-index.yaml"
ORDERS_INDEX="$TMP_ROOT/orders-index.yaml"
ORDER_REVISIONS_INDEX="$TMP_ROOT/order-revisions-index.yaml"
QUOTES_INDEX="$TMP_ROOT/quotes-index.yaml"
PRICING_SNAPSHOTS_INDEX="$TMP_ROOT/pricing-snapshots-index.yaml"
ARTWORK_BINDINGS_INDEX="$TMP_ROOT/artwork-bindings-index.yaml"
PRODUCTION_HANDOFFS_INDEX="$TMP_ROOT/production-handoffs-index.yaml"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

mkdir -p "$PACKETS_DIR"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_handoff-ready.yaml"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_handoff-blocked.yaml"
yq -i '.quote_packet_id = "handoff-ready"' "$PACKETS_DIR/quote_packet_handoff-ready.yaml"
yq -i '.quote_packet_id = "handoff-blocked"' "$PACKETS_DIR/quote_packet_handoff-blocked.yaml"

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

run_handoff() {
  MINT_ORDER_RUNTIME_DIR="$ORDERS_DIR" \
  MINT_ORDER_REVISIONS_DIR="$ORDER_REVISIONS_DIR" \
  MINT_QUOTES_DIR="$QUOTES_DIR" \
  MINT_ARTWORK_BINDINGS_DIR="$ARTWORK_BINDINGS_DIR" \
  MINT_PRODUCTION_HANDOFFS_DIR="$PRODUCTION_HANDOFFS_DIR" \
  MINT_PRODUCTION_HANDOFFS_INDEX_FILE="$PRODUCTION_HANDOFFS_INDEX" \
  "$PRODUCTION_HANDOFF_CREATE" "$@"
}

promote_fixture() {
  local packet_id="$1"
  run_promote "$packet_id" --approved-by MINT-OPERATOR-01 >/dev/null
  local packet_file="$PACKETS_DIR/quote_packet_${packet_id}.yaml"
  local order_id
  local order_revision_id
  local binding_id
  local quote_id
  order_id="$(yq '.order_id' "$packet_file")"
  order_revision_id="$(yq '.order_revision_id' "$packet_file")"
  binding_id="$(yq '.line_items[0].artwork_binding_ref' "$packet_file")"
  quote_id="$(yq '.quote_id' "$packet_file")"
  echo "$order_id|$order_revision_id|$binding_id|$quote_id"
}

section "Ready order creates immutable production handoff and reuses it on rerun"
IFS='|' read -r ready_order_id ready_revision_id ready_binding_id ready_quote_id <<<"$(promote_fixture handoff-ready)"
yq -i '.lifecycle_state = "approved" | .payment_state = "paid"' "$ORDERS_DIR/order_${ready_order_id}.yaml"
yq -i '.selection_state = "approved" | .asset_refs = ["minio://client-assets/Acme%20Events/30100/3.%20Production%20Files/acme-front.eps"]' \
  "$ARTWORK_BINDINGS_DIR/artwork_binding_${ready_binding_id}.yaml"

ready_output="$(run_handoff "$ready_order_id" --json)"
echo "$ready_output" | jq -e '.handoff_create_state == "created"' >/dev/null || fail "ready order must create a handoff"
echo "$ready_output" | jq -e '.handoff_state == "ready_for_staging"' >/dev/null || fail "handoff must be ready_for_staging"
echo "$ready_output" | jq -e '.target_classes == ["screen_print_press"]' >/dev/null || fail "handoff must preserve inferred target class"
handoff_id="$(echo "$ready_output" | jq -r '.production_handoff_id')"
handoff_file="$PRODUCTION_HANDOFFS_DIR/production_handoff_${handoff_id}.yaml"
[[ -f "$handoff_file" ]] || fail "handoff file must be created"
yq '.line_items[0].production_asset_refs[0]' "$handoff_file" | grep -q 'acme-front.eps' || fail "handoff file must preserve production asset ref"
yq '.source_quote_packet_id' "$handoff_file" | grep -q 'handoff-ready' || fail "handoff file must preserve source quote packet id"
yq '.quote_id' "$handoff_file" | grep -q "$ready_quote_id" || fail "handoff file must preserve canonical quote id"
yq '.production_handoffs[0].production_handoff_id' "$PRODUCTION_HANDOFFS_INDEX" | grep -q "$handoff_id" || fail "handoff index must include created handoff"

ready_again="$(run_handoff "$ready_order_id" --json)"
echo "$ready_again" | jq -e '.handoff_create_state == "existing"' >/dev/null || fail "rerun must reuse existing handoff"
echo "$ready_again" | jq -e --arg handoff_id "$handoff_id" '.production_handoff_id == $handoff_id' >/dev/null || fail "rerun must return the same handoff id"
pass "production handoff creation is immutable and idempotent"

section "Blocked order stops instead of inventing production handoff truth"
IFS='|' read -r blocked_order_id blocked_revision_id blocked_binding_id blocked_quote_id <<<"$(promote_fixture handoff-blocked)"
before_count="$(find "$PRODUCTION_HANDOFFS_DIR" -maxdepth 1 -type f -name 'production_handoff_*' | wc -l | tr -d ' ')"
set +e
run_handoff "$blocked_order_id" >"$TMP_ROOT/blocked.out" 2>"$TMP_ROOT/blocked.err"
blocked_status=$?
set -e
[[ $blocked_status -eq 2 ]] || fail "blocked order must stop with exit 2"
grep -q "production readiness is blocked" "$TMP_ROOT/blocked.err" || fail "blocked order must explain readiness blocker"
after_count="$(find "$PRODUCTION_HANDOFFS_DIR" -maxdepth 1 -type f -name 'production_handoff_*' | wc -l | tr -d ' ')"
[[ "$before_count" == "$after_count" ]] || fail "blocked order must not create new handoff files"
pass "production handoff create blocks honestly when order truth is not ready"

section "Summary"
echo "Production handoff creation checks passed"
