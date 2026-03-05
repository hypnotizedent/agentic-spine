#!/usr/bin/env bash
set -euo pipefail

# d77-test.sh — Unit tests for D77 workbench contract lock
#
# Tests:
#   1. PASS: live workbench passes gate
#   2. FAIL: unexpected plist detected
#   3. FAIL: runtime-like directory detected

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$ROOT/surfaces/verify/d77-workbench-contract-lock.sh"

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
# Test 2: FAIL — unexpected plist
# ─────────────────────────────────────────────────────────────────────────
test_unexpected_plist() {
  echo "Test 2: Unexpected plist detection"
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/scripts/root" "$TMPDIR/dotfiles/raycast" "$TMPDIR/dotfiles/macbook/launchd"
  # Create allowed plist
  echo '<?xml version="1.0"?><plist></plist>' > "$TMPDIR/dotfiles/macbook/launchd/com.ronny.agent-inbox.plist"
  # Create unexpected plist
  echo '<?xml version="1.0"?><plist></plist>' > "$TMPDIR/rogue.plist"

  if WORKBENCH_ROOT="$TMPDIR" bash "$GATE" 2>/dev/null; then
    fail "unexpected plist should be caught"
  else
    pass "unexpected plist correctly rejected"
  fi

  rm -rf "$TMPDIR"
}

# ─────────────────────────────────────────────────────────────────────────
# Test 3: FAIL — runtime-like directory
# ─────────────────────────────────────────────────────────────────────────
test_runtime_dir() {
  echo "Test 3: Runtime-like directory detection"
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/scripts/root" "$TMPDIR/dotfiles/raycast" "$TMPDIR/mailroom"

  if WORKBENCH_ROOT="$TMPDIR" bash "$GATE" 2>/dev/null; then
    fail "runtime-like directory should be caught"
  else
    pass "runtime-like directory correctly rejected"
  fi

  rm -rf "$TMPDIR"
}

# ─────────────────────────────────────────────────────────────────────────
# Run all tests
# ─────────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  D77 Workbench Contract Lock Tests"
echo "═══════════════════════════════════════════════════════════════"
echo

test_live_workbench
echo
test_unexpected_plist
echo
test_runtime_dir

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL_COUNT failed"
echo "═══════════════════════════════════════════════════════════════"

[[ $FAIL_COUNT -gt 0 ]] && exit 1
exit 0
