#!/usr/bin/env bash
# TRIAGE: Preserve legacy mint data services as explicit LEGACY_DATA_ICE hold state.
# D244: mint-legacy-data-ice-lock
# Report/enforce VM200 legacy-data service classification and non-authority constraints.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
POLICY="$ROOT/ops/bindings/mint.legacy.ice.policy.yaml"
VM_LIFECYCLE="$ROOT/ops/bindings/vm.lifecycle.yaml"
BACKUP_INVENTORY="$ROOT/ops/bindings/backup.inventory.yaml"
PROBE_BINDING="$ROOT/ops/bindings/mint.probe.targets.yaml"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d244-mint-legacy-data-ice-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D244 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$POLICY" ]] || { echo "D244 FAIL: missing $POLICY" >&2; exit 1; }
[[ -f "$VM_LIFECYCLE" ]] || { echo "D244 FAIL: missing $VM_LIFECYCLE" >&2; exit 1; }
[[ -f "$BACKUP_INVENTORY" ]] || { echo "D244 FAIL: missing $BACKUP_INVENTORY" >&2; exit 1; }
[[ -f "$PROBE_BINDING" ]] || { echo "D244 FAIL: missing $PROBE_BINDING" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "D244 FAIL: yq missing" >&2; exit 1; }

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$POLICY" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D244 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

FINDINGS=0
finding() {
  local severity="$1"
  shift
  echo "  ${severity}: $*"
  FINDINGS=$((FINDINGS + 1))
}

vmid="$(yq -r '.legacy_data_ice_contract.vm_lifecycle_id // 200' "$POLICY" 2>/dev/null || echo 200)"
vm_role_expected="$(yq -r '.legacy_data_ice_contract.required_vm_role // "legacy-production"' "$POLICY" 2>/dev/null || echo legacy-production)"
vm_status_expected="$(yq -r '.legacy_data_ice_contract.required_vm_status // "active"' "$POLICY" 2>/dev/null || echo active)"

vm_host="$(yq -r ".vms[] | select(.id == $vmid) | .hostname // \"\"" "$VM_LIFECYCLE" 2>/dev/null || true)"
vm_role_actual="$(yq -r ".vms[] | select(.id == $vmid) | .role // \"\"" "$VM_LIFECYCLE" 2>/dev/null || true)"
vm_status_actual="$(yq -r ".vms[] | select(.id == $vmid) | .status // \"\"" "$VM_LIFECYCLE" 2>/dev/null || true)"

[[ -n "$vm_host" ]] || finding "HIGH" "vm.lifecycle missing VM id $vmid for legacy data ice"
[[ "$vm_role_actual" == "$vm_role_expected" ]] || finding "HIGH" "VM$vmid role drift: expected '$vm_role_expected' got '$vm_role_actual'"
[[ "$vm_status_actual" == "$vm_status_expected" ]] || finding "MEDIUM" "VM$vmid status drift: expected '$vm_status_expected' got '$vm_status_actual'"

while IFS= read -r required_service; do
  [[ -z "$required_service" ]] && continue
  has_service="$(yq -r ".vms[] | select(.id == $vmid) | .services[]? | select(. == \"$required_service\")" "$VM_LIFECYCLE" 2>/dev/null || true)"
  [[ -n "$has_service" ]] || finding "HIGH" "VM$vmid missing required legacy data service '$required_service'"
done < <(yq -r '.legacy_data_ice_contract.required_services[]' "$POLICY" 2>/dev/null || true)

while IFS= read -r backup_target; do
  [[ -z "$backup_target" ]] && continue
  has_backup="$(yq -r ".targets[]? | select(.name == \"$backup_target\") | .name" "$BACKUP_INVENTORY" 2>/dev/null || true)"
  [[ -n "$has_backup" ]] || finding "MEDIUM" "backup.inventory missing required target '$backup_target' for legacy data ice"
done < <(yq -r '.legacy_data_ice_contract.required_backup_targets[]' "$POLICY" 2>/dev/null || true)

app_target="$(yq -r '.targets.app_plane.ssh_target // ""' "$PROBE_BINDING" 2>/dev/null || true)"
data_target="$(yq -r '.targets.data_plane.ssh_target // ""' "$PROBE_BINDING" 2>/dev/null || true)"
if [[ "$app_target" == "$vm_host" || "$data_target" == "$vm_host" ]]; then
  finding "HIGH" "mint probe authority points to legacy host '$vm_host'"
fi

if [[ "$FINDINGS" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D244 FAIL: legacy data ice findings=$FINDINGS"
    exit 1
  fi
  echo "D244 REPORT: legacy data ice findings=$FINDINGS"
  exit 0
fi

echo "D244 PASS: legacy data services preserved as hold-state ice and not runtime authority"
exit 0
