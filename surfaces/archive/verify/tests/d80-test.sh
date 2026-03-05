#!/usr/bin/env bash
set -euo pipefail

# d80-test.sh — Unit tests for D80 workbench authority-trace lock
#
# Tests:
#   1. PASS: live workbench passes gate
#   2. PASS: authority-trace.sh exists and is executable
#   3. FAIL: missing authority-trace.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$ROOT/surfaces/verify/d80-workbench-authority-trace-lock.sh"

PASS=0
FAIL_COUNT=0
TMPDIR=""

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }

teardown() {
  rm -rf "$TMPDIR" 2>/dev/null || true
}
trap teardown EXIT INT TERM

# ─────────────────────────────────────────────────────────────────────────
# Test 1: PASS — live workbench
# ─────────────────────────────────────────────────────────────────────────
test_live_workbench() {
  echo "Test 1: Live workbench passes gate"
  if bash "$GATE" 2>/dev/null; then
    pass "live workbench accepted"
  else
    fail "live workbench should pass"
  fi
}

# ─────────────────────────────────────────────────────────────────────────
# Test 2: authority-trace.sh exists
# ─────────────────────────────────────────────────────────────────────────
test_script_exists() {
  echo "Test 2: authority-trace.sh exists and is executable"
  WORKBENCH="${WORKBENCH_ROOT:-$HOME/code/workbench}"
  if [[ -x "$WORKBENCH/scripts/root/authority-trace.sh" ]]; then
    pass "authority-trace.sh present and executable"
  else
    fail "authority-trace.sh missing or not executable"
  fi
}

# ─────────────────────────────────────────────────────────────────────────
# Test 3: FAIL — missing authority-trace.sh
# ─────────────────────────────────────────────────────────────────────────
test_missing_script() {
  echo "Test 3: Missing authority-trace.sh detection"
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/scripts/root"
  # Do NOT create authority-trace.sh

  if WORKBENCH_ROOT="$TMPDIR" bash "$GATE" 2>/dev/null; then
    fail "missing script should be caught"
  else
    pass "missing script correctly rejected"
  fi

  rm -rf "$TMPDIR"
}

# ─────────────────────────────────────────────────────────────────────────
# Run all tests
# ─────────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  D80 Workbench Authority-Trace Lock Tests"
echo "═══════════════════════════════════════════════════════════════"
echo

test_live_workbench
echo
test_script_exists
echo
test_missing_script

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL_COUNT failed"
echo "═══════════════════════════════════════════════════════════════"

[[ $FAIL_COUNT -gt 0 ]] && exit 1
exit 0
