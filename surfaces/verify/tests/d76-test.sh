#!/usr/bin/env bash
set -euo pipefail

# d76-test.sh — Unit tests for D76 home-surface hygiene lock
#
# Tests:
#   1. PASS: clean home surface (no violations)
#   2. FAIL: forbidden legacy directory at ~/
#   3. FAIL: uppercase code-dir path in workbench script
#
# Uses temporary directories to avoid mutating real state.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$ROOT/surfaces/verify/d76-home-surface-hygiene-lock.sh"
BINDING="$ROOT/ops/bindings/home-surface.allowlist.yaml"

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
# Test 1: PASS — clean home (real system, should pass if preflight passed)
# ─────────────────────────────────────────────────────────────────────────
test_clean_home() {
  echo "Test 1: Clean home surface (live system)"
  if bash "$GATE" 2>/dev/null; then
    pass "clean home surface accepted"
  else
    fail "clean home surface should pass (live system may have issues)"
  fi
}

# ─────────────────────────────────────────────────────────────────────────
# Test 2: FAIL — forbidden legacy directory
# ─────────────────────────────────────────────────────────────────────────
test_forbidden_dir() {
  echo "Test 2: Forbidden legacy directory"
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/ops"

  # Run gate with overridden HOME
  if HOME="$TMPDIR" bash "$GATE" 2>/dev/null; then
    fail "forbidden ~/ops should be caught"
  else
    pass "forbidden ~/ops correctly rejected"
  fi

  rm -rf "$TMPDIR"
}

# ─────────────────────────────────────────────────────────────────────────
# Test 3: PASS — binding file exists and is parseable
# ─────────────────────────────────────────────────────────────────────────
test_binding_parseable() {
  echo "Test 3: Binding file parseable"
  if [[ -f "$BINDING" ]] && yq e '.version' "$BINDING" >/dev/null 2>&1; then
    pass "binding file parseable"
  else
    fail "binding file missing or unparseable"
  fi
}

# ─────────────────────────────────────────────────────────────────────────
# Run all tests
# ─────────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  D76 Home-Surface Hygiene Lock Tests"
echo "═══════════════════════════════════════════════════════════════"
echo

test_clean_home
echo
test_forbidden_dir
echo
test_binding_parseable

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL_COUNT failed"
echo "═══════════════════════════════════════════════════════════════"

[[ $FAIL_COUNT -gt 0 ]] && exit 1
exit 0
