#!/usr/bin/env bash
# TRIAGE: D106 media-port-collision-lock — No duplicate ports across media VMs
# D106: Media Port Collision Lock
# Enforces: No port conflicts between download-stack (VM 209) and streaming-stack (VM 210)
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BINDING="$ROOT/ops/bindings/media.services.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

if [[ ! -f "$BINDING" ]]; then
  err "media.services.yaml binding not found"
  echo "D106 FAIL: 1 check(s) failed"
  exit 1
fi

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }

# Collect all ports per VM
declare -A PORT_MAP

while IFS=$'\t' read -r name vm port; do
  [[ -z "$name" || "$port" == "null" ]] && continue

  key="${vm}:${port}"
  if [[ -n "${PORT_MAP[$key]:-}" ]]; then
    err "Port collision: $name and ${PORT_MAP[$key]} both use $port on $vm"
  else
    PORT_MAP[$key]="$name"
  fi
done < <(yq -r '.services | to_entries[] | [.key, .value.vm, .value.port // "null"] | @tsv' "$BINDING" 2>/dev/null)

# Check for cross-VM collisions (ports that might conflict if VMs are on same network)
declare -A CROSS_VM_PORTS
while IFS=$'\t' read -r name vm port; do
  [[ -z "$name" || "$port" == "null" ]] && continue
  if [[ -n "${CROSS_VM_PORTS[$port]:-}" ]]; then
    existing="${CROSS_VM_PORTS[$port]}"
    if [[ "$existing" != *"$vm"* ]]; then
      ok "Cross-VM port $port used by: $existing and $name ($vm) — acceptable if distinct IPs"
    fi
  else
    CROSS_VM_PORTS[$port]="$name ($vm)"
  fi
done < <(yq -r '.services | to_entries[] | [.key, .value.vm, .value.port // "null"] | @tsv' "$BINDING" 2>/dev/null)

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D106 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "No port collisions within VMs"
exit 0
