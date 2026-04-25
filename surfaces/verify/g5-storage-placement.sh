#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CHECKS=(
  "mail-archiver-nonboot|$ROOT/surfaces/verify/d233-communications-mail-archiver-nonboot-storage-lock.sh"
  "storage-placement|$ROOT/surfaces/verify/d235-infra-storage-placement-lock.sh --policy enforce"
  "content-family-placement|$ROOT/surfaces/verify/d420-content-family-placement-lock.sh"
)

failures=0

for entry in "${CHECKS[@]}"; do
  name="${entry%%|*}"
  command_string="${entry#*|}"
  script="${command_string%% *}"

  echo "==> $name"
  if [[ ! -x "$script" ]]; then
    echo "G5 FAIL: missing helper gate: $script" >&2
    failures=$((failures + 1))
    echo
    continue
  fi

  set +e
  if [[ "$name" == "storage-placement" ]]; then
    "$BASH" "$script" --policy enforce
  else
    "$BASH" "$script"
  fi
  rc=$?
  set -e
  echo

  if [[ "$rc" -ne 0 ]]; then
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -gt 0 ]]; then
  echo "G5 FAIL: storage placement checks failed=$failures" >&2
  exit 1
fi

echo "G5 PASS: storage placement checks passed"
