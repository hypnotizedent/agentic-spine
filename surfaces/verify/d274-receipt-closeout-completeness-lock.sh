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

if command -v yq >/dev/null 2>&1 && [[ -f "$CONTRACT" ]]; then
  RECEIPT_REGEX="$(yq e -r '.receipt_crumb_detection.untracked_receipt_regex // "'"$RECEIPT_REGEX"'"' "$CONTRACT" 2>/dev/null || echo "$RECEIPT_REGEX")"
  BLOCK_UNTRACKED="$(yq e -r '.receipt_crumb_detection.block_untracked // true' "$CONTRACT" 2>/dev/null || echo "true")"
fi

FINDINGS=0
while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  if [[ "$path" =~ $RECEIPT_REGEX ]]; then
    echo "D274 finding: untracked_receipt=$path" >&2
    FINDINGS=$((FINDINGS + 1))
  fi
done < <(git -C "$ROOT" ls-files --others --exclude-standard)

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

echo "D274 PASS: no untracked receipt crumbs detected"
