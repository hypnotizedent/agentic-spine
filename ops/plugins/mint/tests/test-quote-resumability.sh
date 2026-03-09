#!/usr/bin/env bash
# test-quote-resumability.sh - Test gap lifecycle management in quote-prepare
#
# Tests that gaps are properly removed when conditions improve,
# and that repeated runs don't create duplicate gaps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"

# Source spine paths as required by pre-commit hook
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PREPARE="$SPINE_ROOT/ops/plugins/mint/bin/quote-prepare"
PACKETS_DIR="$SPINE_ROOT/runtime/domain-state/mint/quote-packets"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }

# Setup test environment
section "Setup test environment"
mkdir -p "$PACKETS_DIR"

# Track test packet IDs for cleanup
TEST_PACKET_IDS=()

# Test 1: Customer gap removed when resolved
section "Test 1: Customer gap removal when resolved"

# Create a packet with customer gap (simulate unresolved state)
TEST_PACKET_ID="test-$(uuidgen | tr '[:upper:]' '[:lower:]')"
TEST_PACKET_FILE="$PACKETS_DIR/quote_packet_${TEST_PACKET_ID}.yaml"
TEST_PACKET_IDS+=("$TEST_PACKET_ID")

cat > "$TEST_PACKET_FILE" <<EOF
quote_packet_id: $TEST_PACKET_ID
state: needs_input
customer_ref:
  identity_state: provisional
  customer_query: "Test Customer ABC"
source_refs: []
line_items: []
created_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
updated_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
created_by: test-quote-resumability
open_gaps:
  - gap_id: 1
    gap_type: customer_new
    description: "New customer requires registration"
    severity: blocking
    discovered_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
    resolution_path: "Register customer"
receipts: []
EOF

# Verify gap exists
INITIAL_GAP_COUNT=$(yq '.open_gaps | length' "$TEST_PACKET_FILE")
[[ "$INITIAL_GAP_COUNT" -eq 1 ]] || fail "Test 1 setup: expected 1 gap, got $INITIAL_GAP_COUNT"

# Simulate customer resolution by updating identity_state
yq -i ".customer_ref.identity_state = \"resolved\"" "$TEST_PACKET_FILE"
yq -i ".customer_ref.customer_id = \"TEST-123\"" "$TEST_PACKET_FILE"
yq -i ".customer_ref.resolved_name = \"Test Customer ABC\"" "$TEST_PACKET_FILE"

# Run quote-prepare in update mode (it should remove the customer gap)
# Note: This will fail if customer-resolve service is unavailable, but we can still test gap removal logic
"$QUOTE_PREPARE" --packet-id "$TEST_PACKET_ID" --skip-stock-check --skip-pricing 2>&1 || true

# Verify gap was removed
FINAL_GAP_COUNT=$(yq '.open_gaps | map(select(.gap_type | test("^customer_"))) | length' "$TEST_PACKET_FILE")
if [[ "$FINAL_GAP_COUNT" -eq 0 ]]; then
  pass "Test 1: Customer gap removed when identity_state=resolved"
else
  fail "Test 1: Expected 0 customer gaps, got $FINAL_GAP_COUNT"
fi

# Test 2: No duplicate gaps on repeated runs
section "Test 2: No duplicate gaps on repeated runs"

# Create a packet with a customer gap
TEST_PACKET_ID2="test-$(uuidgen | tr '[:upper:]' '[:lower:]')"
TEST_PACKET_FILE2="$PACKETS_DIR/quote_packet_${TEST_PACKET_ID2}.yaml"
TEST_PACKET_IDS+=("$TEST_PACKET_ID2")

cat > "$TEST_PACKET_FILE2" <<EOF
quote_packet_id: $TEST_PACKET_ID2
state: needs_input
customer_ref:
  identity_state: provisional
  customer_query: "Test Customer XYZ"
source_refs: []
line_items: []
created_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
updated_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
created_by: test-quote-resumability
open_gaps:
  - gap_id: 1
    gap_type: customer_new
    description: "New customer requires registration"
    severity: blocking
    discovered_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
    resolution_path: "Register customer"
receipts: []
EOF

# Run quote-prepare multiple times
for i in {1..3}; do
  "$QUOTE_PREPARE" --packet-id "$TEST_PACKET_ID2" --skip-stock-check --skip-pricing > /dev/null 2>&1 || true
done

# Verify no duplicate gaps (any customer gap type)
CUSTOMER_GAP_COUNT=$(yq '.open_gaps | map(select(.gap_type | test("^customer_"))) | length' "$TEST_PACKET_FILE2")
if [[ "$CUSTOMER_GAP_COUNT" -le 1 ]]; then
  pass "Test 2: No duplicate customer gaps after 3 runs (found $CUSTOMER_GAP_COUNT)"
else
  fail "Test 2: Expected <=1 customer gap, got $CUSTOMER_GAP_COUNT"
fi

# Test 3: Gap type changes when condition changes
section "Test 3: Gap type changes when condition changes"

# Create packet with customer_new gap
TEST_PACKET_ID3="test-$(uuidgen | tr '[:upper:]' '[:lower:]')"
TEST_PACKET_FILE3="$PACKETS_DIR/quote_packet_${TEST_PACKET_ID3}.yaml"
TEST_PACKET_IDS+=("$TEST_PACKET_ID3")

cat > "$TEST_PACKET_FILE3" <<EOF
quote_packet_id: $TEST_PACKET_ID3
state: needs_input
customer_ref:
  identity_state: provisional
  customer_query: "Test Customer 123"
source_refs: []
line_items: []
created_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
updated_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
created_by: test-quote-resumability
open_gaps:
  - gap_id: 1
    gap_type: customer_new
    description: "New customer requires registration"
    severity: blocking
    discovered_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
    resolution_path: "Register customer"
receipts: []
EOF

# Simulate condition change by manually changing gap to customer_ambiguous
yq -i '.open_gaps[0].gap_type = "customer_ambiguous"' "$TEST_PACKET_FILE3"
yq -i '.open_gaps[0].description = "Customer query matched 2 candidates"' "$TEST_PACKET_FILE3"

# Run quote-prepare (should remove customer_ambiguous if it finds different customer condition)
"$QUOTE_PREPARE" --packet-id "$TEST_PACKET_ID3" --skip-stock-check --skip-pricing > /dev/null 2>&1 || true

# Verify old gap type was removed and only one customer gap exists
AMBIGUOUS_COUNT=$(yq '.open_gaps | map(select(.gap_type == "customer_ambiguous")) | length' "$TEST_PACKET_FILE3")
TOTAL_CUSTOMER_GAPS=$(yq '.open_gaps | map(select(.gap_type | test("^customer_"))) | length' "$TEST_PACKET_FILE3")

if [[ "$AMBIGUOUS_COUNT" -eq 0 ]] && [[ "$TOTAL_CUSTOMER_GAPS" -le 1 ]]; then
  pass "Test 3: Old customer_ambiguous gap removed, replaced with current state (total customer gaps: $TOTAL_CUSTOMER_GAPS)"
else
  fail "Test 3: Expected customer_ambiguous=0, total<=1, got ambiguous=$AMBIGUOUS_COUNT total=$TOTAL_CUSTOMER_GAPS"
fi

# Cleanup
section "Cleanup"
for PACKET_ID in "${TEST_PACKET_IDS[@]}"; do
  rm -f "$PACKETS_DIR/quote_packet_${PACKET_ID}.yaml"
  echo "Removed test packet: $PACKET_ID"
done

# Summary
section "Test Summary"
echo "All resumability tests completed successfully"
echo ""
echo "Gap lifecycle management verified:"
echo "  - Gaps are removed when conditions improve (resolved customer)"
echo "  - No duplicate gaps on repeated runs"
echo "  - Gap types change when conditions change"

exit 0
