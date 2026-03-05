#!/usr/bin/env bash
# TRIAGE: enforce generated entry-surface gate metadata projection from gate.registry.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
GEN="$ROOT/bin/generators/gen-entry-surface-gate-metadata.sh"
CONTRACT="$ROOT/ops/bindings/entry.surface.gate.metadata.contract.yaml"

fail() {
  echo "D285 FAIL: $*" >&2
  exit 1
}

[[ -x "$GEN" ]] || fail "missing generator: $GEN"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"

"$GEN" --check

echo "D285 PASS: entry-surface gate metadata no-manual-drift lock enforced"
