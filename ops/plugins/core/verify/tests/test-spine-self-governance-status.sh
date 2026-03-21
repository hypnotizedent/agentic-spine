#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
STATUS="$ROOT/ops/plugins/core/verify/bin/spine-self-governance-status"

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

echo "spine self-governance status tests"
echo "════════════════════════════════════════"

set +e
brief_out="$(cd "$ROOT" && SPINE_TARGET_REPO="$ROOT" python3 "$STATUS" --brief 2>&1)"
brief_status=$?
set -e
if [[ "$brief_status" == "0" ]]; then
  pass "brief self-governance status succeeds"
else
  fail "brief self-governance status succeeds"
fi
assert_contains "$brief_out" "workflow_concepts=5" "status reports workflow concept count"
assert_contains "$brief_out" "issues=0" "status reports zero failing issues"

set +e
json_out="$(cd "$ROOT" && SPINE_TARGET_REPO="$ROOT" python3 "$STATUS" --json 2>&1)"
json_status=$?
set -e
if [[ "$json_status" == "0" ]]; then
  pass "json self-governance status succeeds"
else
  fail "json self-governance status succeeds"
fi
assert_contains "$json_out" "\"capability\": \"spine.self-governance.status\"" "json status reports capability name"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
