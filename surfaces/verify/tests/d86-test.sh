#!/usr/bin/env bash
# Tests for D86: VM operating profile parity lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d86-vm-operating-profile-parity-lock.sh"
REAL_LIFECYCLE="$SP/ops/bindings/vm.lifecycle.yaml"
REAL_PROFILE="$SP/ops/bindings/vm.operating.profile.yaml"

PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

setup_mock() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/ops/bindings"
  cp "$REAL_LIFECYCLE" "$tmp/ops/bindings/vm.lifecycle.yaml"
  cp "$REAL_PROFILE" "$tmp/ops/bindings/vm.operating.profile.yaml"
  echo "$tmp"
}

cleanup_mock() {
  [[ -n "${1:-}" && -d "$1" ]] && rm -rf "$1" || true
}

# ── Test 1: Live pass ──
echo "--- Test 1: live state PASS ---"
if bash "$GATE" >/dev/null 2>&1; then
  pass "D86 passes on current repo state"
else
  fail "D86 should pass on current repo state"
fi

# ── Test 2: Missing profile entry fails ──
echo "--- Test 2: missing profile entry ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
# Remove the last profile entry (VM 102 vaultwarden)
yq -i 'del(.profiles[-1])' "$MOCK/ops/bindings/vm.operating.profile.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D86 correctly detects missing profile entry (rc=$rc)"
else
  fail "D86 should fail for missing profile entry (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

# ── Test 3: Invalid enum value fails ──
echo "--- Test 3: invalid enum value ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
yq -i '.profiles[0].ssh_mode = "bogus_mode"' "$MOCK/ops/bindings/vm.operating.profile.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D86 correctly detects invalid enum value (rc=$rc)"
else
  fail "D86 should fail for invalid enum value (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

# ── Test 4: Null required field fails ──
echo "--- Test 4: null required field ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
yq -i '.profiles[0].backup_policy = null' "$MOCK/ops/bindings/vm.operating.profile.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D86 correctly detects null required field (rc=$rc)"
else
  fail "D86 should fail for null required field (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
