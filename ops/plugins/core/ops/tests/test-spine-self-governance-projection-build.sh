#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
BUILD="$ROOT/ops/plugins/core/authority/bin/spine-self-governance-projection-build"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (expected: $needle)"
  fi
}

echo "spine self-governance projection build tests"
echo "════════════════════════════════════════"

set +e
catalog_out="$(cd "$ROOT" && SPINE_TARGET_REPO="$ROOT" python3 "$BUILD" --stdout catalog 2>&1)"
catalog_status=$?
set -e
if [[ "$catalog_status" == "0" ]]; then
  pass "catalog stdout generation succeeds"
else
  fail "catalog stdout generation succeeds"
fi
assert_contains "$catalog_out" "required_core_concepts:" "catalog includes required concept list"
assert_contains "$catalog_out" "route_ready: true" "catalog includes route readiness"

set +e
projected_out="$(cd "$ROOT" && SPINE_TARGET_REPO="$ROOT" python3 "$BUILD" --stdout projected 2>&1)"
projected_status=$?
set -e
if [[ "$projected_status" == "0" ]]; then
  pass "projected stdout generation succeeds"
else
  fail "projected stdout generation succeeds"
fi
assert_contains "$projected_out" "session_entry_and_degraded_bootstrap:" "projected output includes degraded bootstrap dimension"
assert_contains "$projected_out" "telemetry_capability: spine.surface.usage.telemetry" "projected output includes telemetry capability"

set +e
check_out="$(cd "$ROOT" && SPINE_TARGET_REPO="$ROOT" python3 "$BUILD" --check 2>&1)"
check_status=$?
set -e
if [[ "$check_status" == "0" ]]; then
  pass "projection parity check succeeds"
else
  fail "projection parity check succeeds"
fi
assert_contains "$check_out" "PASS" "projection parity check prints pass"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
