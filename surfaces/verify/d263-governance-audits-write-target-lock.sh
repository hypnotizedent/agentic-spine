#!/usr/bin/env bash
# TRIAGE: stop new runtime write targets under docs/governance/_audits.
set -euo pipefail

ROOT_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="$ROOT_DEFAULT"
MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d263-governance-audits-write-target-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D263 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  MODE="enforce"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D263 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

FILES=(
  "ops/capabilities.yaml"
  "ops/bindings/capability_map.yaml"
  "ops/bindings/routing.dispatch.yaml"
  "ops/bindings/spine.schema.conventions.yaml"
  "ops/bindings/spine.boundary.baseline.yaml"
  "ops/bindings/mailroom.runtime.contract.yaml"
  "ops/plugins/verify/bin/schema-conventions-audit"
  "ops/plugins/verify/bin/calendar-surface-audit"
  "ops/plugins/verify/bin/surface-audit-full"
  "ops/plugins/surface/bin/surface-boundary-reconcile-plan"
  "ops/plugins/slo/bin/slo-evidence-daily"
  "surfaces/verify/d150-code-root-hygiene-lock.sh"
)

FINDINGS=0
finding() {
  echo "  $*"
  FINDINGS=$((FINDINGS + 1))
}

for rel in "${FILES[@]}"; do
  abs="$ROOT/$rel"
  if [[ ! -f "$abs" ]]; then
    finding "HIGH: missing required surface: $rel"
    continue
  fi

  if rg -n "docs/governance/_audits" "$abs" >/dev/null 2>&1; then
    finding "HIGH: legacy write target remains in $rel"
  fi
done

if [[ "$FINDINGS" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D263 FAIL: governance audits write-target lock findings=$FINDINGS"
    exit 1
  fi
  echo "D263 REPORT: governance audits write-target lock findings=$FINDINGS"
  exit 0
fi

echo "D263 PASS: governance audits write-target lock"
exit 0
