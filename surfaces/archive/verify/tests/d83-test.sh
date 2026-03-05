#!/usr/bin/env bash
# Tests for D83: proposal queue health lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d83-proposal-queue-health-lock.sh"
PROPOSALS_DIR="$SP/mailroom/outbox/proposals"
PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

# Test 1: Gate passes on current repo state
echo "--- Test 1: live state PASS ---"
if bash "$GATE" >/dev/null 2>&1; then
  pass "D83 passes on current repo state"
else
  fail "D83 should pass on current repo state"
fi

# Test 2: Missing manifest detection (negative test)
echo "--- Test 2: missing manifest detection ---"
TEST_CP="$PROPOSALS_DIR/CP-20260213-999999__d83-test-missing-manifest"
trap 'rm -rf "$TEST_CP"' EXIT
mkdir -p "$TEST_CP"

output=$(bash "$GATE" 2>&1) && rc=$? || rc=$?
rm -rf "$TEST_CP"

if [[ "$rc" -ne 0 ]]; then
  pass "D83 correctly detects missing manifest (rc=$rc)"
else
  fail "D83 should fail for missing manifest (rc=$rc)"
fi

# Test 3: Missing agent field detection (negative test)
echo "--- Test 3: missing required fields ---"
TEST_CP2="$PROPOSALS_DIR/CP-20260213-999998__d83-test-missing-fields"
trap 'rm -rf "$TEST_CP2"' EXIT
mkdir -p "$TEST_CP2"
cat > "$TEST_CP2/manifest.yaml" << 'YAML'
proposal: CP-20260213-999998__d83-test-missing-fields
created: 2026-02-13T00:00:00Z
changes: []
YAML

output=$(bash "$GATE" 2>&1) && rc=$? || rc=$?
rm -rf "$TEST_CP2"

if [[ "$rc" -ne 0 ]]; then
  pass "D83 correctly detects missing agent field (rc=$rc)"
else
  fail "D83 should fail for missing agent field (rc=$rc)"
fi

# Test 4: draft_hold without owner/review_date detection
echo "--- Test 4: draft_hold without owner ---"
TEST_CP3="$PROPOSALS_DIR/CP-20260213-999997__d83-test-bad-draft-hold"
trap 'rm -rf "$TEST_CP3"' EXIT
mkdir -p "$TEST_CP3"
cat > "$TEST_CP3/manifest.yaml" << 'YAML'
proposal: CP-20260213-999997__d83-test-bad-draft-hold
agent: "test"
created: 2026-02-13T00:00:00Z
status: draft_hold
changes: []
YAML

output=$(bash "$GATE" 2>&1) && rc=$? || rc=$?
rm -rf "$TEST_CP3"

if [[ "$rc" -ne 0 ]]; then
  pass "D83 correctly detects draft_hold without owner (rc=$rc)"
else
  fail "D83 should fail for draft_hold without owner (rc=$rc)"
fi

# Test 5: Missing created field fails (not just warns)
echo "--- Test 5: missing created field ---"
TEST_CP5="$PROPOSALS_DIR/CP-20260213-999995__d83-test-no-created"
trap 'rm -rf "$TEST_CP5"' EXIT
mkdir -p "$TEST_CP5"
cat > "$TEST_CP5/manifest.yaml" << 'YAML'
proposal: CP-20260213-999995__d83-test-no-created
agent: "test-agent"
changes: []
YAML

output=$(bash "$GATE" 2>&1) && rc=$? || rc=$?
rm -rf "$TEST_CP5"

if [[ "$rc" -ne 0 ]]; then
  pass "D83 correctly fails on missing created field (rc=$rc)"
else
  fail "D83 should fail for missing created field (rc=$rc)"
fi

# Test 6: Superseded without superseded_at fails
echo "--- Test 6: superseded without superseded_at ---"
TEST_CP6="$PROPOSALS_DIR/CP-20260213-999994__d83-test-bad-superseded"
trap 'rm -rf "$TEST_CP6"' EXIT
mkdir -p "$TEST_CP6"
cat > "$TEST_CP6/manifest.yaml" << 'YAML'
proposal: CP-20260213-999994__d83-test-bad-superseded
agent: "test-agent"
created: "2026-02-13T00:00:00Z"
status: superseded
superseded_reason: "test only reason, no at field"
changes: []
YAML

output=$(bash "$GATE" 2>&1) && rc=$? || rc=$?
rm -rf "$TEST_CP6"

if [[ "$rc" -ne 0 ]]; then
  pass "D83 correctly fails on superseded without superseded_at (rc=$rc)"
else
  fail "D83 should fail for superseded without superseded_at (rc=$rc)"
fi

# Test 7: Superseded without superseded_reason fails
echo "--- Test 7: superseded without superseded_reason ---"
TEST_CP7="$PROPOSALS_DIR/CP-20260213-999993__d83-test-bad-superseded-2"
trap 'rm -rf "$TEST_CP7"' EXIT
mkdir -p "$TEST_CP7"
cat > "$TEST_CP7/manifest.yaml" << 'YAML'
proposal: CP-20260213-999993__d83-test-bad-superseded-2
agent: "test-agent"
created: "2026-02-13T00:00:00Z"
status: superseded
superseded_at: "2026-02-13T00:00:00Z"
changes: []
YAML

output=$(bash "$GATE" 2>&1) && rc=$? || rc=$?
rm -rf "$TEST_CP7"

if [[ "$rc" -ne 0 ]]; then
  pass "D83 correctly fails on superseded without superseded_reason (rc=$rc)"
else
  fail "D83 should fail for superseded without superseded_reason (rc=$rc)"
fi

# Test 8: Well-formed proposals pass
echo "--- Test 8: well-formed proposal passes ---"
TEST_CP8="$PROPOSALS_DIR/CP-20260213-999996__d83-test-good"
trap 'rm -rf "$TEST_CP8"' EXIT
mkdir -p "$TEST_CP8"
cat > "$TEST_CP8/manifest.yaml" << 'YAML'
proposal: CP-20260213-999996__d83-test-good
agent: "test-agent"
created: 2026-02-13T00:00:00Z
changes: []
YAML

output=$(bash "$GATE" 2>&1) && rc=$? || rc=$?
rm -rf "$TEST_CP8"

if [[ "$rc" -eq 0 ]]; then
  pass "D83 passes for well-formed proposal (rc=$rc)"
else
  fail "D83 should pass for well-formed proposal (rc=$rc)"
fi

# Test 9: read_only proposal without status field detected correctly
echo "--- Test 9: read_only proposal detection ---"
TEST_CP9="$PROPOSALS_DIR/CP-20260213-999992__d83-test-read-only"
trap 'rm -rf "$TEST_CP9"' EXIT
mkdir -p "$TEST_CP9"
cat > "$TEST_CP9/manifest.yaml" << 'YAML'
proposal: CP-20260213-999992__d83-test-read-only
agent: "test-agent"
created: 2026-02-13T00:00:00Z
read_only: true
mode: read-only
changes: []
YAML

output=$(bash "$GATE" 2>&1) && rc=$? || rc=$?
rm -rf "$TEST_CP9"

if [[ "$rc" -eq 0 ]]; then
  pass "D83 passes for read_only proposal without status field (rc=$rc)"
else
  fail "D83 should pass for read_only proposal (rc=$rc, output: $output)"
fi

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
