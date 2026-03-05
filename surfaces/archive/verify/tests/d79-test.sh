#!/usr/bin/env bash
set -euo pipefail

# d79-test.sh — Unit tests for D79 workbench script allowlist lock
#
# Tests:
#   1. PASS: live workbench passes gate
#   2. PASS: binding parseable and has expected structure
#   3. FAIL: unregistered script detected (simulated)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$ROOT/surfaces/verify/d79-workbench-script-allowlist-lock.sh"
BINDING="$ROOT/ops/bindings/workbench.script.allowlist.yaml"

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
# Test 2: Binding structure validation
# ─────────────────────────────────────────────────────────────────────────
test_binding_structure() {
  echo "Test 2: Binding file structure"
  if [[ -f "$BINDING" ]]; then
    ver="$(yq e '.version' "$BINDING" 2>/dev/null)"
    gate="$(yq e '.gate_id' "$BINDING" 2>/dev/null)"
    count="$(yq e '.scripts | length' "$BINDING" 2>/dev/null)"
    if [[ "$ver" == "1" && "$gate" == "D79" && "$count" -gt 0 ]]; then
      pass "binding has correct structure (version=$ver, gate=$gate, scripts=$count)"
    else
      fail "binding structure invalid: ver=$ver, gate=$gate, count=$count"
    fi
  else
    fail "binding file missing"
  fi
}

# ─────────────────────────────────────────────────────────────────────────
# Test 3: FAIL — unregistered script
# ─────────────────────────────────────────────────────────────────────────
test_unregistered_script() {
  echo "Test 3: Unregistered script detection"
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/scripts/root" "$TMPDIR/scripts/agents" "$TMPDIR/dotfiles/raycast"

  # Create a script that IS in the allowlist
  echo '#!/bin/bash' > "$TMPDIR/scripts/root/spine_terminal_entry.sh"
  # Create a script that is NOT in the allowlist
  echo '#!/bin/bash' > "$TMPDIR/scripts/root/rogue-unregistered.sh"

  if WORKBENCH_ROOT="$TMPDIR" bash "$GATE" 2>/dev/null; then
    fail "unregistered script should be caught"
  else
    pass "unregistered script correctly rejected"
  fi

  rm -rf "$TMPDIR"
}

# ─────────────────────────────────────────────────────────────────────────
# Run all tests
# ─────────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  D79 Workbench Script Allowlist Lock Tests"
echo "═══════════════════════════════════════════════════════════════"
echo

test_live_workbench
echo
test_binding_structure
echo
test_unregistered_script

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL_COUNT failed"
echo "═══════════════════════════════════════════════════════════════"

[[ $FAIL_COUNT -gt 0 ]] && exit 1
exit 0
