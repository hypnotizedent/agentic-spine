#!/usr/bin/env bash
# TRIAGE: Detect runtime VMs not declared in vm.lifecycle authority.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/inventory.enforcement.contract.yaml"
VM_LIFECYCLE="$ROOT/ops/bindings/vm.lifecycle.yaml"

[[ -f "$CONTRACT" ]] || { echo "D294 FAIL: missing contract $CONTRACT" >&2; exit 1; }
[[ -f "$VM_LIFECYCLE" ]] || { echo "D294 FAIL: missing lifecycle file $VM_LIFECYCLE" >&2; exit 1; }

MODE="$(yq e '.proxmox_vm_parity.mode // "report_only"' "$CONTRACT")"
RUNTIME_CMD="$(yq e '.proxmox_vm_parity.runtime_command // "qm list"' "$CONTRACT")"

mapfile -t DECLARED < <(yq e -r '.vms[] | select((.status // "") == "active") | .id' "$VM_LIFECYCLE" | sed '/^null$/d;/^$/d' | sort -u)

if [[ "${#DECLARED[@]}" -eq 0 ]]; then
  echo "D294 FAIL: no declared active VM ids in vm.lifecycle" >&2
  exit 1
fi

if ! command -v qm >/dev/null 2>&1; then
  if [[ "$MODE" == "report_only" ]]; then
    echo "D294 REPORT: runtime observation unavailable (qm command missing); declared_active_vm_count=${#DECLARED[@]}"
    exit 0
  fi
  echo "D294 FAIL: runtime observation unavailable (qm command missing)" >&2
  exit 1
fi

RAW="$(timeout 10s bash -lc "$RUNTIME_CMD" 2>/dev/null || true)"
if [[ -z "$RAW" ]]; then
  if [[ "$MODE" == "report_only" ]]; then
    echo "D294 REPORT: runtime VM list unavailable from '$RUNTIME_CMD'; declared_active_vm_count=${#DECLARED[@]}"
    exit 0
  fi
  echo "D294 FAIL: runtime VM list unavailable from '$RUNTIME_CMD'" >&2
  exit 1
fi

mapfile -t OBSERVED < <(printf '%s\n' "$RAW" | awk 'NR>1 {print $1}' | rg '^[0-9]+$' | sort -u)

if [[ "${#OBSERVED[@]}" -eq 0 ]]; then
  if [[ "$MODE" == "report_only" ]]; then
    echo "D294 REPORT: runtime VM parse produced zero ids; declared_active_vm_count=${#DECLARED[@]}"
    exit 0
  fi
  echo "D294 FAIL: runtime VM parse produced zero ids" >&2
  exit 1
fi

declare -A DECL_SET=()
for id in "${DECLARED[@]}"; do DECL_SET["$id"]=1; done

ROGUE=()
for id in "${OBSERVED[@]}"; do
  if [[ -z "${DECL_SET[$id]:-}" ]]; then
    ROGUE+=("$id")
  fi
done

if [[ "${#ROGUE[@]}" -gt 0 ]]; then
  if [[ "$MODE" == "report_only" ]]; then
    echo "D294 REPORT: rogue runtime VMs not declared in vm.lifecycle: ${ROGUE[*]}"
    exit 0
  fi
  echo "D294 FAIL: rogue runtime VMs not declared in vm.lifecycle: ${ROGUE[*]}" >&2
  exit 1
fi

echo "D294 PASS: runtime VM registry parity holds (declared=${#DECLARED[@]} observed=${#OBSERVED[@]})"
