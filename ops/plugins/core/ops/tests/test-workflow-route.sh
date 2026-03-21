#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
ROUTE="$ROOT/ops/plugins/core/ops/bin/workflow-route"

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

echo "workflow route tests"
echo "════════════════════════════════════════"

set +e
loop_out="$(cd "$ROOT" && SPINE_TARGET_REPO="$ROOT" python3 "$ROUTE" loop --json 2>&1)"
loop_status=$?
set -e
if [[ "$loop_status" == "0" ]]; then
  pass "loop concept resolves"
else
  fail "loop concept resolves"
fi
assert_contains "$loop_out" "\"concept\": \"loop\"" "loop route returns loop concept"
assert_contains "$loop_out" "\"primary_capability\": \"loops.create\"" "loop route returns primary capability"

set +e
alias_out="$(cd "$ROOT" && SPINE_TARGET_REPO="$ROOT" python3 "$ROUTE" "planned work" --json 2>&1)"
alias_status=$?
set -e
if [[ "$alias_status" == "0" ]]; then
  pass "alias resolves"
else
  fail "alias resolves"
fi
assert_contains "$alias_out" "\"concept\": \"plan\"" "alias resolves to plan"

set +e
unknown_out="$(cd "$ROOT" && SPINE_TARGET_REPO="$ROOT" python3 "$ROUTE" nonsense-term 2>&1)"
unknown_status=$?
set -e
if [[ "$unknown_status" == "1" ]]; then
  pass "unknown concept fails"
else
  fail "unknown concept fails"
fi
assert_contains "$unknown_out" "workflow.route FAIL: unknown concept" "unknown concept failure is explicit"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
