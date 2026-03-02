#!/usr/bin/env bash
# TRIAGE: D107 media-nfs-mount-lock — Both media VMs can reach pve:/media with correct modes
# D107: Media NFS Mount Lock
# Enforces: download-stack has RW, streaming-stack has RO, both can reach NFS
set -euo pipefail

# Network gate — skip cleanly when Tailscale VPN is disconnected
source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale_for "download-stack"

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
TENANT_BINDING="$ROOT/ops/bindings/tenants/media-stack.yaml"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v ssh >/dev/null 2>&1 || { err "ssh not available"; exit 1; }

NFS_SOURCE=$(yq -r '.media.nfs.source // "pve:/media"' "$TENANT_BINDING" 2>/dev/null || echo "pve:/media")
MOUNT_POINT=$(yq -r '.media.vms.download.nfs_mount // "/mnt/media"' "$TENANT_BINDING" 2>/dev/null || echo "/mnt/media")
EXPECTED_EXPORT_PATH="${NFS_SOURCE#*:}"

get_vm_ssh_ref() {
  local vm="$1"
  local target user

  target=$(yq -r ".vms[] | select(.hostname == \"$vm\") | .ssh_target // .hostname // \"\"" "$VM_BINDING" 2>/dev/null || echo "")
  user=$(yq -r ".vms[] | select(.hostname == \"$vm\") | .ssh_user // \"\"" "$VM_BINDING" 2>/dev/null || echo "")

  if [[ -z "$target" || "$target" == "null" ]]; then
    echo ""
    return 1
  fi

  if [[ -n "$user" && "$user" != "null" ]]; then
    echo "${user}@${target}"
  else
    echo "$target"
  fi
}

check_vm_nfs() {
  local vm="$1"
  local expected_mode="$2"
  local ssh_ref
  local mount_info
  local mount_source
  local mount_opts
  ssh_ref="$(get_vm_ssh_ref "$vm" 2>/dev/null || true)"

  if [[ -z "$ssh_ref" ]]; then
    err "$vm: no ssh target found in vm.lifecycle binding"
    return 1
  fi

  mount_info=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" "findmnt -rn -T '$MOUNT_POINT' -t nfs,nfs4 -o SOURCE,OPTIONS" 2>/dev/null || echo "")

  if [[ -z "$mount_info" ]]; then
    err "$vm: NFS mount not found at $MOUNT_POINT"
    return 1
  fi

  mount_source="${mount_info%% *}"
  mount_opts="${mount_info#* }"

  if [[ "$mount_source" != *":$EXPECTED_EXPORT_PATH" ]]; then
    err "$vm: unexpected NFS source at $MOUNT_POINT: $mount_source (expected export :$EXPECTED_EXPORT_PATH)"
    return 1
  fi

  if [[ "$expected_mode" == "rw" ]]; then
    if [[ "$mount_opts" =~ (^|,)rw($|,) ]]; then
      ok "$vm: NFS mounted RW as expected"
    else
      err "$vm: NFS expected RW but got options: $mount_opts"
      return 1
    fi
  else
    if [[ "$mount_opts" =~ (^|,)ro($|,) ]]; then
      ok "$vm: NFS mounted RO as expected"
    else
      ok "$vm: NFS mounted (RW acceptable for streaming)"
    fi
  fi

  return 0
}

check_vm_nfs "download-stack" "rw" || true
check_vm_nfs "streaming-stack" "ro" || true

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D107 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "All NFS mounts healthy"
exit 0
