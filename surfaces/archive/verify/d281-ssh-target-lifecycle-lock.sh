#!/usr/bin/env bash
# TRIAGE: block use of decommissioned SSH targets in active/runtime surfaces.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/ssh.target.lifecycle.contract.yaml"

fail() {
  echo "D281 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"

mapfile -t dead_targets < <(yq e -r '.decommissioned_targets[]' "$CONTRACT" | sed '/^$/d')
mapfile -t surfaces < <(yq e -r '.active_reference_surfaces[]' "$CONTRACT" | sed '/^$/d')

errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

for rel in "${surfaces[@]}"; do
  [[ -f "$ROOT/$rel" ]] || err "missing active reference surface: $rel"
done

  for target in "${dead_targets[@]}"; do
  for rel in "${surfaces[@]}"; do
    [[ -f "$ROOT/$rel" ]] || continue
    if rg -n "(^|[^A-Za-z0-9_-])$target([^A-Za-z0-9_-]|$)" "$ROOT/$rel" | rg -v '^[0-9]+:[[:space:]]*#' >/dev/null 2>&1; then
      err "decommissioned target '$target' referenced in $rel"
    fi
  done
done

if [[ "$errors" -gt 0 ]]; then
  fail "$errors violation(s)"
fi

echo "D281 PASS: ssh target lifecycle lock enforced"
