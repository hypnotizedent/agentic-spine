#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../" && pwd)}"
CONTRACT="$ROOT/ops/bindings/terminal.worker.projection.contract.yaml"
TARGET="$ROOT/ops/bindings/terminal.launcher.view.yaml"
MODE="check"

usage() {
  cat <<'USAGE'
gen-launcher-view.sh

Usage:
  gen-launcher-view.sh [--check] [--apply]

Options:
  --check   Verify the launcher view surface is explicitly retired.
  --apply   No-op retirement shim; reports the retired state.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --apply) MODE="apply"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

fail() { echo "gen-launcher-view FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"

status="$(yq e -r '.generator.status // ""' "$CONTRACT")"
[[ "$status" == "retired" ]] || fail "terminal worker generator is not retired in contract"

if [[ -f "$TARGET" ]]; then
  echo "gen-launcher-view PASS: retired surface remains historically present at ${TARGET#$ROOT/}"
else
  echo "gen-launcher-view PASS: retired surface absent (${MODE})"
fi
