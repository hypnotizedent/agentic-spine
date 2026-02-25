#!/usr/bin/env bash
# finance-stack-backup.sh - App-level backups for VM 211 (Firefly, Ghostfolio, Paperless)
set -euo pipefail

STACK_DIR="/opt/stacks/finance"
BACKUP_DIR="/tmp/finance-stack-backup"
NAS_USER="ronadmin"
NAS_HOST="100.102.199.111"
NAS_BASE="/volume1/backups/apps"
RETENTION_DAYS=14
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
LOG_TAG="finance-stack-backup"
RSYNC_SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

log() { logger -t "$LOG_TAG" "$*"; echo "[$(date -Iseconds)] $*"; }

cleanup() {
  rm -rf "$BACKUP_DIR"
}
trap cleanup EXIT

mkdir -p "$BACKUP_DIR"

if [[ ! -f "$STACK_DIR/.env" ]]; then
  log "FAIL: missing $STACK_DIR/.env"
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$STACK_DIR/.env"
set +a

: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD missing in .env}"
: "${PAPERLESS_DB_PASS:?PAPERLESS_DB_PASS missing in .env}"

PG_USER="${POSTGRES_USER:-firefly}"
PG_DB="${POSTGRES_DB:-firefly}"

dump_db() {
  local db_name="$1"
  local db_user="$2"
  local db_pass="$3"
  local out_file="$4"
  docker exec -e PGPASSWORD="$db_pass" firefly-postgres \
    pg_dump -U "$db_user" "$db_name" | gzip > "$out_file"
}

firefly_dump="$BACKUP_DIR/firefly-db-${TIMESTAMP}.sql.gz"
ghostfolio_dump="$BACKUP_DIR/ghostfolio-db-${TIMESTAMP}.sql.gz"
paperless_dump="$BACKUP_DIR/paperless-db-${TIMESTAMP}.sql.gz"
paperless_zip_base="paperless-export-${TIMESTAMP}"
paperless_zip="${paperless_zip_base}.zip"
paperless_export_host_dir="$STACK_DIR/data/paperless/export"
paperless_export_container_dir="/usr/src/paperless/export"
paperless_zip_src="$paperless_export_host_dir/$paperless_zip"
paperless_zip_dst="$BACKUP_DIR/$paperless_zip"

log "Starting Firefly DB dump..."
dump_db "$PG_DB" "$PG_USER" "$POSTGRES_PASSWORD" "$firefly_dump"
log "Firefly dump complete: $(du -h "$firefly_dump" | cut -f1)"

log "Starting Ghostfolio DB dump..."
dump_db "ghostfolio" "$PG_USER" "$POSTGRES_PASSWORD" "$ghostfolio_dump"
log "Ghostfolio dump complete: $(du -h "$ghostfolio_dump" | cut -f1)"

log "Starting Paperless DB dump..."
dump_db "paperless" "paperless" "$PAPERLESS_DB_PASS" "$paperless_dump"
log "Paperless DB dump complete: $(du -h "$paperless_dump" | cut -f1)"

log "Starting Paperless document export..."
docker exec paperless-ngx document_exporter "$paperless_export_container_dir" \
  --zip --zip-name "$paperless_zip_base" --no-progress-bar >/dev/null
if [[ ! -f "$paperless_zip_src" ]]; then
  log "FAIL: expected paperless export not found: $paperless_zip_src"
  exit 1
fi
cp "$paperless_zip_src" "$paperless_zip_dst"
log "Paperless export complete: $(du -h "$paperless_zip_dst" | cut -f1)"

log "Ensuring NAS backup directories exist..."
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$NAS_USER@$NAS_HOST" "mkdir -p '$NAS_BASE/finance' '$NAS_BASE/ghostfolio' '$NAS_BASE/paperless'" >/dev/null

log "Syncing artifacts to NAS..."
rsync -az --timeout=120 -e "$RSYNC_SSH" "$firefly_dump" "$NAS_USER@$NAS_HOST:$NAS_BASE/finance/"
rsync -az --timeout=120 -e "$RSYNC_SSH" "$ghostfolio_dump" "$NAS_USER@$NAS_HOST:$NAS_BASE/ghostfolio/"
rsync -az --timeout=120 -e "$RSYNC_SSH" "$paperless_dump" "$NAS_USER@$NAS_HOST:$NAS_BASE/paperless/"
rsync -az --timeout=120 -e "$RSYNC_SSH" "$paperless_zip_dst" "$NAS_USER@$NAS_HOST:$NAS_BASE/paperless/"
log "NAS sync complete"

log "Applying retention policy on NAS..."
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$NAS_USER@$NAS_HOST" "bash -lc '
    find \"$NAS_BASE/finance\" -name \"firefly-db-*.sql.gz\" -mtime +$RETENTION_DAYS -delete || true
    find \"$NAS_BASE/ghostfolio\" -name \"ghostfolio-db-*.sql.gz\" -mtime +$RETENTION_DAYS -delete || true
    find \"$NAS_BASE/paperless\" -name \"paperless-db-*.sql.gz\" -mtime +$RETENTION_DAYS -delete || true
    find \"$NAS_BASE/paperless\" -name \"paperless-export-*.zip\" -mtime +$RETENTION_DAYS -delete || true
  '" >/dev/null
log "Retention prune complete"

log "finance-stack backup finished successfully"
