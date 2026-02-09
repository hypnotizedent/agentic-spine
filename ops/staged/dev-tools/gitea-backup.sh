#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# gitea-backup.sh — Gitea app-level backup (dump + pg_dump + rsync)
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
# Retention: 7 daily on NAS
# NAS path:  /volume1/backups/apps/gitea/
#
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

STACK_DIR="/opt/stacks/gitea"
BACKUP_DIR="/tmp/gitea-backup"
NAS_HOST="nas"
NAS_PATH="/volume1/backups/apps/gitea"
RETENTION_DAYS=7
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
LOG_TAG="gitea-backup"

log() { logger -t "$LOG_TAG" "$*"; echo "[$(date -Iseconds)] $*"; }

cleanup() {
  rm -rf "$BACKUP_DIR"
}
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────
# 1. Create working directory
# ─────────────────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"

# ─────────────────────────────────────────────────────────────
# 2. Gitea application dump
# ─────────────────────────────────────────────────────────────
DUMP_FILE="$BACKUP_DIR/gitea-dump-${TIMESTAMP}.zip"
log "Starting gitea dump..."
docker exec gitea gitea dump --type zip --file "/tmp/gitea-dump-${TIMESTAMP}.zip" 2>&1 | logger -t "$LOG_TAG"
docker cp "gitea:/tmp/gitea-dump-${TIMESTAMP}.zip" "$DUMP_FILE"
docker exec gitea rm -f "/tmp/gitea-dump-${TIMESTAMP}.zip"
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
# 4. Rsync to NAS
# ─────────────────────────────────────────────────────────────
log "Syncing to NAS ($NAS_HOST:$NAS_PATH)..."
ssh "$NAS_HOST" "mkdir -p '$NAS_PATH'" 2>/dev/null || true
rsync -az --timeout=60 "$BACKUP_DIR/" "$NAS_HOST:$NAS_PATH/"
log "NAS sync complete"

# ─────────────────────────────────────────────────────────────
# 5. Retention: prune old backups on NAS (keep last N days)
# ─────────────────────────────────────────────────────────────
log "Pruning backups older than ${RETENTION_DAYS} days on NAS..."
ssh "$NAS_HOST" "find '$NAS_PATH' -name 'gitea-*' -mtime +${RETENTION_DAYS} -delete" 2>/dev/null || true
log "Retention prune complete"

log "Gitea backup finished successfully"
