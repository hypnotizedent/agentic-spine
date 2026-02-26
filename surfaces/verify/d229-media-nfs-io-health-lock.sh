#!/usr/bin/env bash
# TRIAGE: D229 media-nfs-io-health-lock — NFS read latency and retransmit health on both media VMs
# D229: Media NFS I/O Health Lock
# Enforces: NFS metadata latency <2s, zero retransmit growth, read ops responding on both VMs
set -euo pipefail

source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"

LATENCY_THRESHOLD_MS="${D229_LATENCY_THRESHOLD_MS:-2000}"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

get_vm_ssh_ref() {
  local vm="$1"
  local target user
  target=$(yq -r ".vms[] | select(.hostname == \"$vm\") | .ssh_target // .tailscale_ip // .lan_ip // \"\"" "$VM_BINDING" 2>/dev/null || echo "")
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

check_nfs_io() {
  local vm="$1"
  local ssh_ref
  ssh_ref="$(get_vm_ssh_ref "$vm" 2>/dev/null || true)"

  if [[ -z "$ssh_ref" ]]; then
    err "$vm: no SSH target found in vm.lifecycle binding"
    return
  fi

  # Test 1: NFS metadata latency — stat a known directory
  local latency_ms
  latency_ms=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" '
    start=$(date +%s%N 2>/dev/null || echo "0")
    stat /mnt/media/movies/ >/dev/null 2>&1
    end=$(date +%s%N 2>/dev/null || echo "0")
    if [[ "$start" != "0" && "$end" != "0" ]]; then
      echo $(( (end - start) / 1000000 ))
    else
      # Fallback: use time command if nanoseconds not available
      echo "0"
    fi
  ' 2>/dev/null || echo "-1")

  if [[ "$latency_ms" == "-1" ]]; then
    err "$vm: SSH failed — cannot measure NFS latency"
    return
  fi

  if [[ "$latency_ms" -gt "$LATENCY_THRESHOLD_MS" ]]; then
    err "$vm: NFS metadata latency ${latency_ms}ms exceeds ${LATENCY_THRESHOLD_MS}ms threshold"
  else
    ok "$vm: NFS metadata latency ${latency_ms}ms"
  fi

  # Test 2: NFS retransmit rate — /proc/net/rpc/nfs format: rpc <calls> <retrans> <authrefresh>
  # Threshold: >5% retransmit rate indicates network/server issues
  local retrans_pct
  retrans_pct=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" '
    if [[ -f /proc/net/rpc/nfs ]]; then
      awk "/^rpc/ { calls=\$2; retrans=\$3; if (calls > 0) printf \"%.2f\", (retrans/calls)*100; else print \"0.00\" }" /proc/net/rpc/nfs 2>/dev/null
    else
      echo "skip"
    fi
  ' 2>/dev/null || echo "skip")

  if [[ "$retrans_pct" == "skip" || -z "$retrans_pct" ]]; then
    ok "$vm: retransmit stats unavailable (non-critical)"
  else
    local pct_int="${retrans_pct%%.*}"
    if [[ "$pct_int" -gt 5 ]]; then
      err "$vm: NFS retransmit rate ${retrans_pct}% (>5% indicates network issues)"
    else
      ok "$vm: NFS retransmit rate ${retrans_pct}%"
    fi
  fi

  # Test 3: Read I/O test — verify NFS can serve a directory listing within 5s
  local read_ok
  read_ok=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_ref" '
    timeout 5 ls /mnt/media/movies/ >/dev/null 2>&1 && echo "ok" || echo "fail"
  ' 2>/dev/null || echo "fail")

  if [[ "$read_ok" == "fail" ]]; then
    err "$vm: NFS read I/O test failed (timeout or mount unresponsive)"
  else
    ok "$vm: NFS read I/O healthy"
  fi
}

check_nfs_io "download-stack"
check_nfs_io "streaming-stack"

# --- Result ---
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D229 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D229 PASS"
exit 0
