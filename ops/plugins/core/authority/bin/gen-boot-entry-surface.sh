#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../" && pwd)}"
CONTRACT="$ROOT/ops/bindings/entry.boot.surface.contract.yaml"
MODE="write"
LOCK_HELD=0
TMP_RENDERED=""

source "$ROOT/ops/lib/git-lock.sh"
source "$ROOT/ops/lib/governed-write-transaction.sh"

usage() {
  cat <<'USAGE'
gen-boot-entry-surface.sh

Usage:
  gen-boot-entry-surface.sh [--check]

Options:
  --check          Exit non-zero if the generated boot entry surface drifts.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

fail() { echo "gen-boot-entry-surface FAIL: $*" >&2; exit 1; }

cleanup() {
  if [[ "$LOCK_HELD" -eq 1 ]]; then
    release_git_lock || true
  fi
  spine_tx_cleanup
  rm -f "${TMP_RENDERED:-}"
  return 0
}

trap cleanup EXIT INT TERM

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"

GEN_REL="$(yq e -r '.generated_file' "$CONTRACT")"
[[ -n "$GEN_REL" && "$GEN_REL" != "null" ]] || fail "contract missing generated_file"
GEN_FILE="$ROOT/$GEN_REL"

TMP_RENDERED="$(mktemp)"
python3 - "$CONTRACT" >"$TMP_RENDERED" <<'PY'
from pathlib import Path
import sys
import yaml

contract = yaml.safe_load(Path(sys.argv[1]).read_text(encoding="utf-8")) or {}
generated_from = "ops/bindings/entry.boot.surface.contract.yaml"
updated = str(contract.get("updated") or "")
surfaces = contract.get("surfaces") or []
injection = contract.get("injection_surfaces") or {}

lines = [
    "# BOOT ENTRY SURFACE (generated)",
    "authority_state: projection",
    f"projection_of: {generated_from}",
    f"source_contract: {generated_from}",
    f"contract_updated: {updated}",
    "",
    "## Boot Model",
    "",
    f"- mode: {contract.get('boot_model', 'unknown')}",
    "",
    "## Injection Surfaces",
    "",
]

for tool, spec in injection.items():
    if not isinstance(spec, dict):
        continue
    lines.append(f"- {tool}")
    lines.append(f"  - mechanism: {spec.get('mechanism', 'unknown')}")
    lines.append(f"  - path: {spec.get('path', '')}")
    trigger = str(spec.get("trigger") or "").strip()
    if trigger:
        lines.append(f"  - trigger: {trigger}")

lines.extend([
    "",
    "## Pointer-Only Entry Surfaces",
    "",
])
for surface in surfaces:
    lines.append(f"- {surface}")

print("\n".join(lines).rstrip() + "\n")
PY

mkdir -p "$(dirname "$GEN_FILE")"
if [[ "$MODE" == "check" ]]; then
  [[ -f "$GEN_FILE" ]] || fail "generated file missing: $GEN_FILE"
  diff -u "$GEN_FILE" "$TMP_RENDERED" >/dev/null 2>&1 || fail "generated boot entry surface drift: $GEN_REL"
  echo "gen-boot-entry-surface PASS: $GEN_REL"
  exit 0
fi

if [[ "${SPINE_GIT_LOCK_HELD:-0}" != "1" ]]; then
  acquire_git_lock entry_boot_projection || exit 1
  LOCK_HELD=1
  export SPINE_GIT_LOCK_HELD=1
fi

spine_tx_init
spine_tx_track "$GEN_FILE"
cp "$TMP_RENDERED" "$GEN_FILE"
echo "gen-boot-entry-surface PASS: $GEN_REL"
