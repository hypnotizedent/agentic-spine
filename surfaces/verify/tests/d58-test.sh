#!/usr/bin/env bash
# Tests for D58: SSOT freshness lock + binding freshness exemptions
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d58-ssot-freshness-lock.sh"
EXEMPTIONS="$SP/ops/bindings/binding.freshness.exemptions.yaml"
PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

# Test 1: Gate passes on current repo state
echo "--- Test 1: live state PASS ---"
if bash "$GATE" >/dev/null 2>&1; then
  pass "D58 passes on current repo state"
else
  fail "D58 should pass on current repo state"
fi

# Test 2: Exemptions file exists and has 16 entries
echo "--- Test 2: exemption file structure ---"
if [[ -f "$EXEMPTIONS" ]]; then
  exempt_count=$(yq '.exempt | length' "$EXEMPTIONS")
  if [[ "$exempt_count" -eq 16 ]]; then
    pass "exemptions file has 16 entries"
  else
    fail "exemptions file should have 16 entries (got $exempt_count)"
  fi
else
  fail "exemptions file not found at $EXEMPTIONS"
fi

# Test 3: All exempt files actually exist
echo "--- Test 3: exempt files exist ---"
missing=0
for ((i=0; i<16; i++)); do
  ef=$(yq -r ".exempt[$i].file" "$EXEMPTIONS")
  if [[ ! -f "$SP/ops/bindings/$ef" ]]; then
    echo "  MISSING: $ef" >&2
    missing=$((missing + 1))
  fi
done
if [[ "$missing" -eq 0 ]]; then
  pass "all 16 exempt binding files exist"
else
  fail "$missing exempt binding files are missing"
fi

# Test 4: Stale normative binding detection (negative test)
# D58 derives SP from BASH_SOURCE, so we inject a temp stale binding
# into the real bindings dir and clean up after.
echo "--- Test 4: stale binding detection ---"
STALE_FILE="$SP/ops/bindings/_test_stale_policy.yaml"
trap 'rm -f "$STALE_FILE"' EXIT

cat >"$STALE_FILE" <<'YAML'
updated: "2025-01-01"
rules:
  - test: true
YAML

output=$(bash "$GATE" 2>&1) && rc=$? || rc=$?
rm -f "$STALE_FILE"

if [[ "$rc" -ne 0 ]]; then
  pass "D58 correctly detects stale normative binding (rc=$rc)"
else
  fail "D58 should fail for stale normative binding (rc=$rc)"
fi

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
