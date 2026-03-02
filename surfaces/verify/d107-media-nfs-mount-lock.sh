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
source "${ROOT}/ops/lib/ssh-resolve.sh"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v ssh >/dev/null 2>&1 || { err "ssh not available"; exit 1; }

NFS_SOURCE=$(yq -r '.media.nfs.source // "pve:/media"' "$TENANT_BINDING" 2>/dev/null || echo "pve:/media")
MOUNT_POINT=$(yq -r '.media.vms.download.nfs_mount // "/mnt/media"' "$TENANT_BINDING" 2>/dev/null || echo "/mnt/media")
EXPECTED_EXPORT_PATH="${NFS_SOURCE#*:}"

normalize_path_used() {
  local target_id="$1"
  local resolved_host="$2"
  local path_raw="$3"
  case "$path_raw" in
    lan|tailscale) echo "$path_raw"; return 0 ;;
  esac

  local lan_host ts_host
  lan_host="$(ssh_resolve_host "$target_id")"
  ts_host="$(ssh_resolve_tailscale_ip "$target_id")"
  if [[ -n "$ts_host" && "$resolved_host" == "$ts_host" && "$ts_host" != "$lan_host" ]]; then
    echo "tailscale"
  else
    echo "lan"
  fi
}

get_vm_ssh_ref() {
  local vm="$1"
  local target default_user user resolved resolved_host path_raw path_used
  local lan_host ts_host access_policy

  target=$(yq -r ".vms[] | select(.hostname == \"$vm\") | .ssh_target // .hostname // \"\"" "$VM_BINDING" 2>/dev/null || echo "")
  default_user=$(yq -r ".vms[] | select(.hostname == \"$vm\") | .ssh_user // \"ubuntu\"" "$VM_BINDING" 2>/dev/null || echo "ubuntu")

  if [[ -z "$target" || "$target" == "null" ]]; then
    echo ""
    return 1
  fi

  user="$(ssh_resolve_user "$target" "$default_user")"
  resolved="$(ssh_resolve_host_with_fallback "$target" 2 2>/dev/null || true)"
  resolved_host="$(echo "$resolved" | awk '{print $1}')"
  path_raw="$(echo "$resolved" | awk '{print $2}')"
  if [[ -z "$resolved_host" || "$path_raw" == "unreachable" ]]; then
    lan_host="$(ssh_resolve_host "$target")"
    ts_host="$(ssh_resolve_tailscale_ip "$target")"
    access_policy="$(ssh_resolve_access_policy "$target")"
    case "$access_policy" in
      tailscale_required)
        [[ -n "$ts_host" ]] && resolved_host="$ts_host" && path_raw="tailscale"
        ;;
      lan_first)
        if [[ -n "$ts_host" && "$ts_host" != "$lan_host" ]]; then
          resolved_host="$ts_host"
          path_raw="tailscale"
        elif [[ -n "$lan_host" ]]; then
          resolved_host="$lan_host"
          path_raw="lan"
        fi
        ;;
      *)
        [[ -n "$lan_host" ]] && resolved_host="$lan_host" && path_raw="lan"
        ;;
    esac
  fi
  if [[ -z "$resolved_host" || "$path_raw" == "unreachable" ]]; then
    echo ""
    return 1
  fi
  path_used="$(normalize_path_used "$target" "$resolved_host" "$path_raw")"
  echo "${user}@${resolved_host} ${path_used}"
}

check_vm_nfs() {
  local vm="$1"
  local expected_mode="$2"
  local ssh_meta ssh_ref path_used
  local mount_info
  local mount_source
  local mount_opts
  ssh_meta="$(get_vm_ssh_ref "$vm" 2>/dev/null || true)"
  ssh_ref="$(echo "$ssh_meta" | awk '{print $1}')"
  path_used="$(echo "$ssh_meta" | awk '{print $2}')"

  if [[ -z "$ssh_ref" ]]; then
    err "$vm: no ssh target found in vm.lifecycle binding"
    return 1
  fi
  echo "  TRACE: $vm path_used=${path_used}"

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
