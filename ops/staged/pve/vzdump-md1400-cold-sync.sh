#!/usr/bin/env bash
# vzdump-md1400-cold-sync.sh - Promote latest local vzdump artifacts into md1400 cold storage
set -euo pipefail

SRC_DIR="/tank/backups/vzdump/dump"
DEST_DIR="/md1400/backup-cold/vzdump/pve"
MANIFEST_DIR="$DEST_DIR/manifests"
LOCK_FILE="/var/lock/vzdump-md1400-cold-sync.lock"
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
KEEP_PER_GUEST=2

QEMU_VMIDS=(202 203 204 205 206 207 209 210 211 212 213 214 215)
LXC_VMIDS=(220)

log() { echo "[$(date -Iseconds)] $*"; }

install -d -m 755 "$DEST_DIR" "$MANIFEST_DIR"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "SKIP: vzdump cold sync already running"
  exit 0
fi

MANIFEST_FILE="$MANIFEST_DIR/vzdump-md1400-cold-sync-${TIMESTAMP}.txt"
{
  echo "timestamp_utc=$TIMESTAMP"
  echo "source_dir=$SRC_DIR"
} >"$MANIFEST_FILE"

sync_guest() {
  local kind="$1"
  local vmid="$2"
  local artifact_glob log_glob notes_glob latest latest_log latest_notes stem
  if [[ "$kind" == "qemu" ]]; then
    artifact_glob="vzdump-qemu-${vmid}-*.vma.zst"
    log_glob="vzdump-qemu-${vmid}-*.log"
    notes_glob="vzdump-qemu-${vmid}-*.vma.zst.notes"
    latest="$(find "$SRC_DIR" -maxdepth 1 -name "$artifact_glob" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
  else
    artifact_glob="vzdump-lxc-${vmid}-*.tar.zst"
    log_glob="vzdump-lxc-${vmid}-*.log"
    notes_glob="vzdump-lxc-${vmid}-*.tar.zst.notes"
    latest="$(find "$SRC_DIR" -maxdepth 1 -name "$artifact_glob" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
  fi

  if [[ -z "$latest" ]]; then
    log "WARN: no artifact found for ${kind}-${vmid}"
    echo "missing=${kind}-${vmid}" >>"$MANIFEST_FILE"
    return 0
  fi

  stem="${latest%.vma.zst}"
  stem="${stem%.tar.zst}"
  latest_log="${stem}.log"
  latest_notes="${latest}.notes"

  rsync -a --partial --inplace "$latest" "$DEST_DIR/"
  [[ -f "$latest_log" ]] && rsync -a "$latest_log" "$DEST_DIR/"
  [[ -f "$latest_notes" ]] && rsync -a "$latest_notes" "$DEST_DIR/"

  find "$DEST_DIR" -maxdepth 1 -name "$artifact_glob" -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk "NR>${KEEP_PER_GUEST}{print substr(\$0,index(\$0,\" \")+1)}" | xargs -r rm -f
  find "$DEST_DIR" -maxdepth 1 -name "$log_glob" -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk "NR>${KEEP_PER_GUEST}{print substr(\$0,index(\$0,\" \")+1)}" | xargs -r rm -f
  find "$DEST_DIR" -maxdepth 1 -name "$notes_glob" -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk "NR>${KEEP_PER_GUEST}{print substr(\$0,index(\$0,\" \")+1)}" | xargs -r rm -f

  log "OK: synced $(basename "$latest")"
  echo "artifact=$(basename "$latest")" >>"$MANIFEST_FILE"
}

for vmid in "${QEMU_VMIDS[@]}"; do
  sync_guest qemu "$vmid"
done

for vmid in "${LXC_VMIDS[@]}"; do
  sync_guest lxc "$vmid"
done

find "$MANIFEST_DIR" -maxdepth 1 -name 'vzdump-md1400-cold-sync-*.txt' -mtime +14 -delete 2>/dev/null || true
log "OK: wrote manifest $MANIFEST_FILE"
