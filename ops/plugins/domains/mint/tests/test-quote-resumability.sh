#!/usr/bin/env bash
# test-quote-resumability.sh - Verify quote_packet normalization stays resumable across reruns

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PREPARE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-prepare"
TMP_ROOT="$(mktemp -d)"
PACKETS_DIR="$TMP_ROOT/quote-packets"
INDEX_FILE="$TMP_ROOT/quote-packets-index.yaml"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

mkdir -p "$PACKETS_DIR"

run_prepare() {
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  MINT_QUOTE_PACKET_CAPABILITY_NAME="mint.quote.packet.normalize" \
  "$QUOTE_PREPARE" "$@"
}

section "Test 1: Resolved customer removes stale customer gaps"
TEST_PACKET_ID="test-$(uuidgen | tr '[:upper:]' '[:lower:]')"
TEST_PACKET_FILE="$PACKETS_DIR/quote_packet_${TEST_PACKET_ID}.yaml"

cat > "$TEST_PACKET_FILE" <<EOF
quote_packet_id: $TEST_PACKET_ID
state: needs_input
customer_ref:
  identity_state: resolved
  customer_id: CUST-TEST-123
  customer_query: Test Customer ABC
source_refs: []
line_items:
  - line_item_id: li-1
    product_type: t-shirt
created_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
updated_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
created_by: test-quote-resumability
open_gaps:
  - gap_id: 1
    gap_type: customer_new
    description: stale pre-normalization customer gap
    severity: blocking
    discovered_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
    resolution_path: stale
receipts: []
EOF

run_prepare --packet-id "$TEST_PACKET_ID" --skip-customer-resolve --skip-stock-check --skip-pricing > /dev/null
CUSTOMER_GAP_COUNT="$(yq '.open_gaps | map(select(.gap_type == "customer_unresolved")) | length' "$TEST_PACKET_FILE")"
[[ "$CUSTOMER_GAP_COUNT" == "0" ]] || fail "Resolved customer should not retain customer_unresolved"
STALE_GAP_COUNT="$(yq '.open_gaps | map(select(.gap_type == "customer_new")) | length' "$TEST_PACKET_FILE")"
[[ "$STALE_GAP_COUNT" == "0" ]] || fail "Stale customer_new gap should be removed on rewrite"
pass "Resolved customer rewrites packet without stale customer gaps"

section "Test 2: Repeated runs do not duplicate canonical customer gaps"
TEST_PACKET_ID2="test-$(uuidgen | tr '[:upper:]' '[:lower:]')"
TEST_PACKET_FILE2="$PACKETS_DIR/quote_packet_${TEST_PACKET_ID2}.yaml"

cat > "$TEST_PACKET_FILE2" <<EOF
quote_packet_id: $TEST_PACKET_ID2
state: needs_input
customer_ref:
  identity_state: provisional
  customer_query: Test Customer XYZ
source_refs: []
line_items:
  - line_item_id: li-2
    product_type: hoodie
created_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
updated_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
created_by: test-quote-resumability
open_gaps:
  - gap_id: 1
    gap_type: customer_new
    description: stale pre-normalization customer gap
    severity: blocking
    discovered_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
    resolution_path: stale
receipts: []
EOF

for _ in 1 2 3; do
  run_prepare --packet-id "$TEST_PACKET_ID2" --skip-customer-resolve --skip-stock-check --skip-pricing > /dev/null
done

CUSTOMER_UNRESOLVED_COUNT="$(yq '.open_gaps | map(select(.gap_type == "customer_unresolved")) | length' "$TEST_PACKET_FILE2")"
[[ "$CUSTOMER_UNRESOLVED_COUNT" == "1" ]] || fail "Expected exactly one customer_unresolved gap after repeated runs"
STALE_GAP_COUNT2="$(yq '.open_gaps | map(select(.gap_type == "customer_new")) | length' "$TEST_PACKET_FILE2")"
[[ "$STALE_GAP_COUNT2" == "0" ]] || fail "Stale customer_new gap should not survive repeated runs"
pass "Repeated normalization runs keep one canonical customer gap"

section "Test 3: Stale ambiguous gap rewrites to current canonical state"
TEST_PACKET_ID3="test-$(uuidgen | tr '[:upper:]' '[:lower:]')"
TEST_PACKET_FILE3="$PACKETS_DIR/quote_packet_${TEST_PACKET_ID3}.yaml"

cat > "$TEST_PACKET_FILE3" <<EOF
quote_packet_id: $TEST_PACKET_ID3
state: needs_input
customer_ref:
  identity_state: provisional
  customer_query: Test Customer 123
source_refs: []
line_items:
  - line_item_id: li-3
    product_type: tote-bag
created_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
updated_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
created_by: test-quote-resumability
open_gaps:
  - gap_id: 1
    gap_type: customer_ambiguous
    description: stale ambiguous gap
    severity: blocking
    discovered_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
    resolution_path: stale
receipts: []
EOF

run_prepare --packet-id "$TEST_PACKET_ID3" --skip-customer-resolve --skip-stock-check --skip-pricing > /dev/null
AMBIGUOUS_COUNT="$(yq '.open_gaps | map(select(.gap_type == "customer_ambiguous")) | length' "$TEST_PACKET_FILE3")"
[[ "$AMBIGUOUS_COUNT" == "0" ]] || fail "customer_ambiguous should be rewritten away"
CUSTOMER_UNRESOLVED_COUNT3="$(yq '.open_gaps | map(select(.gap_type == "customer_unresolved")) | length' "$TEST_PACKET_FILE3")"
[[ "$CUSTOMER_UNRESOLVED_COUNT3" == "1" ]] || fail "Current canonical state should emit one customer_unresolved gap"
pass "Stale ambiguous gap rewrites to current canonical customer state"

section "Summary"
echo "Quote packet resumability checks passed"
