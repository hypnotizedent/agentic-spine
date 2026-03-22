#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
STATUS="$ROOT/ops/plugins/core/verify/bin/self-governance-closure-primitives-status"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s\n' "$haystack" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label (missing '$needle')"
  fi
}

echo "self-governance closure primitives status tests"
echo "════════════════════════════════════════"

set +e
brief_out="$(cd "$ROOT" && python3 "$STATUS" --root "$ROOT" --brief 2>&1)"
brief_rc=$?
set -e
if [[ "$brief_rc" -eq 0 ]]; then
  pass "brief status succeeds"
else
  fail "brief status succeeds"
  echo "$brief_out" >&2
fi
assert_contains "$brief_out" "issues=0" "brief status reports zero failing issues"

set +e
json_out="$(cd "$ROOT" && python3 "$STATUS" --root "$ROOT" --json 2>&1)"
json_rc=$?
set -e
if [[ "$json_rc" -eq 0 ]]; then
  pass "json status succeeds"
else
  fail "json status succeeds"
  echo "$json_out" >&2
fi
assert_contains "$json_out" "\"capability\": \"self-governance.closure.primitives.status\"" "json status reports capability name"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
