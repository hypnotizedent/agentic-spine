#!/usr/bin/env bash
# TRIAGE: enforce NAS baseline coverage using the real backup.inventory schema.
# D139: NAS baseline coverage present across device registry and backup inventory contracts.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
DEVICE_REG="$ROOT/ops/bindings/home.device.registry.yaml"
BACKUP_INV="$ROOT/ops/bindings/backup.inventory.yaml"

ERRORS=0
err() { echo "  FAIL: $*"; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v yq >/dev/null 2>&1 || { echo "D139 FAIL: missing dependency yq" >&2; exit 1; }

[[ -f "$DEVICE_REG" ]] || err "home.device.registry.yaml missing"
[[ -f "$BACKUP_INV" ]] || err "backup.inventory.yaml missing"

if [[ -f "$DEVICE_REG" ]]; then
  nas_id="$(yq e -r '.devices[] | select(.id == "nas") | .id' "$DEVICE_REG" 2>/dev/null || true)"
  nas_ip="$(yq e -r '.devices[] | select(.id == "nas") | .ip // ""' "$DEVICE_REG" 2>/dev/null || true)"
  nas_role="$(yq e -r '.devices[] | select(.id == "nas") | .role // ""' "$DEVICE_REG" 2>/dev/null || true)"

  [[ "$nas_id" == "nas" ]] || err "device registry missing id=nas"
  [[ -n "$nas_ip" && "$nas_ip" != "null" ]] || err "device registry nas.ip missing"
  [[ -n "$nas_role" && "$nas_role" != "null" ]] || err "device registry nas.role missing"
fi

if [[ -f "$BACKUP_INV" ]]; then
  target_count="$(yq e -r '.targets | length' "$BACKUP_INV" 2>/dev/null || echo 0)"
  [[ "$target_count" =~ ^[0-9]+$ ]] || target_count=0
  [[ "$target_count" -gt 0 ]] || err "backup.inventory has zero targets"

  # Real schema check: file_glob targets must use name/host/base_path/glob.
  schema_missing="$(yq e -r '[.targets[] | select(.kind == "file_glob") | select((.name // "") == "" or (.host // "") == "" or (.base_path // "") == "" or (.glob // "") == "")] | length' "$BACKUP_INV" 2>/dev/null || echo 999)"
  [[ "$schema_missing" == "0" ]] || err "file_glob targets missing required schema fields (name/host/base_path/glob)"

  # Ensure required enabled target host lanes exist for current canonical artifact hosts.
  for host in pve nas; do
    host_count="$(yq e -r "[.targets[] | select(.enabled == true and .host == \"$host\")] | length" "$BACKUP_INV" 2>/dev/null || echo 0)"
    [[ "$host_count" =~ ^[0-9]+$ ]] || host_count=0
    [[ "$host_count" -gt 0 ]] || err "no enabled targets for host lane '$host'"
  done

  # Home hypervisor coverage is modeled as Synology-backed NAS targets plus an explicit
  # proxmox-home machine unit, not enabled target.host=proxmox-home entries.
  home_lane_path="$(yq e -r '.model.destination_lanes.nas-home-local-exception.base_path // ""' "$BACKUP_INV" 2>/dev/null || true)"
  [[ "$home_lane_path" == "/volume1/backups/proxmox_backups/dump" ]] || err "nas-home-local-exception lane missing canonical Synology dump path"
  home_machine_unit="$(yq e -r '.runtime_units[] | select(.unit_id == "machine-proxmox-home") | .unit_id' "$BACKUP_INV" 2>/dev/null || true)"
  [[ "$home_machine_unit" == "machine-proxmox-home" ]] || err "machine-proxmox-home runtime unit missing"
  home_guest_targets="$(yq e -r '[.targets[] | select(.enabled == true and .host == "nas" and (.name == "home-vm-100-ha-primary" or .name == "home-lxc-105-pihole-primary" or .name == "home-vm-106-media-home-primary"))] | length' "$BACKUP_INV" 2>/dev/null || echo 0)"
  [[ "$home_guest_targets" =~ ^[0-9]+$ ]] || home_guest_targets=0
  [[ "$home_guest_targets" -eq 3 ]] || err "home guest Synology targets missing (expected HA VM 100, Pi-hole LXC 105, media-home VM 106)"

  # NAS lane must include /volume1 destinations.
  nas_volume_targets="$(yq e -r '[.targets[] | select(.enabled == true and .host == "nas" and (.base_path | test("^/volume1/")))] | length' "$BACKUP_INV" 2>/dev/null || echo 0)"
  [[ "$nas_volume_targets" =~ ^[0-9]+$ ]] || nas_volume_targets=0
  [[ "$nas_volume_targets" -gt 0 ]] || err "enabled NAS targets do not use /volume1 backup lane"

  # Legacy NAS offsite VM lane must remain explicitly disabled after md1400 canonicalization.
  offsite_target_state="$(yq e -r '.targets[] | select(.name == "vm-offsite-critical") | (.enabled | tostring)' "$BACKUP_INV" 2>/dev/null || true)"
  [[ "$offsite_target_state" == "false" ]] || err "vm-offsite-critical must remain present as an explicit disabled legacy target"

  # Media config-state targets are required in systemic model.
  media_cfg_count="$(yq e -r '[.targets[] | select(.enabled == true and (.name == "app-media-config-download-stack" or .name == "app-media-config-streaming-stack"))] | length' "$BACKUP_INV" 2>/dev/null || echo 0)"
  [[ "$media_cfg_count" =~ ^[0-9]+$ ]] || media_cfg_count=0
  [[ "$media_cfg_count" -eq 2 ]] || err "media config-state targets missing (expected app-media-config-download-stack + app-media-config-streaming-stack)"

  # Runtime unit model must be present and include machine/vm/container-fleet classes.
  runtime_units="$(yq e -r '.runtime_units | length' "$BACKUP_INV" 2>/dev/null || echo 0)"
  machine_units="$(yq e -r '[.runtime_units[] | select(.kind == "machine")] | length' "$BACKUP_INV" 2>/dev/null || echo 0)"
  vm_units="$(yq e -r '[.runtime_units[] | select(.kind == "vm")] | length' "$BACKUP_INV" 2>/dev/null || echo 0)"
  fleet_units="$(yq e -r '[.runtime_units[] | select(.kind == "container-fleet")] | length' "$BACKUP_INV" 2>/dev/null || echo 0)"
  [[ "$runtime_units" =~ ^[0-9]+$ ]] || runtime_units=0
  [[ "$runtime_units" -gt 0 ]] || err "runtime_units model missing from backup inventory"
  [[ "$machine_units" =~ ^[0-9]+$ && "$machine_units" -gt 0 ]] || err "runtime_units missing machine class coverage"
  [[ "$vm_units" =~ ^[0-9]+$ && "$vm_units" -gt 0 ]] || err "runtime_units missing vm class coverage"
  [[ "$fleet_units" =~ ^[0-9]+$ && "$fleet_units" -gt 0 ]] || err "runtime_units missing container-fleet class coverage"

  ok "targets=$target_count nas_volume_targets=$nas_volume_targets home_guest_targets=$home_guest_targets offsite_target_state=$offsite_target_state runtime_units=$runtime_units"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D139 FAIL: $ERRORS coverage gap(s) found"
  exit 1
fi

echo "D139 PASS: NAS baseline coverage and backup model invariants valid"
exit 0
