#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "${ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
TELEMETRY="$ROOT/ops/plugins/core/evidence/bin/spine-surface-usage-telemetry"

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

echo "spine surface usage telemetry tests"
echo "════════════════════════════════════════"

set +e
brief_out="$(cd "$ROOT" && python3 "$TELEMETRY" --root "$ROOT" --brief 2>&1)"
brief_status=$?
set -e
if [[ "$brief_status" == "0" ]]; then
  pass "brief telemetry succeeds"
else
  fail "brief telemetry succeeds"
fi
assert_contains "$brief_out" "status=ok" "brief telemetry reports status"

set +e
json_out="$(cd "$ROOT" && python3 "$TELEMETRY" --root "$ROOT" --json 2>&1)"
json_status=$?
set -e
if [[ "$json_status" == "0" ]]; then
  pass "json telemetry succeeds"
else
  fail "json telemetry succeeds"
fi
assert_contains "$json_out" "\"capability\": \"spine.surface.usage.telemetry\"" "json telemetry reports capability name"
assert_contains "$json_out" "\"tracked_total\"" "json telemetry reports tracked bindings"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
