#!/usr/bin/env bash
# archive-smb-snapshot.sh - Daily md1400 snapshot protection for archive-smb datasets
set -euo pipefail

DATASETS=(
  "md1400/ronny-projects"
  "md1400/mint-legacy"
)
RETENTION_DAYS="${RETENTION_DAYS:-14}"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
SNAPSHOT_PREFIX="auto-daily"
MANIFEST_DIR="/md1400/backup-cold/archive-smb/snapshots"
MANIFEST_FILE="${MANIFEST_DIR}/archive-smb-snapshot-${TIMESTAMP}.txt"

log() { echo "[$(date -Iseconds)] $*"; }

mkdir -p "$MANIFEST_DIR"

created_snapshots=()
for dataset in "${DATASETS[@]}"; do
  snapshot_name="${dataset}@${SNAPSHOT_PREFIX}-${TIMESTAMP}"
  zfs snapshot "$snapshot_name"
  created_snapshots+=("$snapshot_name")
  log "OK: created $snapshot_name"
done

for dataset in "${DATASETS[@]}"; do
  old_snapshots="$(zfs list -t snapshot -H -o name -s creation | grep "^${dataset}@${SNAPSHOT_PREFIX}-" | head -n -"${RETENTION_DAYS}" || true)"
  if [[ -n "$old_snapshots" ]]; then
    while IFS= read -r snapshot; do
      zfs destroy "$snapshot"
      log "OK: destroyed old snapshot $snapshot"
    done <<<"$old_snapshots"
  fi
done

{
  echo "timestamp_utc=${TIMESTAMP}"
  echo "retention_days=${RETENTION_DAYS}"
  for snapshot_name in "${created_snapshots[@]}"; do
    echo "snapshot=${snapshot_name}"
  done
} >"$MANIFEST_FILE"

find "$MANIFEST_DIR" -maxdepth 1 -name 'archive-smb-snapshot-*.txt' -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true

log "OK: wrote manifest $MANIFEST_FILE"
log "Archive-SMB snapshot cycle complete"
