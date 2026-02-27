#!/usr/bin/env bash
# TRIAGE: D254 image-age-budget-lock
# Report/enforce governance contract coverage for image freshness budget policy.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/docs/CANONICAL/W52_FOUNDATIONAL_CONTAINMENT_CONTRACT_V1.yaml"
MAPPING="$ROOT/docs/planning/W52_CONTROL_TO_FINDING_MAPPING.md"
GAPS="$ROOT/ops/bindings/operational.gaps.yaml"
W51="$ROOT/docs/planning/W51_FOUNDATIONAL_FORENSIC_AUDIT_MASTER_RECEIPT.md"
CONTROL_ID="D254"
MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d254-image-age-budget-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D254 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$CONTRACT" ]] || { echo "D254 FAIL: missing $CONTRACT" >&2; exit 1; }
[[ -f "$MAPPING" ]] || { echo "D254 FAIL: missing $MAPPING" >&2; exit 1; }
[[ -f "$GAPS" ]] || { echo "D254 FAIL: missing $GAPS" >&2; exit 1; }
[[ -f "$W51" ]] || { echo "D254 FAIL: missing $W51" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "D254 FAIL: yq missing" >&2; exit 1; }
command -v rg >/dev/null 2>&1 || { echo "D254 FAIL: rg missing" >&2; exit 1; }

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$CONTRACT" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D254 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

FINDINGS=0
finding() {
  local severity="$1"
  shift
  echo "  ${severity}: $*"
  FINDINGS=$((FINDINGS + 1))
}

gate_id="$(yq -r ".controls.${CONTROL_ID}.gate_id // \"\"" "$CONTRACT" 2>/dev/null || true)"
linked_gap_id="$(yq -r ".controls.${CONTROL_ID}.linked_gap_id // \"\"" "$CONTRACT" 2>/dev/null || true)"
report_mode="$(yq -r ".controls.${CONTROL_ID}.policy.report_mode // false" "$CONTRACT" 2>/dev/null || echo false)"
promote_count="$(yq -r ".controls.${CONTROL_ID}.policy.promotion_criteria | length" "$CONTRACT" 2>/dev/null || echo 0)"

[[ "$gate_id" == "$CONTROL_ID" ]] || finding "HIGH" "contract gate_id drift: expected $CONTROL_ID got '$gate_id'"
[[ "$report_mode" == "true" ]] || finding "HIGH" "contract must remain report_mode=true during W52A"
[[ "$promote_count" =~ ^[0-9]+$ ]] || promote_count=0
(( promote_count > 0 )) || finding "HIGH" "promotion_criteria must be populated"
[[ -n "$linked_gap_id" ]] || finding "HIGH" "linked_gap_id missing in contract"

if [[ -n "$linked_gap_id" ]]; then
  gap_exists="$(yq -r ".gaps[] | select(.id == \"$linked_gap_id\") | .id" "$GAPS" 2>/dev/null | head -n1)"
  [[ "$gap_exists" == "$linked_gap_id" ]] || finding "HIGH" "linked gap '$linked_gap_id' not found in operational.gaps.yaml"
fi

rg -q "${CONTROL_ID}" "$MAPPING" || finding "MEDIUM" "mapping doc missing ${CONTROL_ID}"
[[ -z "$linked_gap_id" ]] || rg -q "$linked_gap_id" "$MAPPING" || finding "MEDIUM" "mapping doc missing linked gap $linked_gap_id"
rg -qi "minio image 173 days old|image age" "$W51" || finding "MEDIUM" "W51 evidence marker for image-age finding not present"

if [[ "$FINDINGS" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D254 FAIL: image age governance findings=$FINDINGS"
    exit 1
  fi
  echo "D254 REPORT: image age governance findings=$FINDINGS"
  exit 0
fi

echo "D254 PASS: image age budget governance lock"
exit 0
