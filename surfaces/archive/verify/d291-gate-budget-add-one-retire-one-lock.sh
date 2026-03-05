#!/usr/bin/env bash
# TRIAGE: Pair any new invariant gates with explicit demotion/retirement plan.
# D291: gate-budget-add-one-retire-one-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
REPORT_SCRIPT="$ROOT/ops/plugins/verify/bin/gate-budget-add-one-retire-one-report"
BUDGET_CONTRACT="$ROOT/ops/bindings/gate.budget.add_one_retire_one.contract.yaml"
ENFORCEMENT_POLICY="$ROOT/ops/bindings/gate.enforcement.policy.yaml"

fail() {
  echo "D291 FAIL: $*" >&2
  exit 1
}

[[ -x "$REPORT_SCRIPT" ]] || fail "missing executable report script: $REPORT_SCRIPT"
[[ -f "$BUDGET_CONTRACT" ]] || fail "missing budget contract: $BUDGET_CONTRACT"
[[ -f "$ENFORCEMENT_POLICY" ]] || fail "missing enforcement policy: $ENFORCEMENT_POLICY"

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

contract_mode="$(yq e -r '.mode // "report-only"' "$BUDGET_CONTRACT" 2>/dev/null || echo "report-only")"
policy_mode="$(yq e -r '.controls.D291.mode // "report-only"' "$ENFORCEMENT_POLICY" 2>/dev/null || echo "report-only")"

if [[ "$contract_mode" == "enforce" || "$policy_mode" == "enforce" ]]; then
  effective_mode="enforce"
else
  effective_mode="report-only"
fi

override_mode="${SPINE_ENFORCEMENT_MODE:-}"
if [[ -n "$override_mode" ]]; then
  case "$override_mode" in
    enforce|report-only) effective_mode="$override_mode" ;;
    *) fail "invalid SPINE_ENFORCEMENT_MODE=$override_mode (expected enforce|report-only)" ;;
  esac
fi

output="$("$REPORT_SCRIPT" 2>&1)" || fail "budget report generation failed"
echo "$output"

violations="$(printf '%s\n' "$output" | awk -F': ' '/^violations: /{print $2; exit}')"
if [[ -z "${violations:-}" ]]; then
  fail "unable to parse violations from budget report output"
fi

report_path="$(yq e -r '.report.markdown_path // ""' "$BUDGET_CONTRACT" 2>/dev/null || true)"
[[ -n "$report_path" && "$report_path" != "null" ]] || fail "budget contract missing report.markdown_path"
REPORT_PATH="$ROOT/$report_path"

if [[ ! -f "$REPORT_PATH" ]]; then
  fail "expected report not generated: $REPORT_PATH"
fi

if [[ "$violations" =~ ^[0-9]+$ ]] && [[ "$violations" -gt 0 ]]; then
  if [[ "$effective_mode" == "enforce" ]]; then
    fail "budget violations detected ($violations) in enforce mode — see $REPORT_PATH"
  fi
  echo "D291 PASS (report-only): budget violations detected ($violations) — see $REPORT_PATH"
else
  echo "D291 PASS ($effective_mode): no budget violations — see $REPORT_PATH"
fi

exit 0
