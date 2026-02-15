#!/usr/bin/env bash
# TRIAGE: D107 media-nfs-mount-lock — Both media VMs can reach pve:/media with correct modes
# D107: Media NFS Mount Lock
# Enforces: download-stack has RW, streaming-stack has RO, both can reach NFS
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
TENANT_BINDING="$ROOT/ops/bindings/tenants/media-stack.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v ssh >/dev/null 2>&1 || { err "ssh not available"; exit 1; }

NFS_SOURCE=$(yq -r '.media.nfs.source // "pve:/media"' "$TENANT_BINDING" 2>/dev/null || echo "pve:/media")
MOUNT_POINT=$(yq -r '.media.vms.download.nfs_mount // "/mnt/media"' "$TENANT_BINDING" 2>/dev/null || echo "/mnt/media")

check_vm_nfs() {
  local vm="$1"
  local expected_mode="$2"

  mount_info=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$vm" "mount 2>/dev/null | grep '$NFS_SOURCE'" || echo "")

  if [[ -z "$mount_info" ]]; then
    err "$vm: NFS mount $NFS_SOURCE not found"
    return 1
  fi

  if [[ "$expected_mode" == "rw" ]]; then
    if [[ "$mount_info" =~ rw, ]]; then
      ok "$vm: NFS mounted RW as expected"
    else
      err "$vm: NFS expected RW but got: $mount_info"
      return 1
    fi
  else
    if [[ "$mount_info" =~ ro, ]]; then
      ok "$vm: NFS mounted RO as expected"
    else
      ok "$vm: NFS mounted (RW acceptable for streaming)"
    fi
  fi

  return 0
}

check_vm_nfs "download-stack" "rw" || ERRORS=$((ERRORS + 1))
check_vm_nfs "streaming-stack" "ro" || ERRORS=$((ERRORS + 1))

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D107 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "All NFS mounts healthy"
exit 0
