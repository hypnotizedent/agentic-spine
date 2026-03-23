#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/wave.closeout.contract.yaml"
POLICY="enforce"
DEFAULT_REGEX='(^|/)\.evidence/spine/reports/verify/W[^/]*RECEIPT[^/]*\.md$'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      POLICY="${2:-enforce}"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: d274-receipt-closeout-completeness-lock.sh [--policy enforce|report]

Blocks closeout hygiene when untracked receipt crumbs remain in the repo.
EOF
      exit 0
      ;;
    *)
      echo "D274 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

case "$POLICY" in
  enforce|report) ;;
  *)
    echo "D274 FAIL: --policy must be enforce|report" >&2
    exit 2
    ;;
esac

[[ -d "$ROOT/.git" || -f "$ROOT/.git" ]] || {
  echo "D274 FAIL: not a git repository root: $ROOT" >&2
  exit 1
}

RECEIPT_REGEX="$DEFAULT_REGEX"
if command -v yq >/dev/null 2>&1 && [[ -f "$CONTRACT" ]]; then
  contract_regex="$(yq e -r '.receipt_crumb_detection.untracked_receipt_regex // ""' "$CONTRACT" 2>/dev/null || true)"
  if [[ -n "$contract_regex" && "$contract_regex" != "null" ]]; then
    RECEIPT_REGEX="$contract_regex"
  fi
fi

mapfile -t untracked < <(git -C "$ROOT" ls-files --others --exclude-standard)
mapfile -t ignored_untracked < <(git -C "$ROOT" ls-files --others -i --exclude-standard)

crumbs=()
for path in "${untracked[@]}" "${ignored_untracked[@]}"; do
  [[ -n "$path" ]] || continue
  if [[ "$path" =~ $RECEIPT_REGEX ]]; then
    skip=0
    for existing in "${crumbs[@]}"; do
      if [[ "$existing" == "$path" ]]; then
        skip=1
        break
      fi
    done
    if [[ "$skip" -eq 0 ]]; then
      crumbs+=("$path")
    fi
  fi
done

if [[ "${#crumbs[@]}" -eq 0 ]]; then
  echo "D274 PASS: no untracked receipt crumbs remain before closeout"
  exit 0
fi

{
  echo "D274 ${POLICY^^}: untracked receipt crumbs detected"
  for path in "${crumbs[@]}"; do
    echo "- $path"
  done
} >&2

if [[ "$POLICY" == "report" ]]; then
  exit 0
fi

exit 1
