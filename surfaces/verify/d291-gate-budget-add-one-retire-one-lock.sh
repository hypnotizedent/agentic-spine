#!/usr/bin/env bash
# D291: gate-budget-add-one-retire-one-lock (report-only)
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
REPORT_SCRIPT="$ROOT/ops/plugins/verify/bin/gate-budget-add-one-retire-one-report"
REPORT_PATH="$ROOT/docs/planning/W65_GATE_BUDGET_REPORT.md"

fail() {
  echo "D291 FAIL: $*" >&2
  exit 1
}

[[ -x "$REPORT_SCRIPT" ]] || fail "missing executable report script: $REPORT_SCRIPT"

output="$("$REPORT_SCRIPT" 2>&1)" || fail "budget report generation failed"
echo "$output"

violations="$(printf '%s\n' "$output" | awk -F': ' '/^violations: /{print $2; exit}')"
if [[ -z "${violations:-}" ]]; then
  fail "unable to parse violations from budget report output"
fi

if [[ ! -f "$REPORT_PATH" ]]; then
  fail "expected report not generated: $REPORT_PATH"
fi

if [[ "$violations" =~ ^[0-9]+$ ]] && [[ "$violations" -gt 0 ]]; then
  echo "D291 PASS (report-only): budget violations detected ($violations) — see $REPORT_PATH"
else
  echo "D291 PASS (report-only): no budget violations — see $REPORT_PATH"
fi

exit 0
