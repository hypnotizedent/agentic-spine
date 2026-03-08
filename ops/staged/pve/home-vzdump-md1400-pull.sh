#!/usr/bin/env bash
# home-vzdump-md1400-pull.sh - Pull latest proxmox-home vzdump artifacts into md1400 cold storage
set -euo pipefail

SRC_USER="root"
SRC_HOST="${SRC_HOST:-100.103.99.62}"
SRC_DIR="/mnt/pve/synology-backups/dump"
DEST_DIR="/md1400/backup-cold/vzdump/home"
IDENTITY_FILE="${IDENTITY_FILE:-/root/.ssh/id_rsa}"
LOCK_FILE="/var/lock/home-vzdump-md1400-pull.lock"
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
KEEP_QEMU=3
KEEP_LXC=2

SSH_OPTS=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -o ConnectTimeout=20
)
if [[ -n "$IDENTITY_FILE" && -r "$IDENTITY_FILE" ]]; then
  SSH_OPTS+=(-i "$IDENTITY_FILE")
fi
printf -v RSYNC_SSH '%q ' ssh "${SSH_OPTS[@]}"
RSYNC_SSH="${RSYNC_SSH% }"

log() { echo "[$(date -Iseconds)] $*"; }
src_ssh() { ssh "${SSH_OPTS[@]}" "$SRC_USER@$SRC_HOST" "$@"; }

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "SKIP: home vzdump md1400 pull already running"
  exit 0
fi

install -d -m 755 "$DEST_DIR"

sync_latest() {
  local kind="$1"
  local vmid="$2"
  local keep="$3"
  local ext latest stem log_path notes_path pattern
  if [[ "$kind" == "qemu" ]]; then
    ext="vma.zst"
  else
    ext="tar.zst"
  fi
  pattern="vzdump-${kind}-${vmid}-*.${ext}"
  latest="$(src_ssh "find '$SRC_DIR' -maxdepth 1 -name '$pattern' -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-" 2>/dev/null || true)"
  [[ -n "$latest" ]] || { log "WARN: no artifact found for ${kind}-${vmid} on $SRC_HOST"; return 0; }

  stem="${latest%.vma.zst}"
  stem="${stem%.tar.zst}"
  log_path="${stem}.log"
  notes_path="${latest}.notes"

  rsync -a --partial --inplace --timeout=120 -e "$RSYNC_SSH" "$SRC_USER@$SRC_HOST:$latest" "$DEST_DIR/"
  src_ssh "test -f '$log_path'" >/dev/null 2>&1 && rsync -a -e "$RSYNC_SSH" "$SRC_USER@$SRC_HOST:$log_path" "$DEST_DIR/"
  src_ssh "test -f '$notes_path'" >/dev/null 2>&1 && rsync -a -e "$RSYNC_SSH" "$SRC_USER@$SRC_HOST:$notes_path" "$DEST_DIR/"

  find "$DEST_DIR" -maxdepth 1 -name "$pattern" -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk "NR>${keep}{print substr(\$0,index(\$0,\" \")+1)}" | xargs -r rm -f
  log "OK: pulled $(basename "$latest")"
}

sync_latest qemu 100 "$KEEP_QEMU"
sync_latest lxc 105 "$KEEP_LXC"

printf 'timestamp_utc=%s\nsource_host=%s\n' "$TIMESTAMP" "$SRC_HOST" >"$DEST_DIR/home-vzdump-md1400-pull-${TIMESTAMP}.txt"
find "$DEST_DIR" -maxdepth 1 -name 'home-vzdump-md1400-pull-*.txt' -mtime +14 -delete 2>/dev/null || true
log "OK: home vzdump md1400 pull complete"
