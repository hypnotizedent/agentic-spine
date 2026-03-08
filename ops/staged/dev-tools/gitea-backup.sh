#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# gitea-backup.sh — Gitea app-level backup (dump + pg_dump + verified 730XD sync)
# ═══════════════════════════════════════════════════════════════
#
# Runs on: dev-tools (VM 206)
# Cron:    55 2 * * * /usr/local/bin/gitea-backup.sh
# Pattern: matches vaultwarden-backup.sh + infisical-backup.sh
#
# Artifacts:
#   1. gitea dump (zip) — repos, attachments, config snapshot
#   2. pg_dump (sql.gz) — belt-and-suspenders DB backup
#
# Retention: 7 daily on 730XD canonical plane
# 730XD path: /md1400/backup-cold/apps/dev-tools/gitea/
#
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

STACK_DIR="/opt/stacks/gitea"
BACKUP_DIR="/opt/backups/gitea/staging"
ARCHIVE_DIR="/opt/backups/gitea/last-good"
OFFSITE_USER="root"
OFFSITE_HOST="pve"
OFFSITE_PATH="/md1400/backup-cold/apps/dev-tools/gitea"
OFFSITE_IDENTITY_FILE="${OFFSITE_IDENTITY_FILE:-/home/ubuntu/.ssh/id_ed25519}"
RETENTION_DAYS=7
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
LOG_TAG="gitea-backup"
SUCCESS_MARKER="$BACKUP_DIR/.sync-success"
CONTAINER_TMP="/tmp/gitea-backup"

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

offsite_ssh() {
  ssh "${OFFSITE_SSH_OPTS[@]}" "$OFFSITE_USER@$OFFSITE_HOST" "$@"
}

log() { logger -t "$LOG_TAG" "$*"; echo "[$(date -Iseconds)] $*"; }

cleanup() {
  local exit_code=$?
  docker exec -u git gitea rm -rf "$CONTAINER_TMP" >/dev/null 2>&1 || true
  if [[ -f "$SUCCESS_MARKER" ]]; then
    log "730XD sync verified — cleaning staging area"
    rm -rf "$BACKUP_DIR"
  elif (( exit_code != 0 )); then
    log "ERROR: Backup failed (exit $exit_code) — preserving staging artifacts at $BACKUP_DIR"
  fi
}
trap cleanup EXIT

mkdir -p "$BACKUP_DIR" "$ARCHIVE_DIR"
rm -f "$SUCCESS_MARKER"

# ─────────────────────────────────────────────────────────────
# 2. Gitea application dump
# ─────────────────────────────────────────────────────────────
DUMP_FILE="$BACKUP_DIR/gitea-dump-${TIMESTAMP}.zip"
CONTAINER_DUMP="$CONTAINER_TMP/gitea-dump-${TIMESTAMP}.zip"
log "Starting gitea dump..."
docker exec -u git gitea mkdir -p "$CONTAINER_TMP"
docker exec -u git gitea gitea dump --type zip --file "$CONTAINER_DUMP" 2>&1 | logger -t "$LOG_TAG"
docker cp "gitea:${CONTAINER_DUMP}" "$DUMP_FILE"
log "Gitea dump complete: $(du -h "$DUMP_FILE" | cut -f1)"

# ─────────────────────────────────────────────────────────────
# 3. PostgreSQL dump
# ─────────────────────────────────────────────────────────────
DB_FILE="$BACKUP_DIR/gitea-db-${TIMESTAMP}.sql.gz"
log "Starting pg_dump..."

# Read DB password from stack .env (does not print secrets)
set -a
# shellcheck source=/dev/null
source "$STACK_DIR/.env"
set +a

docker exec -e PGPASSWORD="$GITEA_DB_PASSWORD" gitea-postgres \
  pg_dump -U gitea gitea | gzip > "$DB_FILE"
log "pg_dump complete: $(du -h "$DB_FILE" | cut -f1)"

# ─────────────────────────────────────────────────────────────
# 4. Rsync to 730XD
# ─────────────────────────────────────────────────────────────
log "Testing 730XD connectivity..."
offsite_ssh "mkdir -p '$OFFSITE_PATH'" >/dev/null

log "Syncing to 730XD ($OFFSITE_HOST:$OFFSITE_PATH)..."
rsync -az --timeout=120 -e "$RSYNC_SSH" "$DUMP_FILE" "$DB_FILE" "$OFFSITE_USER@$OFFSITE_HOST:$OFFSITE_PATH/"

for expected in "gitea-dump-${TIMESTAMP}.zip" "gitea-db-${TIMESTAMP}.sql.gz"; do
  offsite_ssh "test -f '$OFFSITE_PATH/$expected'" >/dev/null
done

find "$ARCHIVE_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
cp -a "$BACKUP_DIR"/* "$ARCHIVE_DIR"/
touch "$SUCCESS_MARKER"

# ─────────────────────────────────────────────────────────────
# 5. Retention: prune old backups on 730XD (keep last N days)
# ─────────────────────────────────────────────────────────────
log "Pruning backups older than ${RETENTION_DAYS} days on 730XD..."
offsite_ssh "find '$OFFSITE_PATH' -name 'gitea-*' -mtime +${RETENTION_DAYS} -delete" >/dev/null 2>&1 || true
log "Retention prune complete"

log "Gitea backup finished successfully"
