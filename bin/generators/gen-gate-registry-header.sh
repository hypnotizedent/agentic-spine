#!/usr/bin/env bash
set -euo pipefail

# Reconcile gate.registry.yaml header metadata (gate_count + description)
# from actual .gates[] entries.
#
# Usage:
#   gen-gate-registry-header.sh           # rewrite header in place
#   gen-gate-registry-header.sh --check   # verify drift, exit 1 if stale

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"
MODE="write"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --) shift ;;
    --check) MODE="check"; shift ;;
    -h|--help)
      echo "Usage: gen-gate-registry-header.sh [--check]"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

fail() { echo "gen-gate-registry-header FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
[[ -f "$REGISTRY" ]] || fail "missing registry: $REGISTRY"

# ── compute actual counts ──
total="$(yq e '.gates | length' "$REGISTRY")"
active="$(yq e '[.gates[] | select(.retired != true)] | length' "$REGISTRY")"
retired="$(( total - active ))"
max_gate="$(yq e '.gates[].id' "$REGISTRY" | sed 's/^D//' | sort -n | tail -1)"
[[ -n "$max_gate" ]] || max_gate=0

# ── read current header values ──
cur_total="$(yq e '.gate_count.total // 0' "$REGISTRY")"
cur_active="$(yq e '.gate_count.active // 0' "$REGISTRY")"
cur_retired="$(yq e '.gate_count.retired // 0' "$REGISTRY")"

# ── build description gate-name suffix ──
# Extract the max gate from the current description for comparison
cur_desc_max="$(yq e -r '.description // ""' "$REGISTRY" | sed -n 's/.*D1-D\([0-9]*\).*/\1/p')"
[[ -n "$cur_desc_max" ]] || cur_desc_max=0

drift=0
reasons=()

if [[ "$total" -ne "$cur_total" ]]; then
  drift=1
  reasons+=("gate_count.total: $cur_total -> $total")
fi
if [[ "$active" -ne "$cur_active" ]]; then
  drift=1
  reasons+=("gate_count.active: $cur_active -> $active")
fi
if [[ "$retired" -ne "$cur_retired" ]]; then
  drift=1
  reasons+=("gate_count.retired: $cur_retired -> $retired")
fi
if [[ "$max_gate" -ne "${cur_desc_max:-0}" ]]; then
  drift=1
  reasons+=("description max gate: D${cur_desc_max:-0} -> D${max_gate}")
fi

if [[ "$MODE" == "check" ]]; then
  if [[ "$drift" -eq 1 ]]; then
    for r in "${reasons[@]}"; do
      echo "  drift: $r" >&2
    done
    fail "gate registry header stale (run gen-gate-registry-header.sh to fix)"
  fi
  echo "gen-gate-registry-header PASS: header in sync (total=$total active=$active retired=$retired max=D$max_gate)"
  exit 0
fi

# ── write mode: update header in place ──
if [[ "$drift" -eq 0 ]]; then
  echo "gen-gate-registry-header PASS: header already in sync (total=$total active=$active retired=$retired max=D$max_gate)"
  exit 0
fi

# Update gate_count fields
yq e -i ".gate_count.total = $total" "$REGISTRY"
yq e -i ".gate_count.active = $active" "$REGISTRY"
yq e -i ".gate_count.retired = $retired" "$REGISTRY"

# Update the description D1-DXXX range
cur_desc="$(yq e -r '.description' "$REGISTRY")"
new_desc="$(echo "$cur_desc" | sed "s/D1-D[0-9]*/D1-D${max_gate}/")"
if [[ "$cur_desc" != "$new_desc" ]]; then
  yq e -i ".description = \"$(printf '%s' "$new_desc" | sed 's/"/\\"/g')\"" "$REGISTRY"
fi

echo "gen-gate-registry-header PASS: header updated (total=$total active=$active retired=$retired max=D$max_gate)"
for r in "${reasons[@]}"; do
  echo "  fixed: $r"
done
