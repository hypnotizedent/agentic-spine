#!/usr/bin/env bash
# mail-archiver-backup.sh — Daily backup of mail-archiver DB + uploads WITH 730XD OFFSITE
# DESTINATION: 730XD canonical backup plane (/md1400/backup-cold/apps/communications/mail-archiver/)
# GOVERNANCE: Communications offsite doctrine (offsite verification required)
set -euo pipefail

BACKUP_DIR="/srv/mail-archiver/backups"
BACKUP_STAGING="$BACKUP_DIR/staging"
BACKUP_ARCHIVE="$BACKUP_DIR/last-good"
UPLOADS_DIR="/srv/mail-archiver/uploads"
OFFSITE_USER="root"
OFFSITE_HOST="pve"
OFFSITE_BASE="/md1400/backup-cold/apps/communications/mail-archiver"
OFFSITE_IDENTITY_FILE="${OFFSITE_IDENTITY_FILE:-/home/ubuntu/.ssh/id_ed25519}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H%M%SZ)
LOG_TAG="mail-archiver-backup"
SUCCESS_MARKER="$BACKUP_STAGING/.sync-success"
LOCK_FILE="/var/lock/mail-archiver-backup.lock"

OFFSITE_SSH_OPTS=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -o ConnectTimeout=30
)
if [[ -n "$OFFSITE_IDENTITY_FILE" && -r "$OFFSITE_IDENTITY_FILE" ]]; then
  OFFSITE_SSH_OPTS+=(-i "$OFFSITE_IDENTITY_FILE")
fi
printf -v RSYNC_SSH '%q ' ssh "${OFFSITE_SSH_OPTS[@]}"
RSYNC_SSH="${RSYNC_SSH% }"

log() { logger -t "$LOG_TAG" "$*"; echo "[$(date -Iseconds)] $*"; }

offsite_ssh() {
  ssh "${OFFSITE_SSH_OPTS[@]}" "$OFFSITE_USER@$OFFSITE_HOST" "$@"
}

acquire_lock() {
  exec 200>"$LOCK_FILE"
  if ! flock -n 200; then
    log "ERROR: Another backup is already running (lock file: $LOCK_FILE)"
    log "ERROR: If this is incorrect, remove $LOCK_FILE manually"
    exit 1
  fi
  echo $$ >&200
}

release_lock() {
  rm -f "$LOCK_FILE"
}

cleanup() {
  local exit_code=$?
  if [[ -f "$SUCCESS_MARKER" ]]; then
    log "730XD offsite sync verified — cleaning staging area"
    rm -rf "$BACKUP_STAGING"
  elif (( exit_code != 0 )); then
    log "ERROR: Backup failed (exit $exit_code) — preserving staging artifacts at $BACKUP_STAGING"
    log "ERROR: Most recent backup NOT synced to 730XD — manual intervention required"
  fi
  release_lock
}
trap cleanup EXIT

acquire_lock

install -d -m 755 "$BACKUP_STAGING" "$BACKUP_ARCHIVE"
rm -f "$SUCCESS_MARKER"

log "=== mail-archiver backup start (730XD offsite) ==="
log "Destination: 730XD canonical backup plane ($OFFSITE_HOST:$OFFSITE_BASE)"

# pg_dump inside the container
DB_DUMP="$BACKUP_STAGING/mail-archiver-db-${TIMESTAMP}.sql.gz"
docker exec mail-archiver-db pg_dump -U mailuser MailArchiver 2>&1 | gzip > "$DB_DUMP"
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log "FAIL: pg_dump failed"
    rm -f "$DB_DUMP"
    exit 1
fi
log "OK: DB dump created $(du -h "$DB_DUMP" | cut -f1)"

# tar uploads directory
UPLOADS_ARCHIVE="$BACKUP_STAGING/mail-archiver-uploads-${TIMESTAMP}.tar.gz"
if [ -d "$UPLOADS_DIR" ]; then
    tar -czf "$UPLOADS_ARCHIVE" -C "$(dirname "$UPLOADS_DIR")" "$(basename "$UPLOADS_DIR")" 2>&1
    log "OK: uploads archive $(du -h "$UPLOADS_ARCHIVE" | cut -f1)"
else
    log "WARN: uploads dir not found, skipping"
fi

# Sanity check: DB dump should be > 100MB for realistic mail archive
DB_SIZE=$(stat -c %s "$DB_DUMP" 2>/dev/null || stat -f %z "$DB_DUMP" 2>/dev/null || echo 0)
if (( DB_SIZE < 104857600 )); then
    log "WARN: DB dump is smaller than expected (${DB_SIZE} bytes), but proceeding"
fi

# Get row count from DB for manifest
ROW_COUNT=$(docker exec mail-archiver-db psql -U mailuser -d MailArchiver -Atc "SELECT COUNT(*) FROM emails;" 2>/dev/null || echo 0)
log "Mail archive row count: $ROW_COUNT"

# Create manifest
MANIFEST_FILE="$BACKUP_STAGING/mail-archiver-manifest-${TIMESTAMP}.txt"
cat > "$MANIFEST_FILE" <<EOF
timestamp=$TIMESTAMP
db_dump_bytes=$DB_SIZE
uploads_archive_bytes=$(stat -c %s "$UPLOADS_ARCHIVE" 2>/dev/null || echo 0)
email_count=$ROW_COUNT
EOF

log "=== Phase 2: 730XD offsite sync ==="
log "Testing 730XD connectivity..."
if ! offsite_ssh "echo 'connectivity OK'" >/dev/null 2>&1; then
  log "ERROR: Cannot reach 730XD at $OFFSITE_HOST — aborting sync"
  log "ERROR: Local backups preserved at $BACKUP_STAGING"
  exit 1
fi

log "Ensuring 730XD backup directory exists..."
if ! offsite_ssh "mkdir -p '$OFFSITE_BASE'" >/dev/null 2>&1; then
  log "ERROR: Failed to create 730XD directory"
  exit 1
fi

log "Syncing artifacts to 730XD..."
sync_fail=0
for artifact in "$DB_DUMP" "$UPLOADS_ARCHIVE" "$MANIFEST_FILE"; do
  if [[ ! -f "$artifact" ]]; then
    log "WARN: Skipping missing artifact: $artifact"
    continue
  fi
  log "  Syncing $(basename "$artifact") -> 730XD"
  if ! rsync -a --partial --inplace --timeout=120 -e "$RSYNC_SSH" "$artifact" "$OFFSITE_USER@$OFFSITE_HOST:$OFFSITE_BASE/"; then
    log "ERROR: rsync failed for $(basename "$artifact")"
    sync_fail=$((sync_fail + 1))
  fi
done

if (( sync_fail > 0 )); then
  log "ERROR: $sync_fail artifact(s) failed to sync to 730XD"
  log "ERROR: Local backups preserved at $BACKUP_STAGING for manual recovery"
  exit 1
fi

log "730XD sync complete — all artifacts transferred"

log "=== Phase 3: 730XD verification ==="
verify_fail=0
for expected in \
  "mail-archiver-db-${TIMESTAMP}.sql.gz" \
  "mail-archiver-uploads-${TIMESTAMP}.tar.gz" \
  "mail-archiver-manifest-${TIMESTAMP}.txt"; do
  if ! offsite_ssh "test -f '$OFFSITE_BASE/$expected'" 2>/dev/null; then
    log "ERROR: 730XD verification failed — missing $expected"
    verify_fail=$((verify_fail + 1))
  else
    log "  Verified: $expected"
  fi
done

if (( verify_fail > 0 )); then
  log "ERROR: 730XD verification failed for $verify_fail artifact(s)"
  log "ERROR: Local backups preserved at $BACKUP_STAGING"
  exit 1
fi

log "730XD verification passed — all artifacts confirmed on 730XD"

log "=== Phase 4: Retention cleanup ==="
# Local canonical recovery point is single-slot last-good; historical flat artifacts are preserved until separately pruned.
# 730XD retention remains the authoritative multi-day offsite history.
offsite_ssh "bash -lc '
    find \"$OFFSITE_BASE\" -name \"mail-archiver-db-*.sql.gz\" -mtime +14 -delete 2>/dev/null || true
    find \"$OFFSITE_BASE\" -name \"mail-archiver-uploads-*.tar.gz\" -mtime +14 -delete 2>/dev/null || true
    find \"$OFFSITE_BASE\" -name \"mail-archiver-manifest-*.txt\" -mtime +14 -delete 2>/dev/null || true
  '" >/dev/null 2>&1 || log "WARN: 730XD retention cleanup encountered errors (non-fatal)"

log "Retention cleanup complete"

log "=== Success: Archiving local recovery point ==="
mkdir -p "$BACKUP_ARCHIVE"
find "$BACKUP_ARCHIVE" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
cp -a "$BACKUP_STAGING"/* "$BACKUP_ARCHIVE"/
touch "$SUCCESS_MARKER"

log "mail-archiver backup SUCCEEDED — 730XD sync verified, local archive updated"
log "Local archive: $BACKUP_ARCHIVE"
log "730XD location: $OFFSITE_HOST:$OFFSITE_BASE"
exit 0
