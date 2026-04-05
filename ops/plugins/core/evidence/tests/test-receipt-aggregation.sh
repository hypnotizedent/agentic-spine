#!/usr/bin/env bash
# Test: receipt aggregation completion determination
# Validates mechanical completion verdict derivation from receipts + linkage

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../" && pwd)"
cd "$ROOT"

source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init

AGGREGATION_BIN="$ROOT/ops/plugins/core/evidence/bin/receipt-aggregation-status"
TEST_STATE_DIR="$SPINE_STATE/test-receipt-aggregation-$$"
TEST_LINKAGE_DIR="$TEST_STATE_DIR/dispatch/linkage"
TEST_COMPLETION_DIR="$TEST_STATE_DIR/dispatch/completion"
TEST_RECEIPT_INDEX="$TEST_STATE_DIR/receipt-index.yaml"

echo "TEST: receipt aggregation completion determination"

# Setup test environment
mkdir -p "$TEST_LINKAGE_DIR" "$TEST_COMPLETION_DIR"

cleanup() {
    rm -rf "$TEST_STATE_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: Create test receipt index with parent and child receipts
echo "  - creating test receipt index..."
cat > "$TEST_RECEIPT_INDEX" <<'EOF'
version: 1.0
updated_at_utc: "2026-04-05T19:00:00Z"
entries:
  - run_id: "CAP-20260405-190000__parent.capability__Rtest001"
    capability: "parent.capability"
    status: "done"
    domain: "core"
    plane: "execution"
    generated_at_utc: "2026-04-05T19:00:00Z"
    receipt_path: "/fake/path/parent.receipt.md"
    output_path: "/fake/path/parent.output.txt"
    indexed_at_utc: "2026-04-05T19:01:00Z"

  - run_id: "CAP-20260405-190100__child1.capability__Rtest002"
    capability: "child1.capability"
    status: "done"
    domain: "core"
    plane: "execution"
    generated_at_utc: "2026-04-05T19:01:00Z"
    receipt_path: "/fake/path/child1.receipt.md"
    output_path: "/fake/path/child1.output.txt"
    indexed_at_utc: "2026-04-05T19:02:00Z"

  - run_id: "CAP-20260405-190200__child2.capability__Rtest003"
    capability: "child2.capability"
    status: "done"
    domain: "core"
    plane: "execution"
    generated_at_utc: "2026-04-05T19:02:00Z"
    receipt_path: "/fake/path/child2.receipt.md"
    output_path: "/fake/path/child2.output.txt"
    indexed_at_utc: "2026-04-05T19:03:00Z"
EOF
echo "    PASS: test receipt index created"

# Test 2: Create linkage artifact for parent with all children complete
echo "  - creating linkage artifact (all children complete)..."
cat > "$TEST_LINKAGE_DIR/CAP-20260405-190000__parent.capability__Rtest001.linkage.yaml" <<'EOF'
parent_run_key: "CAP-20260405-190000__parent.capability__Rtest001"
child_envelope_ids:
  - "ENV-20260405-190100-child1"
  - "ENV-20260405-190200-child2"
child_run_keys_expected:
  - "CAP-20260405-190100__child1.capability__Rtest002"
  - "CAP-20260405-190200__child2.capability__Rtest003"
child_run_keys_actual: []
child_run_keys_missing: []
completion_status: "unknown"
linkage_updated_at_utc: "2026-04-05T19:00:00Z"
timeout_utc: "2026-04-06T19:00:00Z"
EOF

# Test 3: Query completion status (should be complete)
echo "  - querying completion status (all children present)..."
output=$("$AGGREGATION_BIN" \
    --receipt-index "$TEST_RECEIPT_INDEX" \
    --linkage-dir "$TEST_LINKAGE_DIR" \
    --completion-dir "$TEST_COMPLETION_DIR" \
    --parent-run-key "CAP-20260405-190000__parent.capability__Rtest001" 2>&1 || true)

# Check for expected output
if ! echo "$output" | grep -q "completion_status: complete"; then
    echo "FAIL: expected 'complete' status"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "child_run_keys_expected: 2"; then
    echo "FAIL: expected 2 child run keys"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "child_run_keys_actual: 2"; then
    echo "FAIL: expected 2 actual child run keys"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "child_run_keys_missing: 0"; then
    echo "FAIL: expected 0 missing child run keys"
    echo "Output: $output"
    exit 1
fi

echo "    PASS: completion status is 'complete'"

# Test 4: Create linkage with missing child
echo "  - creating linkage artifact (one child missing)..."
cat > "$TEST_LINKAGE_DIR/CAP-20260405-190000__parent.missing__Rtest004.linkage.yaml" <<'EOF'
parent_run_key: "CAP-20260405-190000__parent.missing__Rtest004"
child_envelope_ids:
  - "ENV-20260405-190100-child1"
  - "ENV-20260405-190200-childMISSING"
child_run_keys_expected:
  - "CAP-20260405-190100__child1.capability__Rtest002"
  - "CAP-20260405-190200__childMISSING__Rtest999"
timeout_utc: "2026-04-06T19:00:00Z"
EOF

# Test 5: Query completion status (should be awaiting)
echo "  - querying completion status (one child missing, no timeout)..."
output=$("$AGGREGATION_BIN" \
    --receipt-index "$TEST_RECEIPT_INDEX" \
    --linkage-dir "$TEST_LINKAGE_DIR" \
    --completion-dir "$TEST_COMPLETION_DIR" \
    --parent-run-key "CAP-20260405-190000__parent.missing__Rtest004" 2>&1 || true)

if ! echo "$output" | grep -q "completion_status: awaiting_delegated_receipt"; then
    echo "FAIL: expected 'awaiting_delegated_receipt' status"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "child_run_keys_missing: 1"; then
    echo "FAIL: expected 1 missing child run key"
    echo "Output: $output"
    exit 1
fi

echo "    PASS: completion status is 'awaiting_delegated_receipt'"

# Test 6: Create linkage with timeout exceeded
echo "  - creating linkage artifact (timeout exceeded)..."
cat > "$TEST_LINKAGE_DIR/CAP-20260405-190000__parent.timeout__Rtest005.linkage.yaml" <<'EOF'
parent_run_key: "CAP-20260405-190000__parent.timeout__Rtest005"
child_envelope_ids:
  - "ENV-20260405-190100-childTIMEOUT"
child_run_keys_expected:
  - "CAP-20260405-190100__childTIMEOUT__Rtest998"
timeout_utc: "2026-04-04T19:00:00Z"
EOF

# Test 7: Query completion status (should be timeout)
echo "  - querying completion status (timeout exceeded)..."
output=$("$AGGREGATION_BIN" \
    --receipt-index "$TEST_RECEIPT_INDEX" \
    --linkage-dir "$TEST_LINKAGE_DIR" \
    --completion-dir "$TEST_COMPLETION_DIR" \
    --parent-run-key "CAP-20260405-190000__parent.timeout__Rtest005" 2>&1 || true)

if ! echo "$output" | grep -q "completion_status: timeout_delegated"; then
    echo "FAIL: expected 'timeout_delegated' status"
    echo "Output: $output"
    exit 1
fi

echo "    PASS: completion status is 'timeout_delegated'"

# Test 8: List all delegated work
echo "  - listing all delegated work..."
output=$("$AGGREGATION_BIN" \
    --receipt-index "$TEST_RECEIPT_INDEX" \
    --linkage-dir "$TEST_LINKAGE_DIR" \
    --completion-dir "$TEST_COMPLETION_DIR" \
    --list-delegated 2>&1 || true)

if ! echo "$output" | grep -q "Delegated work items: 3"; then
    echo "FAIL: expected 3 delegated work items"
    echo "Output: $output"
    exit 1
fi

echo "    PASS: list-delegated shows 3 items"

# Test 9: Verify completion artifacts were created
echo "  - verifying completion artifacts created..."
if [[ ! -f "$TEST_COMPLETION_DIR/CAP-20260405-190000__parent.capability__Rtest001.completion.yaml" ]]; then
    echo "FAIL: completion artifact not created for parent.capability"
    exit 1
fi

if [[ ! -f "$TEST_COMPLETION_DIR/CAP-20260405-190000__parent.missing__Rtest004.completion.yaml" ]]; then
    echo "FAIL: completion artifact not created for parent.missing"
    exit 1
fi

echo "    PASS: completion artifacts created"

# Test 10: Verify completion artifact content
echo "  - verifying completion artifact content..."
completion_data=$(cat "$TEST_COMPLETION_DIR/CAP-20260405-190000__parent.capability__Rtest001.completion.yaml")

if ! echo "$completion_data" | grep -q "completion_status: complete"; then
    echo "FAIL: completion artifact does not show 'complete' status"
    exit 1
fi

if ! echo "$completion_data" | grep -q "child_run_keys_expected_count: 2"; then
    echo "FAIL: completion artifact does not show expected count 2"
    exit 1
fi

echo "    PASS: completion artifact content valid"

echo "PASS: receipt aggregation completion determination"
