#!/bin/bash
# stalwart-backup.sh — Daily backup of Stalwart mail server (config + data volume)
# DESTINATION: 730XD canonical backup plane (/md1400/backup-cold/apps/communications/stalwart/)
# GOVERNANCE: Finance Stack Doctrine v1 compliance (offsite verification required)
set -euo pipefail

BACKUP_DIR="/srv/stalwart-backups"
BACKUP_STAGING="$BACKUP_DIR/staging"
BACKUP_ARCHIVE="$BACKUP_DIR/last-good"
STACK_DIR="/opt/stacks/communications-stack"
VOLUME_NAME="communications-stack_stalwart-data"
OFFSITE_USER="root"
OFFSITE_HOST="pve"
OFFSITE_BASE="/md1400/backup-cold/apps/communications/stalwart"
OFFSITE_IDENTITY_FILE="${OFFSITE_IDENTITY_FILE:-/home/ubuntu/.ssh/id_ed25519}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H%M%SZ)
LOG_TAG="stalwart-backup"
SUCCESS_MARKER="$BACKUP_STAGING/.sync-success"

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

cleanup() {
  local exit_code=$?
  if [[ -f "$SUCCESS_MARKER" ]]; then
    log "730XD offsite sync verified — cleaning staging area"
    rm -rf "$BACKUP_STAGING"
  elif (( exit_code != 0 )); then
    log "ERROR: Backup failed (exit $exit_code) — preserving staging artifacts at $BACKUP_STAGING"
    log "ERROR: Most recent backup NOT synced to 730XD — manual intervention required"
  fi
}
trap cleanup EXIT

mkdir -p "$BACKUP_STAGING" "$BACKUP_ARCHIVE"
rm -f "$SUCCESS_MARKER"

log "=== Stalwart backup start (730XD offsite) ==="
log "Destination: 730XD canonical backup plane ($OFFSITE_HOST:$OFFSITE_BASE)"

# Backup Stalwart data volume
DATA_ARCHIVE="$BACKUP_STAGING/stalwart-data-${TIMESTAMP}.tar.gz"
log "Backing up Stalwart data volume: $VOLUME_NAME"
if ! docker run --rm \
  -v "${VOLUME_NAME}:/data:ro" \
  -v "$BACKUP_STAGING:/backup" \
  alpine sh -c "tar -czf /backup/stalwart-data-${TIMESTAMP}.tar.gz -C /data ." 2>&1; then
  log "ERROR: Volume backup failed"
  exit 1
fi
log "OK: Data volume backup created $(du -h "$DATA_ARCHIVE" | cut -f1)"

# Backup config + compose stack directory
CONFIG_ARCHIVE="$BACKUP_STAGING/stalwart-config-${TIMESTAMP}.tar.gz"
log "Backing up Stalwart config + stack directory: $STACK_DIR"
if ! tar -czf "$CONFIG_ARCHIVE" -C / "$(echo "$STACK_DIR" | sed 's|^/||')" 2>&1; then
  log "ERROR: Config backup failed"
  exit 1
fi
log "OK: Config backup created $(du -h "$CONFIG_ARCHIVE" | cut -f1)"

# Create manifest
DATA_SIZE=$(stat -c %s "$DATA_ARCHIVE" 2>/dev/null || stat -f %z "$DATA_ARCHIVE" 2>/dev/null || echo 0)
CONFIG_SIZE=$(stat -c %s "$CONFIG_ARCHIVE" 2>/dev/null || stat -f %z "$CONFIG_ARCHIVE" 2>/dev/null || echo 0)

MANIFEST_FILE="$BACKUP_STAGING/stalwart-manifest-${TIMESTAMP}.txt"
cat > "$MANIFEST_FILE" <<EOF
timestamp=$TIMESTAMP
data_archive_bytes=$DATA_SIZE
config_archive_bytes=$CONFIG_SIZE
volume_name=$VOLUME_NAME
stack_dir=$STACK_DIR
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
for artifact in "$DATA_ARCHIVE" "$CONFIG_ARCHIVE" "$MANIFEST_FILE"; do
  if [[ ! -f "$artifact" ]]; then
    log "WARN: Skipping missing artifact: $artifact"
    continue
  fi
  log "  Syncing $(basename "$artifact") -> 730XD"
  if ! rsync -az --timeout=120 -e "$RSYNC_SSH" "$artifact" "$OFFSITE_USER@$OFFSITE_HOST:$OFFSITE_BASE/"; then
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
  "stalwart-data-${TIMESTAMP}.tar.gz" \
  "stalwart-config-${TIMESTAMP}.tar.gz" \
  "stalwart-manifest-${TIMESTAMP}.txt"; do
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
# 730XD retention (14 days)
offsite_ssh "bash -lc '
    find \"$OFFSITE_BASE\" -name \"stalwart-data-*.tar.gz\" -mtime +14 -delete 2>/dev/null || true
    find \"$OFFSITE_BASE\" -name \"stalwart-config-*.tar.gz\" -mtime +14 -delete 2>/dev/null || true
    find \"$OFFSITE_BASE\" -name \"stalwart-manifest-*.txt\" -mtime +14 -delete 2>/dev/null || true
  '" >/dev/null 2>&1 || log "WARN: 730XD retention cleanup encountered errors (non-fatal)"

log "Retention cleanup complete"

log "=== Success: Archiving local recovery point ==="
mkdir -p "$BACKUP_ARCHIVE"
find "$BACKUP_ARCHIVE" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
cp -a "$BACKUP_STAGING"/* "$BACKUP_ARCHIVE"/
touch "$SUCCESS_MARKER"

log "Stalwart backup SUCCEEDED — 730XD sync verified, local archive updated"
log "Local archive: $BACKUP_ARCHIVE"
log "730XD location: $OFFSITE_HOST:$OFFSITE_BASE"
exit 0
