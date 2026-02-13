#!/usr/bin/env bash
# Tests for D34: loop ledger integrity lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d34-loop-ledger-integrity-lock.sh"
PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

# Test 1: Gate passes on current repo state
echo "--- Test 1: live state PASS ---"
if bash "$GATE" >/dev/null 2>&1; then
  pass "D34 passes on current repo state"
else
  fail "D34 should pass on current repo state"
fi

# Test 2: Missing open_loops.jsonl does not cause errors
echo "--- Test 2: missing open_loops.jsonl tolerance ---"
JSONL_PATH="$SP/mailroom/state/open_loops.jsonl"
# Confirm file doesn't exist (it was deprecated)
if [[ ! -f "$JSONL_PATH" ]]; then
  # Run ops loops list --open and verify exit 0 + deterministic output
  output=$("$SP/bin/ops" loops list --open 2>&1) && rc=$? || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    pass "ops loops list --open succeeds without open_loops.jsonl (exit $rc)"
  else
    fail "ops loops list --open should succeed without open_loops.jsonl (exit $rc)"
  fi

  # Verify output contains an open count line
  if echo "$output" | grep -qE "^Open loops: [0-9]+"; then
    count=$(echo "$output" | grep -E "^Open loops:" | awk '{print $NF}')
    pass "deterministic output: Open loops: $count"
  else
    fail "output should contain 'Open loops: N' line"
  fi
else
  # If file exists for some reason, skip this test
  echo "SKIP: open_loops.jsonl exists (unexpected — file was deprecated)"
fi

# Test 3: ops loops summary also works without jsonl
echo "--- Test 3: summary without jsonl ---"
if "$SP/bin/ops" loops summary >/dev/null 2>&1; then
  pass "ops loops summary succeeds without open_loops.jsonl"
else
  fail "ops loops summary should succeed without open_loops.jsonl"
fi

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
