#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
PLAN="$ROOT/ops/plugins/calendar/bin/calendar-sync-plan"
export SPINE_CODE="$ROOT"
export SPINE_REPO="$ROOT"
export SPINE_ROOT="$ROOT"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

echo "calendar-sync-plan tests"
echo "════════════════════════════════════════"

command -v jq >/dev/null 2>&1 || { echo "MISSING_DEP: jq" >&2; exit 2; }

echo ""
echo "T1: planner emits valid JSON dry-run envelope"
(
  out="$("$PLAN" --json)"
  echo "$out" | jq -e '
    .capability == "calendar.sync.plan" and
    .status == "ok" and
    .data.dry_run == true and
    (.data.actions | length == 6)
  ' >/dev/null
) && pass "JSON envelope valid" || fail "JSON envelope valid"

echo ""
echo "T2: identity/personal plan directions are pull (external authoritative)"
(
  out="$("$PLAN" --json)"
  echo "$out" | jq -e '
    ([.data.actions[] | select(.layer == "identity" or .layer == "personal") | .direction] | all(. == "pull")) and
    ([.data.actions[] | select(.layer == "identity" or .layer == "personal") | .conflict_winner] | all(. == "external"))
  ' >/dev/null
) && pass "identity/personal pull direction" || fail "identity/personal pull direction"

echo ""
echo "T3: infrastructure/automation/spine include planned graph upsert caps"
(
  out="$("$PLAN" --json)"
  echo "$out" | jq -e '
    ([.data.actions[] | select(.layer == "infrastructure" or .layer == "automation" or .layer == "spine") | .direction] | all(. == "push")) and
    ([.data.actions[] | select(.layer == "infrastructure" or .layer == "automation" or .layer == "spine") | (.write_capabilities | index("graph.calendar.create") != null and index("graph.calendar.update") != null)] | all(. == true))
  ' >/dev/null
) && pass "spine-authoritative layers include upsert contracts" || fail "spine-authoritative layers include upsert contracts"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
