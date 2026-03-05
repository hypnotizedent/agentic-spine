#!/usr/bin/env bash
# TRIAGE: Detect untracked receipt crumbs left after closeout.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/wave.closeout.contract.yaml"

MODE="enforce"

usage() {
  cat <<'USAGE'
Usage: d274-receipt-closeout-completeness-lock.sh [--policy report|enforce]

Checks:
  - Untracked receipt markdown files under docs/planning matching the governed receipt regex.
  - Planning docs active-file ceiling (contract-driven).
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    --)
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "D274 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || {
  echo "D274 FAIL: invalid policy mode '$MODE'" >&2
  exit 2
}

[[ -d "$ROOT/.git" || -f "$ROOT/.git" ]] || {
  echo "D274 FAIL: not a git repository root: $ROOT" >&2
  exit 1
}

RECEIPT_REGEX='(^|/)docs/planning/W[^/]*RECEIPT[^/]*\.md$'
BLOCK_UNTRACKED="true"
PLANNING_BUDGET_ENABLED="false"
PLANNING_MAX_ACTIVE_DOCS="50"

if command -v yq >/dev/null 2>&1 && [[ -f "$CONTRACT" ]]; then
  RECEIPT_REGEX="$(yq e -r '.receipt_crumb_detection.untracked_receipt_regex // "'"$RECEIPT_REGEX"'"' "$CONTRACT" 2>/dev/null || echo "$RECEIPT_REGEX")"
  BLOCK_UNTRACKED="$(yq e -r '.receipt_crumb_detection.block_untracked // true' "$CONTRACT" 2>/dev/null || echo "true")"
  PLANNING_BUDGET_ENABLED="$(yq e -r '.planning_budget.enabled // false' "$CONTRACT" 2>/dev/null || echo "false")"
  PLANNING_MAX_ACTIVE_DOCS="$(yq e -r '.planning_budget.max_active_docs // 50' "$CONTRACT" 2>/dev/null || echo "50")"
fi

FINDINGS=0
while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  if [[ "$path" =~ $RECEIPT_REGEX ]]; then
    echo "D274 finding: untracked_receipt=$path" >&2
    FINDINGS=$((FINDINGS + 1))
  fi
done < <(git -C "$ROOT" ls-files --others --exclude-standard)

if [[ "$PLANNING_BUDGET_ENABLED" == "true" ]]; then
  if ! [[ "$PLANNING_MAX_ACTIVE_DOCS" =~ ^[0-9]+$ ]]; then
    echo "D274 FAIL: planning_budget.max_active_docs must be an integer (got '$PLANNING_MAX_ACTIVE_DOCS')" >&2
    exit 2
  fi
  planning_count="$(find "$ROOT/docs/planning" -type f 2>/dev/null | wc -l | tr -d ' ')"
  if (( planning_count > PLANNING_MAX_ACTIVE_DOCS )); then
    echo "D274 FAIL: planning docs ceiling exceeded (${planning_count} > ${PLANNING_MAX_ACTIVE_DOCS})" >&2
    exit 1
  fi
fi

if [[ "$BLOCK_UNTRACKED" != "true" ]]; then
  echo "D274 PASS: untracked receipt blocking disabled by contract"
  exit 0
fi

if [[ "$FINDINGS" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D274 FAIL: receipt closeout completeness findings=$FINDINGS" >&2
    exit 1
  fi
  echo "D274 REPORT: receipt closeout completeness findings=$FINDINGS"
  exit 0
fi

if [[ "$PLANNING_BUDGET_ENABLED" == "true" ]]; then
  planning_count="$(find "$ROOT/docs/planning" -type f 2>/dev/null | wc -l | tr -d ' ')"
  echo "D274 PASS: no untracked receipt crumbs detected (planning_docs=${planning_count}/${PLANNING_MAX_ACTIVE_DOCS})"
else
  echo "D274 PASS: no untracked receipt crumbs detected"
fi
