#!/usr/bin/env bash
# vaultwarden-backup.sh — Daily backup of vaultwarden data with verified 730XD sync
set -euo pipefail

BACKUP_DIR="/opt/backups/vaultwarden/staging"
ARCHIVE_DIR="/opt/backups/vaultwarden/last-good"
VW_DATA="/opt/stacks/vaultwarden/vw-data"
OFFSITE_USER="root"
OFFSITE_HOST="pve"
OFFSITE_BASE="/md1400/backup-cold/apps/infra-core/vaultwarden"
TIMESTAMP="$(date -u +%Y-%m-%d_%H%M%S)"
BACKUP_FILE="vaultwarden-backup-${TIMESTAMP}.tar.gz"
KEEP_REMOTE_DAYS=14
LOG="/var/log/vaultwarden-backup.log"
LOCK_FILE="/var/lock/vaultwarden-backup.lock"
SUCCESS_MARKER="$BACKUP_DIR/.sync-success"
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
    log "OK: 730XD sync verified, cleaning staging area"
    rm -rf "$BACKUP_DIR"
  elif (( exit_code != 0 )); then
    log "FAIL: backup failed (exit $exit_code), preserving staging at $BACKUP_DIR"
  fi
}
trap cleanup EXIT

mkdir -p "$BACKUP_DIR" "$ARCHIVE_DIR"
rm -f "$SUCCESS_MARKER"

log "=== vaultwarden backup start (730XD canonical plane) ==="

tar -czf "$BACKUP_DIR/$BACKUP_FILE" -C "$(dirname "$VW_DATA")" "$(basename "$VW_DATA")" 2>>"$LOG"
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  log "FAIL: tar failed"
  exit 1
fi
log "OK: created $BACKUP_FILE ($(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1))"

log "Testing 730XD connectivity..."
if ! $RSYNC_SSH "$OFFSITE_USER@$OFFSITE_HOST" "echo OK" >/dev/null 2>&1; then
  log "FAIL: cannot reach 730XD at $OFFSITE_HOST"
  exit 1
fi

log "Ensuring 730XD directory exists..."
$RSYNC_SSH "$OFFSITE_USER@$OFFSITE_HOST" "mkdir -p '$OFFSITE_BASE'"

log "Syncing to 730XD..."
rsync -az -e "$RSYNC_SSH" "$BACKUP_DIR/$BACKUP_FILE" "$OFFSITE_USER@$OFFSITE_HOST:$OFFSITE_BASE/"
if [[ $? -ne 0 ]]; then
  log "FAIL: 730XD sync failed"
  exit 1
fi

log "Verifying 730XD artifact..."
if ! $RSYNC_SSH "$OFFSITE_USER@$OFFSITE_HOST" "test -f '$OFFSITE_BASE/$BACKUP_FILE'" >/dev/null 2>&1; then
  log "FAIL: 730XD verification failed"
  exit 1
fi

log "Pruning 730XD backups older than ${KEEP_REMOTE_DAYS} days..."
$RSYNC_SSH "$OFFSITE_USER@$OFFSITE_HOST" \
  "find '$OFFSITE_BASE' -maxdepth 1 -name 'vaultwarden-backup-*.tar.gz' -mtime +${KEEP_REMOTE_DAYS} -delete" \
  >/dev/null 2>&1 || true

find "$ARCHIVE_DIR" -mindepth 1 -maxdepth 1 -name 'vaultwarden-backup-*.tar.gz' -delete 2>/dev/null || true
cp -a "$BACKUP_DIR/$BACKUP_FILE" "$ARCHIVE_DIR/"
touch "$SUCCESS_MARKER"

log "vaultwarden backup SUCCEEDED — 730XD sync verified"
exit 0
