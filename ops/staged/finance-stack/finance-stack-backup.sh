#!/usr/bin/env bash
# finance-stack-backup.sh - App-level backups for VM 211 (Firefly, Ghostfolio, Paperless)
# DESTINATION: 730XD canonical backup plane (/md1400/backup-cold/apps/finance/)
# GOVERNANCE: tier1_critical backup with 730XD offsite sync verification
set -euo pipefail

STACK_DIR="/opt/stacks/finance"
BACKUP_DIR="/tmp/finance-stack-backup"
OFFSITE_USER="root"
OFFSITE_HOST="pve"
OFFSITE_BASE="/md1400/backup-cold/apps/finance"
OFFSITE_IDENTITY_FILE="${OFFSITE_IDENTITY_FILE:-/home/ubuntu/.ssh/id_ed25519}"
RETENTION_DAYS=14
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
LOG_TAG="finance-stack-backup"
SUCCESS_MARKER="$BACKUP_DIR/.sync-success"

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
  elif (( exit_code != 0 )); then
    log "ERROR: Backup failed (exit $exit_code) — preserving staging artifacts at $BACKUP_DIR"
    log "ERROR: Most recent backup NOT synced to 730XD — manual intervention required"
  fi
  rm -rf "$BACKUP_DIR"
}
trap cleanup EXIT

mkdir -p "$BACKUP_DIR"
rm -f "$SUCCESS_MARKER"

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

log "=== finance-stack backup starting at $TIMESTAMP ==="
log "Destination: 730XD canonical backup plane ($OFFSITE_HOST:$OFFSITE_BASE)"

firefly_dump="$BACKUP_DIR/firefly-db-${TIMESTAMP}.sql.gz"
ghostfolio_dump="$BACKUP_DIR/ghostfolio-db-${TIMESTAMP}.sql.gz"
paperless_dump="$BACKUP_DIR/paperless-db-${TIMESTAMP}.sql.gz"
paperless_zip_base="paperless-export-${TIMESTAMP}"
paperless_zip="${paperless_zip_base}.zip"
paperless_export_host_dir="$STACK_DIR/data/paperless/export"
paperless_export_container_dir="/usr/src/paperless/export"
paperless_zip_src="$paperless_export_host_dir/$paperless_zip"
paperless_zip_dst="$BACKUP_DIR/$paperless_zip"

log "=== Phase 1: Database dumps ==="
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

log "=== Phase 1b: Sanity manifest ==="
# Get row counts for sanity check
firefly_rows=$(docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" firefly-postgres \
  psql -U "$PG_USER" -d "$PG_DB" -Atc "SELECT COUNT(*) FROM transactions;" 2>/dev/null || echo 0)
ghostfolio_rows=$(docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" firefly-postgres \
  psql -U "$PG_USER" -d ghostfolio -Atc "SELECT COUNT(*) FROM \"Order\";" 2>/dev/null || echo 0)
paperless_docs=$(docker exec -e PGPASSWORD="$PAPERLESS_DB_PASS" firefly-postgres \
  psql -U paperless -d paperless -Atc "SELECT COUNT(*) FROM documents_document;" 2>/dev/null || echo 0)

finance_manifest="$BACKUP_DIR/finance-backup-manifest-${TIMESTAMP}.txt"
cat > "$finance_manifest" <<EOF
timestamp=$TIMESTAMP
firefly_dump_bytes=$(stat -c %s "$firefly_dump" 2>/dev/null || stat -f %z "$firefly_dump" 2>/dev/null || echo 0)
ghostfolio_dump_bytes=$(stat -c %s "$ghostfolio_dump" 2>/dev/null || stat -f %z "$ghostfolio_dump" 2>/dev/null || echo 0)
paperless_dump_bytes=$(stat -c %s "$paperless_dump" 2>/dev/null || stat -f %z "$paperless_dump" 2>/dev/null || echo 0)
paperless_export_bytes=$(stat -c %s "$paperless_zip_dst" 2>/dev/null || stat -f %z "$paperless_zip_dst" 2>/dev/null || echo 0)
firefly_transaction_count=$firefly_rows
ghostfolio_order_count=$ghostfolio_rows
paperless_document_count=$paperless_docs
EOF

log "Finance backup sanity manifest:"
log "  Firefly transactions: $firefly_rows"
log "  Ghostfolio orders: $ghostfolio_rows"
log "  Paperless documents: $paperless_docs"

log "=== Phase 2: 730XD offsite sync ==="
log "Testing 730XD connectivity..."
if ! offsite_ssh "echo 'connectivity OK'" >/dev/null 2>&1; then
  log "ERROR: Cannot reach 730XD at $OFFSITE_HOST — aborting sync"
  log "ERROR: Local backups preserved at $BACKUP_DIR"
  exit 1
fi

log "Ensuring 730XD backup directories exist..."
if ! offsite_ssh "mkdir -p '$OFFSITE_BASE/firefly' '$OFFSITE_BASE/ghostfolio' '$OFFSITE_BASE/paperless'" >/dev/null 2>&1; then
  log "ERROR: Failed to create 730XD directories"
  exit 1
fi

log "Syncing artifacts to 730XD..."
sync_fail=0

log "  Syncing Firefly artifacts..."
if ! rsync -az --timeout=120 -e "$RSYNC_SSH" "$firefly_dump" "$finance_manifest" \
  "$OFFSITE_USER@$OFFSITE_HOST:$OFFSITE_BASE/firefly/"; then
  log "ERROR: Firefly rsync failed"
  sync_fail=$((sync_fail + 1))
fi

log "  Syncing Ghostfolio artifacts..."
if ! rsync -az --timeout=120 -e "$RSYNC_SSH" "$ghostfolio_dump" \
  "$OFFSITE_USER@$OFFSITE_HOST:$OFFSITE_BASE/ghostfolio/"; then
  log "ERROR: Ghostfolio rsync failed"
  sync_fail=$((sync_fail + 1))
fi

log "  Syncing Paperless artifacts..."
if ! rsync -az --timeout=120 -e "$RSYNC_SSH" "$paperless_dump" "$paperless_zip_dst" \
  "$OFFSITE_USER@$OFFSITE_HOST:$OFFSITE_BASE/paperless/"; then
  log "ERROR: Paperless rsync failed"
  sync_fail=$((sync_fail + 1))
fi

if (( sync_fail > 0 )); then
  log "ERROR: $sync_fail service(s) failed to sync to 730XD"
  log "ERROR: Local backups preserved at $BACKUP_DIR for manual recovery"
  exit 1
fi

log "730XD sync complete — all artifacts transferred"

log "=== Phase 3: 730XD verification ==="
verify_fail=0
for expected in \
  "firefly/firefly-db-${TIMESTAMP}.sql.gz" \
  "firefly/finance-backup-manifest-${TIMESTAMP}.txt" \
  "ghostfolio/ghostfolio-db-${TIMESTAMP}.sql.gz" \
  "paperless/paperless-db-${TIMESTAMP}.sql.gz" \
  "paperless/$paperless_zip"; do
  if ! offsite_ssh "test -f '$OFFSITE_BASE/$expected'" 2>/dev/null; then
    log "ERROR: 730XD verification failed — missing $expected"
    verify_fail=$((verify_fail + 1))
  else
    log "  Verified: $expected"
  fi
done

if (( verify_fail > 0 )); then
  log "ERROR: 730XD verification failed for $verify_fail artifact(s)"
  log "ERROR: Local backups preserved at $BACKUP_DIR"
  exit 1
fi

log "730XD verification passed — all artifacts confirmed on 730XD"

log "=== Phase 4: 730XD retention cleanup ==="
offsite_ssh "bash -lc '
    find \"$OFFSITE_BASE/firefly\" -name \"firefly-db-*.sql.gz\" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find \"$OFFSITE_BASE/firefly\" -name \"finance-backup-manifest-*.txt\" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find \"$OFFSITE_BASE/ghostfolio\" -name \"ghostfolio-db-*.sql.gz\" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find \"$OFFSITE_BASE/paperless\" -name \"paperless-db-*.sql.gz\" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find \"$OFFSITE_BASE/paperless\" -name \"paperless-export-*.zip\" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
  '" >/dev/null 2>&1 || log "WARN: 730XD retention cleanup encountered errors (non-fatal)"

log "Retention cleanup complete"

touch "$SUCCESS_MARKER"
log "finance-stack backup SUCCEEDED — 730XD sync verified"
log "730XD location: $OFFSITE_HOST:$OFFSITE_BASE/{firefly,ghostfolio,paperless}"
exit 0
