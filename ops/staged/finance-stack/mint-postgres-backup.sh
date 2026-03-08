#!/usr/bin/env bash
# mint-postgres-backup.sh - App-level backup for VM 212 Mint Postgres
# DESTINATION: 730XD canonical backup plane (/md1400/backup-cold/apps/mint-data/postgres/)
# GOVERNANCE: tier1_critical backup with 730XD offsite sync verification
set -euo pipefail

STACK_DIR="/opt/stacks/mint-data"
BACKUP_STAGING="/mnt/backups/mint-postgres/staging"
BACKUP_ARCHIVE="/mnt/backups/mint-postgres/last-good"
OFFSITE_USER="root"
OFFSITE_HOST="pve"
OFFSITE_BASE="/md1400/backup-cold/apps/mint-data/postgres"
OFFSITE_IDENTITY_FILE="${OFFSITE_IDENTITY_FILE:-/home/ubuntu/.ssh/id_ed25519}"
RETENTION_DAYS=14
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
LOG_TAG="mint-postgres-backup"
SUCCESS_MARKER="$BACKUP_STAGING/.sync-success"
ALLOW_REGRESSION="${MINT_BACKUP_ALLOW_REGRESSION:-0}"
FAIL_COUNT=0

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

if [[ ! -f "$STACK_DIR/.env" ]]; then
  log "FAIL: missing $STACK_DIR/.env"
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$STACK_DIR/.env"
set +a

: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD missing in .env}"

PG_USER="${POSTGRES_USER:-mint}"
PG_DB="${POSTGRES_DB:-mint_modules}"
CONTAINER_NAME="mint-modules-postgres"

dump_db() {
  local db_name="$1"
  local db_user="$2"
  local db_pass="$3"
  local out_file="$4"
  if ! docker exec -e PGPASSWORD="$db_pass" "$CONTAINER_NAME" \
    pg_dump -U "$db_user" "$db_name" | gzip > "$out_file"; then
    log "ERROR: Database dump failed: $db_name"
    return 1
  fi
  return 0
}

db_scalar() {
  local db_name="$1"
  local db_user="$2"
  local db_pass="$3"
  local sql="$4"
  docker exec -e PGPASSWORD="$db_pass" "$CONTAINER_NAME" \
    psql -U "$db_user" -d "$db_name" -Atqc "$sql" 2>/dev/null | tr -d '[:space:]'
}

file_size_bytes() {
  local path="$1"
  stat -c %s "$path" 2>/dev/null || stat -f %z "$path" 2>/dev/null || echo 0
}

numeric_or_zero() {
  local value="${1:-}"
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "$value"
  else
    echo 0
  fi
}

manifest_get() {
  local manifest_path="$1"
  local key="$2"
  awk -F'=' -v k="$key" '$1 == k { print substr($0, index($0, "=") + 1) }' "$manifest_path" 2>/dev/null | tail -n1
}

write_manifest() {
  local manifest_path="$1"
  cat >"$manifest_path" <<EOF
timestamp=$TIMESTAMP
postgres_dump_bytes=$postgres_dump_bytes
postgres_db_cluster_bytes=$postgres_db_cluster_bytes
postgres_table_count=$postgres_table_count
postgres_total_rows=$postgres_total_rows
EOF
}

enforce_sanity_guard() {
  local current_manifest="$1"
  local previous_manifest="$2"
  local guard_fail=0

  sane_fail() {
    log "ERROR: Stateful sanity guard: $1"
    guard_fail=$((guard_fail + 1))
  }

  if (( postgres_db_cluster_bytes > 10485760 && postgres_dump_bytes < 131072 )); then
    sane_fail "Postgres dump is implausibly small (${postgres_dump_bytes} bytes) for cluster size ${postgres_db_cluster_bytes}"
  fi

  if (( postgres_table_count > 0 && postgres_total_rows == 0 )); then
    sane_fail "Postgres has ${postgres_table_count} tables but zero rows (possible empty-state)"
  fi

  if [[ -f "$previous_manifest" ]]; then
    prev_postgres_total_rows="$(numeric_or_zero "$(manifest_get "$previous_manifest" "postgres_total_rows")")"
    prev_postgres_table_count="$(numeric_or_zero "$(manifest_get "$previous_manifest" "postgres_table_count")")"

    if (( prev_postgres_total_rows > 1000 && postgres_total_rows == 0 )); then
      sane_fail "Postgres total rows regressed from ${prev_postgres_total_rows} to 0"
    fi

    if (( prev_postgres_table_count > 10 && postgres_table_count < prev_postgres_table_count / 2 )); then
      sane_fail "Postgres table count regressed from ${prev_postgres_table_count} to ${postgres_table_count}"
    fi
  fi

  if (( guard_fail > 0 )); then
    if [[ "$ALLOW_REGRESSION" == "1" ]]; then
      log "WARN: mint-postgres backup sanity guard override active (MINT_BACKUP_ALLOW_REGRESSION=1)"
    else
      return 1
    fi
  fi
}

log "=== mint-postgres-backup starting at $TIMESTAMP ==="
log "Target: $PG_DB @ $CONTAINER_NAME"
log "Destination: 730XD canonical backup plane ($OFFSITE_HOST:$OFFSITE_BASE)"

postgres_dump="$BACKUP_STAGING/mint-postgres-${TIMESTAMP}.sql.gz"
manifest_file="$BACKUP_STAGING/mint-postgres-manifest-${TIMESTAMP}.txt"
latest_manifest="$BACKUP_ARCHIVE/.latest-manifest.txt"

log "=== Phase 1: Database dump ==="
log "Starting Mint Postgres dump..."
if dump_db "$PG_DB" "$PG_USER" "$POSTGRES_PASSWORD" "$postgres_dump"; then
  log "Postgres dump complete: $(du -h "$postgres_dump" | cut -f1)"
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if (( FAIL_COUNT > 0 )); then
  log "ERROR: Phase 1 completed with $FAIL_COUNT failure(s) — aborting before 730XD sync"
  exit 1
fi

log "=== Phase 1b: Backup sanity guard ==="
postgres_dump_bytes="$(numeric_or_zero "$(file_size_bytes "$postgres_dump")")"
postgres_db_cluster_bytes="$(numeric_or_zero "$(db_scalar "$PG_DB" "$PG_USER" "$POSTGRES_PASSWORD" "select pg_database_size(current_database());")")"
postgres_table_count="$(numeric_or_zero "$(db_scalar "$PG_DB" "$PG_USER" "$POSTGRES_PASSWORD" "select count(*) from information_schema.tables where table_schema = 'public';")")"
postgres_total_rows="$(numeric_or_zero "$(db_scalar "$PG_DB" "$PG_USER" "$POSTGRES_PASSWORD" "select sum(n_live_tup) from pg_stat_user_tables;")")"

write_manifest "$manifest_file"
if ! enforce_sanity_guard "$manifest_file" "$latest_manifest"; then
  log "ERROR: Backup sanity guard failed — refusing to promote possibly empty-state artifacts"
  log "ERROR: Set MINT_BACKUP_ALLOW_REGRESSION=1 only for audited break-glass backups"
  exit 1
fi
log "Backup sanity guard passed"

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
for artifact in "$postgres_dump" "$manifest_file"; do
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
  "mint-postgres-${TIMESTAMP}.sql.gz" \
  "mint-postgres-manifest-${TIMESTAMP}.txt"; do
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

log "=== Phase 4: 730XD retention cleanup ==="
offsite_ssh "bash -lc '
    find \"$OFFSITE_BASE\" -name \"mint-postgres-*.sql.gz\" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find \"$OFFSITE_BASE\" -name \"mint-postgres-manifest-*.txt\" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
  '" >/dev/null 2>&1 || log "WARN: 730XD retention cleanup encountered errors (non-fatal)"

log "Retention cleanup complete"

log "=== Success: Archiving local recovery point ==="
find "$BACKUP_ARCHIVE" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
cp -a "$BACKUP_STAGING"/* "$BACKUP_ARCHIVE"/
cp "$manifest_file" "$latest_manifest"
touch "$SUCCESS_MARKER"

log "mint-postgres backup SUCCEEDED — 730XD sync verified, local archive updated"
log "Local archive: $BACKUP_ARCHIVE"
log "730XD location: $OFFSITE_HOST:$OFFSITE_BASE"
exit 0
