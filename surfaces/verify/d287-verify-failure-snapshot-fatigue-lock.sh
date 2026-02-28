#!/usr/bin/env bash
# TRIAGE: split deterministic failures from external snapshot freshness failures.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SCRIPT="$ROOT/ops/plugins/verify/bin/verify-failure-classify"
CONTRACT="$ROOT/ops/bindings/verify.failure.classification.contract.yaml"
RUNTIME="$ROOT/ops/runtime/slo-evidence-daily.sh"

fail() {
  echo "D287 FAIL: $*" >&2
  exit 1
}

[[ -x "$SCRIPT" ]] || fail "missing verify-failure-classify script"
[[ -f "$CONTRACT" ]] || fail "missing classification contract"
[[ -f "$RUNTIME" ]] || fail "missing runtime SLO script"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"

kw_count="$(yq e '.freshness_keywords | length' "$CONTRACT")"
[[ "$kw_count" -gt 0 ]] || fail "freshness_keywords is empty"
rg -n 'verify-failure-classify' "$RUNTIME" >/dev/null 2>&1 || fail "slo-evidence runtime script must call verify-failure-classify"

VERIFY_FAILURE_CLASSIFY_DRYRUN=1 "$SCRIPT" core >/dev/null

echo "D287 PASS: verify failure snapshot-fatigue lock enforced"
