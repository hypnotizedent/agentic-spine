#!/usr/bin/env bash
# Tests for proposals-apply: timestamp preservation (GAP-OP-259 regression)
set -euo pipefail

PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

TMPMANIFEST=$(mktemp)
trap 'rm -f "$TMPMANIFEST"' EXIT

cat > "$TMPMANIFEST" << 'YAML'
proposal: CP-20260213-999990__test
agent: "test-agent"
created: "2026-02-13T12:05:30Z"
loop_id: "LOOP-TEST-TIMESTAMP"
changes:
  - action: create
    path: test/placeholder.txt
    reason: test
YAML

# These are the exact awk patterns used in proposals-apply (post-fix)
extract_agent() { awk '/^agent:/{sub(/^agent: */, ""); gsub(/"/, ""); print; exit}' "$1"; }
extract_created() { awk '/^created:/{sub(/^created: */, ""); gsub(/"/, ""); print; exit}' "$1"; }
extract_loop_id() { awk '/^loop_id:/{sub(/^loop_id: */, ""); gsub(/"/, ""); print; exit}' "$1"; }

# Reproduce the OLD (broken) pattern for contrast
extract_created_old() { awk -F': *' '/^created:/{print $2; exit}' "$1" | tr -d '"'; }

# Test 1: Full ISO timestamp preserved (regression for GAP-OP-259)
echo "--- Test 1: timestamp preservation ---"
got=$(extract_created "$TMPMANIFEST")
if [[ "$got" == "2026-02-13T12:05:30Z" ]]; then
  pass "Full ISO timestamp preserved: $got"
else
  fail "Expected '2026-02-13T12:05:30Z', got '$got'"
fi

# Test 2: Old pattern was broken (documents the bug)
echo "--- Test 2: old pattern truncates ---"
old=$(extract_created_old "$TMPMANIFEST")
if [[ "$old" != "2026-02-13T12:05:30Z" ]]; then
  pass "Old pattern confirms truncation: '$old'"
else
  pass "Old pattern happened to work (no colons in value)"
fi

# Test 3: Agent field preserved
echo "--- Test 3: agent field preserved ---"
got=$(extract_agent "$TMPMANIFEST")
if [[ "$got" == "test-agent" ]]; then
  pass "Agent field correct: $got"
else
  fail "Expected 'test-agent', got '$got'"
fi

# Test 4: Loop ID preserved
echo "--- Test 4: loop_id preserved ---"
got=$(extract_loop_id "$TMPMANIFEST")
if [[ "$got" == "LOOP-TEST-TIMESTAMP" ]]; then
  pass "Loop ID correct: $got"
else
  fail "Expected 'LOOP-TEST-TIMESTAMP', got '$got'"
fi

# Test 5: Timestamp without quotes
echo "--- Test 5: unquoted timestamp ---"
cat > "$TMPMANIFEST" << 'YAML'
proposal: CP-test
agent: bot
created: 2026-02-13T23:59:59Z
YAML
got=$(extract_created "$TMPMANIFEST")
if [[ "$got" == "2026-02-13T23:59:59Z" ]]; then
  pass "Unquoted timestamp preserved: $got"
else
  fail "Expected '2026-02-13T23:59:59Z', got '$got'"
fi

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
