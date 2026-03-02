#!/usr/bin/env bash
# TRIAGE: New VMs need entries in SSH config, SERVICE_REGISTRY, backup, and health checks.
# D69: VM creation governance lock
# Enforces cross-file parity for every active VM in vm.lifecycle.yaml.
# Each active shop VM must have matching entries in ssh.targets.yaml,
# SERVICE_REGISTRY.yaml hosts, backup.inventory.yaml, and
# services.health.yaml (or an explicit health_exemption).
# Also checks: no PENDING_* placeholders, vmid/host parity across files.
#
# Scope: shop-site VMs only (home VMs are out of scope per
# LOOP-HOME-SERVICE-REGISTRY-SCOPE-DECISION-20260210).
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

LIFECYCLE="$SP/ops/bindings/vm.lifecycle.yaml"
SSH_TARGETS="$SP/ops/bindings/ssh.targets.yaml"
SERVICE_REG="$SP/docs/governance/SERVICE_REGISTRY.yaml"
BACKUP_INV="$SP/ops/bindings/backup.inventory.yaml"
HEALTH_BIND="$SP/ops/bindings/services.health.yaml"
STACK_REG="$SP/docs/governance/STACK_REGISTRY.yaml"

FAIL=0
err() { echo "  D69 FAIL: $1" >&2; FAIL=1; }
warn() { echo "  D69 WARN: $1" >&2; }

# ── Preconditions ────────────────────────────────────────────────────────────
command -v yq >/dev/null 2>&1 || { err "yq not found"; exit 1; }
for f in "$LIFECYCLE" "$SSH_TARGETS" "$SERVICE_REG" "$BACKUP_INV" "$HEALTH_BIND" "$STACK_REG"; do
  [[ -f "$f" ]] || { err "missing: $f"; exit 1; }
done

# ── Extract active shop VMs ─────────────────────────────────────────────────
# Active VMs on shop hypervisor (pve), excluding home-site, templates, decommissioned
vm_count=$(yq '.vms | length' "$LIFECYCLE")

for ((i=0; i<vm_count; i++)); do
  status=$(yq -r ".vms[$i].status" "$LIFECYCLE")
  hypervisor=$(yq -r ".vms[$i].proxmox_host" "$LIFECYCLE")
  site_scope=$(yq -r ".vms[$i].site_scope // \"shop\"" "$LIFECYCLE")
  vmid=$(yq -r ".vms[$i] | (.id // .vmid)" "$LIFECYCLE")
  hostname=$(yq -r ".vms[$i].hostname" "$LIFECYCLE")
  ts_ip=$(yq -r ".vms[$i].tailscale_ip // \"\"" "$LIFECYCLE")
  lan_ip=$(yq -r ".vms[$i].lan_ip // \"\"" "$LIFECYCLE")

  # Skip non-active, non-shop, templates
  [[ "$status" == "active" ]] || continue
  [[ "$site_scope" == "home" ]] && continue
  [[ "$hypervisor" != "pve" ]] && continue

  # ── Check 1: PENDING_* placeholder check ───────────────────────────────
  if [[ "$hostname" == PENDING_* ]] || [[ "$ts_ip" == PENDING_* ]]; then
    err "VM $vmid ($hostname): has PENDING_* placeholder in lifecycle binding"
  fi

  # ── Check 2: ssh.targets.yaml entry ────────────────────────────────────
  ssh_match=$(yq -r ".ssh.targets[] | select(.id == \"$hostname\") | .id" "$SSH_TARGETS")
  if [[ -z "$ssh_match" || "$ssh_match" == "null" ]]; then
    err "VM $vmid ($hostname): missing from ssh.targets.yaml"
  else
    ssh_ip=$(yq -r ".ssh.targets[] | select(.id == \"$hostname\") | .host" "$SSH_TARGETS")
    ssh_ts_ip=$(yq -r ".ssh.targets[] | select(.id == \"$hostname\") | .tailscale_ip // \"\"" "$SSH_TARGETS")
    # LAN-first: ssh.targets.host should match vm.lifecycle.lan_ip
    if [[ -n "$lan_ip" && "$lan_ip" != "null" && "$ssh_ip" != "null" ]]; then
      if [[ "$ssh_ip" != "$lan_ip" ]]; then
        err "VM $vmid ($hostname): LAN IP mismatch — lifecycle=$lan_ip, ssh.targets=$ssh_ip"
      fi
    fi
    # Tailscale IP parity: ssh.targets.tailscale_ip should match vm.lifecycle.tailscale_ip
    if [[ -n "$ts_ip" && -n "$ssh_ts_ip" && "$ssh_ts_ip" != "null" ]]; then
      if [[ "$ssh_ts_ip" != "$ts_ip" ]]; then
        err "VM $vmid ($hostname): Tailscale IP mismatch — lifecycle=$ts_ip, ssh.targets.tailscale_ip=$ssh_ts_ip"
      fi
    fi
  fi

  # ── Check 3: SERVICE_REGISTRY.yaml hosts entry ────────────────────────
  svc_match=$(yq -r ".hosts.\"$hostname\" // \"\"" "$SERVICE_REG")
  if [[ -z "$svc_match" ]]; then
    err "VM $vmid ($hostname): missing from SERVICE_REGISTRY.yaml hosts"
  else
    # Verify Tailscale IP parity
    if [[ -n "$ts_ip" ]]; then
      svc_ip=$(yq -r ".hosts.\"$hostname\".tailscale_ip // \"\"" "$SERVICE_REG")
      if [[ -n "$svc_ip" && "$svc_ip" != "$ts_ip" ]]; then
        err "VM $vmid ($hostname): Tailscale IP mismatch — lifecycle=$ts_ip, SERVICE_REGISTRY=$svc_ip"
      fi
    fi
    # Verify vmid parity
    svc_vmid=$(yq -r ".hosts.\"$hostname\".vmid // \"\"" "$SERVICE_REG")
    if [[ -n "$svc_vmid" && "$svc_vmid" != "null" && "$svc_vmid" != "$vmid" ]]; then
      err "VM $vmid ($hostname): vmid mismatch — lifecycle=$vmid, SERVICE_REGISTRY=$svc_vmid"
    fi
  fi

  # ── Check 4: backup.inventory.yaml vzdump target ──────────────────────
  backup_match=$(yq -r ".targets[] | select(.glob == \"vzdump-qemu-${vmid}-*.vma.zst\") | .name" "$BACKUP_INV")
  if [[ -z "$backup_match" || "$backup_match" == "null" ]]; then
    err "VM $vmid ($hostname): no vzdump target in backup.inventory.yaml matching vmid $vmid"
  fi

  # ── Check 4b: systemic backup model metadata ──────────────────────────
  model_match="$(yq -r "[.runtime_units[]? | select(.kind == \"vm\" and .hostname == \"$hostname\" and (.backup_profile // \"\") != \"\" and (.data_class // \"\") != \"\" and (.destination_lane // \"\") != \"\" and (.schedule_class // \"\") != \"\" and (.restore_class // \"\") != \"\")] | length" "$BACKUP_INV" 2>/dev/null || echo 0)"
  [[ "$model_match" =~ ^[0-9]+$ ]] || model_match=0
  if [[ "$model_match" -eq 0 ]]; then
    err "VM $vmid ($hostname): missing runtime_units backup metadata (backup_profile/data_class/destination_lane/schedule_class/restore_class)"
  fi

  if [[ "$hostname" == "download-stack" || "$hostname" == "streaming-stack" ]]; then
    media_exclusions="$(yq -r ".runtime_units[]? | select(.kind == \"vm\" and .hostname == \"$hostname\") | (.exclude_paths // [])[]?" "$BACKUP_INV" 2>/dev/null || true)"
    if ! printf '%s\n' "$media_exclusions" | grep -Eq '^/mnt/media(/.*)?$'; then
      err "VM $vmid ($hostname): media runtime unit missing /mnt/media exclusion"
    fi
  fi

  # ── Check 5: services.health.yaml coverage ────────────────────────────
  # At least one enabled probe must reference this hostname, OR the VM
  # must have has_docker: false (no services to probe).
  has_docker=$(yq -r ".vms[$i].has_docker // true" "$LIFECYCLE")
  if [[ "$has_docker" == "true" ]]; then
    health_count=$(yq -r "[.endpoints[] | select(.host == \"$hostname\")] | length" "$HEALTH_BIND")
    if [[ "$health_count" -eq 0 || "$health_count" == "null" ]]; then
      err "VM $vmid ($hostname): zero health probe entries in services.health.yaml"
    fi
  fi

  # ── Check 6: STACK_REGISTRY.yaml coverage (docker hosts only) ─────────
  if [[ "$has_docker" == "true" ]]; then
    # Check for at least one stack targeting this VM (by path containing vmid or hostname)
    stack_match=$(yq -r ".stacks[] | select(.path == \"proxmox:vm-${vmid}\" or .deploy_target == \"proxmox:vm-${vmid}\") | .stack_id" "$STACK_REG")
    # Also check docker-host by name (it uses repo paths, not proxmox: prefix)
    if [[ -z "$stack_match" || "$stack_match" == "null" ]]; then
      stack_match=$(yq -r ".stacks[] | select(.name | test(\"$hostname\"; \"i\")) | .stack_id" "$STACK_REG" 2>/dev/null || true)
    fi
    if [[ -z "$stack_match" || "$stack_match" == "null" ]]; then
      warn "VM $vmid ($hostname): no STACK_REGISTRY entry found (non-fatal; some VMs use inline compose)"
    fi
  fi
done

# ── Check 7: Orphan detection — downstream entries without lifecycle entry ──
# Check ssh.targets for shop hosts not in lifecycle
ssh_ids=$(yq -r '.ssh.targets[] | select(.access_method != "lan_only") | .id' "$SSH_TARGETS")
lifecycle_hostnames=$(yq -r '.vms[].hostname' "$LIFECYCLE")

for ssh_id in $ssh_ids; do
  # Skip known non-VM targets
  case "$ssh_id" in
    pve|proxmox-home|nas|vault|ha|pihole-home|download-home) continue ;;
  esac
  if ! echo "$lifecycle_hostnames" | grep -qx "$ssh_id"; then
    err "Orphan: $ssh_id in ssh.targets.yaml but missing from vm.lifecycle.yaml"
  fi
done

if [[ "$FAIL" -eq 1 ]]; then
  echo "D69 FAIL: VM creation governance violations detected" >&2
  exit 1
fi
echo "D69 PASS: VM creation governance valid ($vm_count VMs checked)"
exit 0
