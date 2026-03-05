#!/usr/bin/env bash
# Tests for D350: spine experiment compare lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d350-spine-experiment-compare-lock.sh"

PASS=0
FAIL_COUNT=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1" >&2; }

echo "--- Test 1: live state PASS ---"
if SPINE_ROOT="$SP" bash "$GATE" >/dev/null 2>&1; then
  pass "D350 passes on current repo state"
else
  fail "D350 should pass on current repo state"
fi

echo "--- Test 2: missing contract FAIL ---"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/surfaces/verify"
cp "$GATE" "$TMP/surfaces/verify/d350-spine-experiment-compare-lock.sh"
chmod +x "$TMP/surfaces/verify/d350-spine-experiment-compare-lock.sh"
output="$(SPINE_ROOT="$TMP" bash "$TMP/surfaces/verify/d350-spine-experiment-compare-lock.sh" 2>&1)" && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D350 correctly fails when required contract/surfaces are missing (rc=$rc)"
else
  fail "D350 should fail when required surfaces are missing (rc=$rc, output: $output)"
fi

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
