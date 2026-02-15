#!/usr/bin/env bash
# Tests for tenant.profile.validate capability
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SCRIPT="$SP/ops/plugins/tenant/bin/tenant-profile-validate"
FIXTURE="$SP/fixtures/tenant.sample.yaml"

PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

# Test 1: Valid sample fixture passes
test_valid_fixture() {
  if [[ ! -f "$FIXTURE" ]]; then
    fail "fixture missing: $FIXTURE"
    return
  fi
  if SPINE_ROOT="$SP" bash "$SCRIPT" --profile "$FIXTURE" >/dev/null 2>&1; then
    pass "valid fixture passes validation"
  else
    fail "valid fixture should pass validation"
  fi
}

# Test 2: No args shows usage
test_no_args() {
  local out
  out="$(bash "$SCRIPT" 2>&1 || true)"
  if echo "$out" | grep -q "Usage:"; then
    pass "no args shows usage"
  else
    fail "no args should show usage"
  fi
}

# Test 3: Missing file errors
test_missing_file() {
  local out
  out="$(bash "$SCRIPT" --profile /nonexistent/path.yaml 2>&1 || true)"
  if echo "$out" | grep -q "ERROR"; then
    pass "missing file shows error"
  else
    fail "missing file should show error"
  fi
}

# Test 4: Invalid profile fails validation
test_invalid_profile() {
  local tmp
  tmp="$(mktemp)"
  echo "identity: {}" > "$tmp"
  if SPINE_ROOT="$SP" bash "$SCRIPT" --profile "$tmp" >/dev/null 2>&1; then
    fail "invalid profile should fail validation"
  else
    pass "invalid profile fails validation"
  fi
  rm -f "$tmp"
}

echo "tenant-profile-validate Tests"
echo "════════════════════════════════════════"
test_valid_fixture
test_no_args
test_missing_file
test_invalid_profile

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL_COUNT failed (of $((PASS + FAIL_COUNT)))"
exit "$FAIL_COUNT"
