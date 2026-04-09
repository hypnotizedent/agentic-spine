#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../" && pwd)}"
CONTRACT="$ROOT/ops/bindings/terminal.worker.projection.contract.yaml"
TARGET="$ROOT/docs/reference/generated/worker-usage"
MODE="check"

usage() {
  cat <<'USAGE'
gen-worker-usage-docs.sh

Usage:
  gen-worker-usage-docs.sh [--check] [--apply]

Options:
  --check   Verify worker usage generation is explicitly retired.
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

fail() { echo "gen-worker-usage-docs FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"

status="$(yq e -r '.generator.status // ""' "$CONTRACT")"
[[ "$status" == "retired" ]] || fail "terminal worker generator is not retired in contract"

if [[ -d "$TARGET" ]]; then
  echo "gen-worker-usage-docs PASS: retired surface left as historical docs at ${TARGET#$ROOT/}"
else
  echo "gen-worker-usage-docs PASS: retired surface absent (${MODE})"
fi
