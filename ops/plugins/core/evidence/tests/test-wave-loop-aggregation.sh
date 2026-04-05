#!/usr/bin/env bash
# Test: wave and loop aggregation mechanical completion determination
# Validates wave/loop verdict derivation from orchestration packet + lane outcomes

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../" && pwd)"
cd "$ROOT"

source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init

AGGREGATION_BIN="$ROOT/ops/plugins/core/evidence/bin/receipt-aggregation-status"
TEST_STATE_DIR="$SPINE_STATE/test-wave-loop-aggregation-$$"
TEST_AGGREGATION_DIR="$TEST_STATE_DIR/dispatch/aggregation"
TEST_ORCHESTRATION_DIR="$TEST_STATE_DIR/orchestration"

echo "TEST: wave and loop aggregation mechanical completion determination"

# Setup test environment
mkdir -p "$TEST_AGGREGATION_DIR" "$TEST_ORCHESTRATION_DIR"

cleanup() {
    rm -rf "$TEST_STATE_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: Create orchestration packet with all lanes complete
echo "  - creating orchestration packet (all lanes complete)..."
mkdir -p "$TEST_ORCHESTRATION_DIR/LOOP-TEST-ALL-COMPLETE"
cat > "$TEST_ORCHESTRATION_DIR/LOOP-TEST-ALL-COMPLETE/packet.yaml" <<'EOF'
loop_id: "LOOP-TEST-ALL-COMPLETE"
execution_mode: orchestrator_subagents
owner_terminal: "test-terminal"
created_at_utc: "2026-04-05T20:00:00Z"

wave_plan:
  - wave_id: "W1-CONTROL"
    objective: "Control lane work"
    subagents: ["agent-1"]
    depends_on: []
  - wave_id: "W2-EXECUTION"
    objective: "Execution lane work"
    subagents: ["agent-2"]
    depends_on: ["W1-CONTROL"]

lane_outcomes:
  - lane_id: "CONTROL"
    owner_terminal: "terminal-1"
    lane_status: "closed"
    updated_at_utc: "2026-04-05T20:10:00Z"
  - lane_id: "EXECUTION"
    owner_terminal: "terminal-2"
    lane_status: "closed"
    updated_at_utc: "2026-04-05T20:20:00Z"

plan_transition:
  status: completed
  updated_at_utc: "2026-04-05T20:30:00Z"

deadline_utc: "2026-04-06T20:00:00Z"
EOF

# Test 2: Query wave aggregation (all lanes complete)
echo "  - querying wave aggregation (all lanes complete)..."
output=$("$AGGREGATION_BIN" \
    --wave-id "W1-CONTROL" \
    --loop-id "LOOP-TEST-ALL-COMPLETE" \
    --state-dir "$TEST_STATE_DIR" \
    --aggregation-dir "$TEST_AGGREGATION_DIR" 2>&1 || true)

if ! echo "$output" | grep -q "aggregation_status: complete"; then
    echo "FAIL: expected wave 'complete' status"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "total_lanes: 2"; then
    echo "FAIL: expected 2 total lanes"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "lanes_complete: 2"; then
    echo "FAIL: expected 2 lanes complete"
    echo "Output: $output"
    exit 1
fi

echo "    PASS: wave aggregation status is 'complete'"

# Test 3: Query loop aggregation (all waves complete)
echo "  - querying loop aggregation (all waves complete)..."
output=$("$AGGREGATION_BIN" \
    --loop-id "LOOP-TEST-ALL-COMPLETE" \
    --state-dir "$TEST_STATE_DIR" \
    --aggregation-dir "$TEST_AGGREGATION_DIR" 2>&1 || true)

if ! echo "$output" | grep -q "loop_aggregation_status: complete"; then
    echo "FAIL: expected loop 'complete' status"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "total_waves: 2"; then
    echo "FAIL: expected 2 total waves"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "waves_complete: 2"; then
    echo "FAIL: expected 2 waves complete"
    echo "Output: $output"
    exit 1
fi

echo "    PASS: loop aggregation status is 'complete'"

# Test 4: Create packet with one lane blocked
echo "  - creating orchestration packet (one lane blocked)..."
mkdir -p "$TEST_ORCHESTRATION_DIR/LOOP-TEST-ONE-BLOCKED"
cat > "$TEST_ORCHESTRATION_DIR/LOOP-TEST-ONE-BLOCKED/packet.yaml" <<'EOF'
loop_id: "LOOP-TEST-ONE-BLOCKED"
execution_mode: orchestrator_subagents
owner_terminal: "test-terminal"
created_at_utc: "2026-04-05T20:00:00Z"

wave_plan:
  - wave_id: "W1-CONTROL"
    objective: "Control lane work"
    subagents: ["agent-1"]
    depends_on: []

lane_outcomes:
  - lane_id: "CONTROL"
    owner_terminal: "terminal-1"
    lane_status: "closed"
    updated_at_utc: "2026-04-05T20:10:00Z"
  - lane_id: "EXECUTION"
    owner_terminal: "terminal-2"
    lane_status: "blocked"
    updated_at_utc: "2026-04-05T20:20:00Z"

deadline_utc: "2026-04-06T20:00:00Z"
EOF

# Test 5: Query wave aggregation (one lane blocked)
echo "  - querying wave aggregation (one lane blocked)..."
output=$("$AGGREGATION_BIN" \
    --wave-id "W1-CONTROL" \
    --loop-id "LOOP-TEST-ONE-BLOCKED" \
    --state-dir "$TEST_STATE_DIR" \
    --aggregation-dir "$TEST_AGGREGATION_DIR" 2>&1 || true)

if ! echo "$output" | grep -q "aggregation_status: blocked"; then
    echo "FAIL: expected wave 'blocked' status"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "lanes_blocked: 1"; then
    echo "FAIL: expected 1 lane blocked"
    echo "Output: $output"
    exit 1
fi

echo "    PASS: wave aggregation status is 'blocked'"

# Test 6: Query loop aggregation (one wave blocked)
echo "  - querying loop aggregation (one wave blocked)..."
output=$("$AGGREGATION_BIN" \
    --loop-id "LOOP-TEST-ONE-BLOCKED" \
    --state-dir "$TEST_STATE_DIR" \
    --aggregation-dir "$TEST_AGGREGATION_DIR" 2>&1 || true)

if ! echo "$output" | grep -q "loop_aggregation_status: blocked"; then
    echo "FAIL: expected loop 'blocked' status"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "waves_blocked: 1"; then
    echo "FAIL: expected 1 wave blocked"
    echo "Output: $output"
    exit 1
fi

echo "    PASS: loop aggregation status is 'blocked'"

# Test 7: Create packet with incomplete lanes
echo "  - creating orchestration packet (lanes in progress)..."
mkdir -p "$TEST_ORCHESTRATION_DIR/LOOP-TEST-IN-PROGRESS"
cat > "$TEST_ORCHESTRATION_DIR/LOOP-TEST-IN-PROGRESS/packet.yaml" <<'EOF'
loop_id: "LOOP-TEST-IN-PROGRESS"
execution_mode: orchestrator_subagents
owner_terminal: "test-terminal"
created_at_utc: "2026-04-05T20:00:00Z"

wave_plan:
  - wave_id: "W1-CONTROL"
    objective: "Control lane work"
    subagents: ["agent-1"]
    depends_on: []

lane_outcomes:
  - lane_id: "CONTROL"
    owner_terminal: "terminal-1"
    lane_status: "dispatched"
    updated_at_utc: "2026-04-05T20:10:00Z"
  - lane_id: "EXECUTION"
    owner_terminal: "terminal-2"
    lane_status: "open"
    updated_at_utc: "2026-04-05T20:20:00Z"

deadline_utc: "2026-04-06T20:00:00Z"
EOF

# Test 8: Query wave aggregation (incomplete)
echo "  - querying wave aggregation (lanes in progress)..."
output=$("$AGGREGATION_BIN" \
    --wave-id "W1-CONTROL" \
    --loop-id "LOOP-TEST-IN-PROGRESS" \
    --state-dir "$TEST_STATE_DIR" \
    --aggregation-dir "$TEST_AGGREGATION_DIR" 2>&1 || true)

if ! echo "$output" | grep -q "aggregation_status: incomplete"; then
    echo "FAIL: expected wave 'incomplete' status"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "lanes_incomplete: 2"; then
    echo "FAIL: expected 2 lanes incomplete"
    echo "Output: $output"
    exit 1
fi

echo "    PASS: wave aggregation status is 'incomplete'"

# Test 9: Query loop aggregation (in progress)
echo "  - querying loop aggregation (in progress)..."
output=$("$AGGREGATION_BIN" \
    --loop-id "LOOP-TEST-IN-PROGRESS" \
    --state-dir "$TEST_STATE_DIR" \
    --aggregation-dir "$TEST_AGGREGATION_DIR" 2>&1 || true)

if ! echo "$output" | grep -q "loop_aggregation_status: in_progress"; then
    echo "FAIL: expected loop 'in_progress' status"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "waves_incomplete: 1"; then
    echo "FAIL: expected 1 wave incomplete"
    echo "Output: $output"
    exit 1
fi

echo "    PASS: loop aggregation status is 'in_progress'"

# Test 10: Verify aggregation artifacts created
echo "  - verifying aggregation artifacts created..."
if [[ ! -f "$TEST_AGGREGATION_DIR/W1-CONTROL.aggregation.yaml" ]]; then
    echo "FAIL: wave aggregation artifact not created"
    exit 1
fi

if [[ ! -f "$TEST_AGGREGATION_DIR/LOOP-TEST-ALL-COMPLETE.aggregation.yaml" ]]; then
    echo "FAIL: loop aggregation artifact not created"
    exit 1
fi

echo "    PASS: aggregation artifacts created"

# Test 11: Verify wave artifact content
echo "  - verifying wave aggregation artifact content..."
wave_data=$(cat "$TEST_AGGREGATION_DIR/W1-CONTROL.aggregation.yaml")

if ! echo "$wave_data" | grep -q "aggregation_type: wave"; then
    echo "FAIL: wave artifact missing aggregation_type"
    exit 1
fi

if ! echo "$wave_data" | grep -q "wave_id: W1-CONTROL"; then
    echo "FAIL: wave artifact missing wave_id"
    exit 1
fi

echo "    PASS: wave aggregation artifact content valid"

# Test 12: Verify loop artifact content
echo "  - verifying loop aggregation artifact content..."
loop_data=$(cat "$TEST_AGGREGATION_DIR/LOOP-TEST-ALL-COMPLETE.aggregation.yaml")

if ! echo "$loop_data" | grep -q "aggregation_type: loop"; then
    echo "FAIL: loop artifact missing aggregation_type"
    exit 1
fi

if ! echo "$loop_data" | grep -q "loop_id: LOOP-TEST-ALL-COMPLETE"; then
    echo "FAIL: loop artifact missing loop_id"
    exit 1
fi

if ! echo "$loop_data" | grep -q "loop_aggregation_status: complete"; then
    echo "FAIL: loop artifact does not show 'complete' status"
    exit 1
fi

echo "    PASS: loop aggregation artifact content valid"

echo "PASS: wave and loop aggregation mechanical completion determination"
