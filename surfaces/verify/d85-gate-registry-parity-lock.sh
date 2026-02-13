#!/usr/bin/env bash
# TRIAGE: Update ops/bindings/gate.registry.yaml to match gate scripts in surfaces/verify/. Every active gate in drift-gate.sh must have a registry entry.
# D85: Gate registry parity lock
# Ensures gate.registry.yaml covers every gate invoked by drift-gate.sh
# and every registry entry points to an existing script (or is inline/retired).
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"
DRIFT_GATE="$ROOT/surfaces/verify/drift-gate.sh"

fail() { echo "D85 FAIL: $*" >&2; exit 1; }

# Check registry exists
[[ -f "$REGISTRY" ]] || fail "gate.registry.yaml not found"

# Check drift-gate.sh exists
[[ -f "$DRIFT_GATE" ]] || fail "drift-gate.sh not found"

ERRORS=0
err() { echo "  $*" >&2; ERRORS=$((ERRORS + 1)); }

# 1. Extract gate IDs invoked by drift-gate.sh (from echo -n "D<N> " lines)
DRIFT_GATE_IDS="$(grep -oE 'echo -n "D[0-9]+' "$DRIFT_GATE" | grep -oE 'D[0-9]+' | sort -t'D' -k1 -n | sort -u)"

# 2. Extract gate IDs from registry
REGISTRY_IDS="$(yq -r '.gates[].id' "$REGISTRY" | sort -t'D' -k1 -n | sort -u)"

# 3. Check every drift-gate ID is in registry
while IFS= read -r gid; do
  [[ -z "$gid" ]] && continue
  if ! echo "$REGISTRY_IDS" | grep -qx "$gid"; then
    err "Gate $gid invoked by drift-gate.sh but missing from registry"
  fi
done <<< "$DRIFT_GATE_IDS"

# 4. Check every non-retired, non-inline registry entry points to existing script
while IFS=$'\t' read -r gid script is_inline is_retired; do
  [[ -z "$gid" ]] && continue
  [[ "$is_retired" == "true" ]] && continue
  [[ "$is_inline" == "true" ]] && continue
  if [[ -z "$script" || "$script" == "null" ]]; then
    err "Gate $gid has no check_script"
    continue
  fi
  script_path="$ROOT/$script"
  if [[ ! -f "$script_path" ]]; then
    err "Gate $gid references missing script: $script"
  fi
done < <(yq -r '.gates[] | [.id, .check_script // "null", .inline // "false", .retired // "false"] | @tsv' "$REGISTRY")

# 5. Check registry gate_count matches actual gates list
REGISTRY_COUNT="$(yq -r '.gates | length' "$REGISTRY")"
DECLARED_TOTAL="$(yq -r '.gate_count.total' "$REGISTRY")"
if [[ "$REGISTRY_COUNT" != "$DECLARED_TOTAL" ]]; then
  err "gate_count.total ($DECLARED_TOTAL) != actual gates list length ($REGISTRY_COUNT)"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  fail "$ERRORS parity errors found"
fi

echo "D85 PASS: gate registry parity lock enforced ($REGISTRY_COUNT gates, $(echo "$DRIFT_GATE_IDS" | wc -l | tr -d ' ') in drift-gate.sh)"
