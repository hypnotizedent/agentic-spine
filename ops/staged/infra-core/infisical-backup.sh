#!/usr/bin/env bash
# infisical-backup.sh — Daily pg_dump of Infisical database with verified NAS sync
set -euo pipefail

BACKUP_DIR="/opt/backups/infisical/staging"
ARCHIVE_DIR="/opt/backups/infisical/last-good"
NAS_USER="ronadmin"
NAS_HOST="nas"
NAS_DIR="/volume1/backups/apps/infisical"
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
BACKUP_FILE="infisical-db-${TIMESTAMP}.sql.gz"
RETENTION_DAYS=14
LOG="/var/log/infisical-backup.log"
SUCCESS_MARKER="$BACKUP_DIR/.sync-success"
LOCK_FILE="/var/lock/infisical-backup.lock"
RSYNC_SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=30"

log() { echo "$(date -Is) $*" >>"$LOG"; }

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "SKIP: backup already running"
  exit 0
fi

cleanup() {
  local exit_code=$?
  if [[ -f "$SUCCESS_MARKER" ]]; then
    log "OK: NAS sync verified, cleaning staging area"
    rm -rf "$BACKUP_DIR"
  elif (( exit_code != 0 )); then
    log "FAIL: backup failed (exit $exit_code), preserving staging at $BACKUP_DIR"
  fi
}
trap cleanup EXIT

mkdir -p "$BACKUP_DIR" "$ARCHIVE_DIR"
rm -f "$SUCCESS_MARKER"

log "=== infisical backup start ==="

docker exec infisical-db pg_dump -U infisical infisical 2>>"$LOG" | gzip >"$BACKUP_DIR/$BACKUP_FILE"
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  log "FAIL: pg_dump failed"
  rm -f "$BACKUP_DIR/$BACKUP_FILE"
  exit 1
fi
log "OK: created $BACKUP_FILE ($(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1))"

ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 \
  "${NAS_USER}@${NAS_HOST}" "mkdir -p '$NAS_DIR'" >/dev/null

rsync -az --timeout=120 -e "$RSYNC_SSH" "$BACKUP_DIR/$BACKUP_FILE" "${NAS_USER}@${NAS_HOST}:${NAS_DIR}/" >>"$LOG" 2>&1
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "${NAS_USER}@${NAS_HOST}" "test -f '$NAS_DIR/$BACKUP_FILE'" >/dev/null

ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "${NAS_USER}@${NAS_HOST}" "find '$NAS_DIR' -name 'infisical-db-*.sql.gz' -mtime +${RETENTION_DAYS} -delete" >/dev/null 2>&1 || true

find "$ARCHIVE_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
cp -a "$BACKUP_DIR"/* "$ARCHIVE_DIR"/
touch "$SUCCESS_MARKER"

log "=== infisical backup done ==="
