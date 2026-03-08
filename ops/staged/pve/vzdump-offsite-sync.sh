#!/usr/bin/env bash
# vzdump-offsite-sync.sh — Push latest feasible shop VM backups to NAS offsite
set -euo pipefail

LOG="/var/log/vzdump-offsite-sync.log"
NAS_USER="ronadmin"
NAS_HOST="100.102.199.111"
NAS_DIR="/volume1/backups/proxmox/vzdump/critical"
SRC_DIR="/tank/backups/vzdump/dump"
BWLIMIT=1500  # KB/s (~12 Mbps, leaves headroom for shop traffic)
RSYNC_SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20 -o LogLevel=ERROR"

# Feasible nightly offsite set. Excludes VM 200 (186GB), VM 212 (100GB-215GB),
# and VM 214 (~1TB) because they do not fit the current nightly uplink window.
VMIDS="204 205 206 207 209 210 211 213"

log() {
  echo "$(date -Is) $*" >>"$LOG"
}

log "=== offsite sync start ==="

if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 \
  "${NAS_USER}@${NAS_HOST}" "mkdir -p '$NAS_DIR'" >/dev/null 2>&1; then
  log "FAIL preflight: cannot reach NAS ${NAS_HOST} or create $NAS_DIR"
  exit 1
fi

for vmid in $VMIDS; do
  latest="$(find "$SRC_DIR" -name "vzdump-qemu-${vmid}-*.vma.zst" -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -1 | cut -d" " -f2-)"
  latest_log="$(find "$SRC_DIR" -name "vzdump-qemu-${vmid}-*.log" -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -1 | cut -d" " -f2-)"

  if [[ -z "$latest" ]]; then
    log "SKIP vm-$vmid: no backup found"
    continue
  fi

  size="$(du -h "$latest" | cut -f1)"
  log "SYNC vm-$vmid: $(basename "$latest") ($size)"

  args=("$latest")
  if [[ -n "$latest_log" ]]; then
    args+=("$latest_log")
  fi

  if rsync -az --bwlimit="$BWLIMIT" -e "$RSYNC_SSH" "${args[@]}" "${NAS_USER}@${NAS_HOST}:${NAS_DIR}/" >>"$LOG" 2>&1; then
    log "OK   vm-$vmid"
  else
    log "FAIL vm-$vmid: rsync exit $?"
  fi
done

log "=== offsite sync done ==="
