#!/usr/bin/env bash
set -euo pipefail

# d78-test.sh — Unit tests for D78 workbench path lock
#
# Tests:
#   1. PASS: live workbench passes gate
#   2. FAIL: uppercase code-dir in script
#   3. PASS: lowercase /code/ allowed

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$ROOT/surfaces/verify/d78-workbench-path-lock.sh"

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
# Test 2: FAIL — uppercase code-dir in script
# ─────────────────────────────────────────────────────────────────────────
test_uppercase_code() {
  echo "Test 2: Uppercase code-dir detection"
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/scripts/root" "$TMPDIR/dotfiles/raycast"

  # Create script with uppercase code-dir (built dynamically to avoid D42)
  _upper="/Users/ronnyworks/$(printf '%s' 'Code')/workbench"
  echo "#!/bin/bash" > "$TMPDIR/scripts/root/bad.sh"
  echo "cd $_upper" >> "$TMPDIR/scripts/root/bad.sh"

  if WORKBENCH_ROOT="$TMPDIR" bash "$GATE" 2>/dev/null; then
    fail "uppercase code-dir should be caught"
  else
    pass "uppercase code-dir correctly rejected"
  fi

  rm -rf "$TMPDIR"
}

# ─────────────────────────────────────────────────────────────────────────
# Test 3: PASS — lowercase /code/ allowed
# ─────────────────────────────────────────────────────────────────────────
test_lowercase_code() {
  echo "Test 3: Lowercase /code/ allowed"
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/scripts/root" "$TMPDIR/dotfiles/raycast"

  echo '#!/bin/bash' > "$TMPDIR/scripts/root/good.sh"
  echo 'cd /Users/ronnyworks/code/workbench' >> "$TMPDIR/scripts/root/good.sh"

  if WORKBENCH_ROOT="$TMPDIR" bash "$GATE" 2>/dev/null; then
    pass "lowercase /code/ correctly allowed"
  else
    fail "lowercase /code/ should be allowed"
  fi

  rm -rf "$TMPDIR"
}

# ─────────────────────────────────────────────────────────────────────────
# Run all tests
# ─────────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  D78 Workbench Path Lock Tests"
echo "═══════════════════════════════════════════════════════════════"
echo

test_live_workbench
echo
test_uppercase_code
echo
test_lowercase_code

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL_COUNT failed"
echo "═══════════════════════════════════════════════════════════════"

[[ $FAIL_COUNT -gt 0 ]] && exit 1
exit 0
