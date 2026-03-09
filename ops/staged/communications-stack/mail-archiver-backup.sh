#!/usr/bin/env bash
# mail-archiver-backup.sh — Daily backup of mail-archiver DB + uploads WITH 730XD OFFSITE
# DESTINATION: 730XD canonical backup plane (/md1400/backup-cold/apps/communications/mail-archiver/)
# GOVERNANCE: Communications offsite doctrine (offsite verification required)
set -euo pipefail

BACKUP_DIR="/srv/mail-archiver/backups"
BACKUP_STAGING="$BACKUP_DIR/staging"
BACKUP_ARCHIVE="$BACKUP_DIR/last-good"
BACKUP_ARCHIVE_NEXT="$BACKUP_DIR/last-good.next"
BACKUP_ARCHIVE_PREV="$BACKUP_DIR/last-good.prev"
UPLOADS_DIR="/srv/mail-archiver/uploads"
OFFSITE_USER="root"
OFFSITE_HOST="pve"
OFFSITE_BASE="/md1400/backup-cold/apps/communications/mail-archiver"
OFFSITE_IDENTITY_FILE="${OFFSITE_IDENTITY_FILE:-/home/ubuntu/.ssh/id_ed25519}"
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
LOG_TAG="mail-archiver-backup"
SUCCESS_MARKER="$BACKUP_STAGING/.sync-success"
LOCK_FILE="/var/lock/mail-archiver-backup.lock"
MODE="backup"
TARGET_TIMESTAMP=""
LOCK_ACQUIRED=0
MANIFEST_ARTIFACT_DIR=""

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

declare -A METRICS=()

usage() {
  cat <<'EOF'
Usage:
  mail-archiver-backup.sh
  mail-archiver-backup.sh --rewrite-manifest-only [--timestamp <YYYY-MM-DDTHHMMSSZ>] [--artifact-dir <path>]

Modes:
  default                  Run pg_dump + uploads archive + schema-aware manifest + offsite sync.
  --rewrite-manifest-only  Rewrite the canonical manifest for the latest artifact set in the
                           selected artifact dir (default: last-good) and sync the refreshed
                           manifest to 730XD.
EOF
}

log() { logger -t "$LOG_TAG" "$*"; echo "[$(date -Iseconds)] $*"; }

offsite_ssh() {
  ssh "${OFFSITE_SSH_OPTS[@]}" "$OFFSITE_USER@$OFFSITE_HOST" "$@"
}

stat_bytes() {
  local path="$1"
  stat -c %s "$path" 2>/dev/null || stat -f %z "$path" 2>/dev/null || echo 0
}

extract_timestamp_from_path() {
  local path="$1"
  basename "$path" | sed -E 's/^mail-archiver-(db|uploads|manifest)-([0-9T:-]+Z)\..*$/\2/'
}

find_latest_artifact() {
  local pattern="$1"
  find "$BACKUP_ARCHIVE" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-
}

collect_manifest_metrics() {
  METRICS=()
  local line key value uploads_file_count

  while IFS=$'\t' read -r key value; do
    [[ -n "$key" ]] || continue
    METRICS["$key"]="$value"
  done < <(
    docker exec -i mail-archiver-db psql -U mailuser -d MailArchiver -v ON_ERROR_STOP=1 -F $'\t' -At <<'SQL'
SELECT 'schema_public_table_count', COUNT(*)::bigint::text
FROM information_schema.tables
WHERE table_schema = 'public'
UNION ALL
SELECT 'schema_mail_archiver_table_count', COUNT(*)::bigint::text
FROM information_schema.tables
WHERE table_schema = 'mail_archiver'
UNION ALL
SELECT 'public_ef_migrations_history_rows', COUNT(*)::bigint::text
FROM public."__EFMigrationsHistory"
UNION ALL
SELECT 'mail_archiver_archived_emails_rows', COUNT(*)::bigint::text
FROM mail_archiver."ArchivedEmails"
UNION ALL
SELECT 'mail_archiver_mail_accounts_rows', COUNT(*)::bigint::text
FROM mail_archiver."MailAccounts"
UNION ALL
SELECT 'mail_archiver_users_rows', COUNT(*)::bigint::text
FROM mail_archiver."Users";
SQL
  )

  uploads_file_count="$(find "$UPLOADS_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')"
  METRICS["uploads_file_count"]="${uploads_file_count:-0}"

  for required_key in \
    schema_public_table_count \
    schema_mail_archiver_table_count \
    public_ef_migrations_history_rows \
    mail_archiver_archived_emails_rows \
    mail_archiver_mail_accounts_rows \
    mail_archiver_users_rows \
    uploads_file_count; do
    [[ -n "${METRICS[$required_key]:-}" ]] || {
      log "ERROR: Missing manifest metric: $required_key"
      exit 1
    }
  done
}

write_manifest_file() {
  local manifest_path="$1"
  local artifact_timestamp="$2"
  local db_dump_path="$3"
  local uploads_archive_path="$4"
  local db_size uploads_size

  db_size="$(stat_bytes "$db_dump_path")"
  uploads_size=0
  if [[ -n "$uploads_archive_path" && -f "$uploads_archive_path" ]]; then
    uploads_size="$(stat_bytes "$uploads_archive_path")"
  fi

  cat > "$manifest_path" <<EOF
manifest_version=2
timestamp=$artifact_timestamp
metrics_source=live-db-query
db_dump_bytes=$db_size
uploads_archive_bytes=$uploads_size
schema_public_table_count=${METRICS[schema_public_table_count]}
schema_mail_archiver_table_count=${METRICS[schema_mail_archiver_table_count]}
public_ef_migrations_history_rows=${METRICS[public_ef_migrations_history_rows]}
mail_archiver_archived_emails_rows=${METRICS[mail_archiver_archived_emails_rows]}
mail_archiver_mail_accounts_rows=${METRICS[mail_archiver_mail_accounts_rows]}
mail_archiver_users_rows=${METRICS[mail_archiver_users_rows]}
uploads_file_count=${METRICS[uploads_file_count]}
EOF
}

sync_artifacts_to_offsite() {
  local artifact sync_fail=0

  log "=== Phase 2: 730XD offsite sync ==="
  log "Testing 730XD connectivity..."
  if ! offsite_ssh "echo 'connectivity OK'" >/dev/null 2>&1; then
    log "ERROR: Cannot reach 730XD at $OFFSITE_HOST — aborting sync"
    exit 1
  fi

  log "Ensuring 730XD backup directory exists..."
  if ! offsite_ssh "mkdir -p '$OFFSITE_BASE'" >/dev/null 2>&1; then
    log "ERROR: Failed to create 730XD directory"
    exit 1
  fi

  log "Syncing artifacts to 730XD..."
  for artifact in "$@"; do
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
    exit 1
  fi

  log "730XD sync complete — all artifacts transferred"
}

verify_offsite_artifacts() {
  local verify_fail=0 expected
  log "=== Phase 3: 730XD verification ==="
  for expected in "$@"; do
    if ! offsite_ssh "test -f '$OFFSITE_BASE/$expected'" 2>/dev/null; then
      log "ERROR: 730XD verification failed — missing $expected"
      verify_fail=$((verify_fail + 1))
    else
      log "  Verified: $expected"
    fi
  done

  if (( verify_fail > 0 )); then
    log "ERROR: 730XD verification failed for $verify_fail artifact(s)"
    exit 1
  fi

  log "730XD verification passed — all artifacts confirmed on 730XD"
}

perform_retention_cleanup() {
  log "=== Phase 4: Retention cleanup ==="
  offsite_ssh "bash -lc '
      find \"$OFFSITE_BASE\" -name \"mail-archiver-db-*.sql.gz\" -mtime +14 -delete 2>/dev/null || true
      find \"$OFFSITE_BASE\" -name \"mail-archiver-uploads-*.tar.gz\" -mtime +14 -delete 2>/dev/null || true
      find \"$OFFSITE_BASE\" -name \"mail-archiver-manifest-*.txt\" -mtime +14 -delete 2>/dev/null || true
    '" >/dev/null 2>&1 || log "WARN: 730XD retention cleanup encountered errors (non-fatal)"
  log "Retention cleanup complete"
}

acquire_lock() {
  exec 200>"$LOCK_FILE"
  if ! flock -n 200; then
    log "ERROR: Another backup is already running (lock file: $LOCK_FILE)"
    log "ERROR: If this is incorrect, remove $LOCK_FILE manually"
    exit 1
  fi
  echo $$ >&200
  LOCK_ACQUIRED=1
}

release_lock() {
  if [[ "$LOCK_ACQUIRED" == "1" ]]; then
    rm -f "$LOCK_FILE"
  fi
}

cleanup() {
  local exit_code=$?
  if [[ "$MODE" == "backup" && -f "$SUCCESS_MARKER" ]]; then
    log "730XD offsite sync verified — cleaning staging area"
    rm -rf "$BACKUP_STAGING"
  elif [[ "$MODE" == "backup" && $exit_code -ne 0 ]]; then
    log "ERROR: Backup failed (exit $exit_code) — preserving staging artifacts at $BACKUP_STAGING"
    log "ERROR: Most recent backup NOT synced to 730XD — manual intervention required"
  fi
  release_lock
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rewrite-manifest-only)
      MODE="manifest-only"
      shift
      ;;
    --timestamp)
      TARGET_TIMESTAMP="${2:?--timestamp requires a value}"
      shift 2
      ;;
    --artifact-dir)
      MANIFEST_ARTIFACT_DIR="${2:?--artifact-dir requires a value}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

install -d -m 755 "$BACKUP_STAGING" "$BACKUP_ARCHIVE"
rm -f "$SUCCESS_MARKER"

if [[ "$MODE" == "backup" ]]; then
  acquire_lock
fi

if [[ "$MODE" == "manifest-only" ]]; then
  artifact_dir="${MANIFEST_ARTIFACT_DIR:-$BACKUP_ARCHIVE}"
  local_db_dump=""
  if [[ -n "$TARGET_TIMESTAMP" ]]; then
    local_db_dump="$artifact_dir/mail-archiver-db-${TARGET_TIMESTAMP}.sql.gz"
  else
    local_db_dump="$(find "$artifact_dir" -maxdepth 1 -type f -name 'mail-archiver-db-*.sql.gz' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)"
  fi
  [[ -n "$local_db_dump" && -f "$local_db_dump" ]] || {
    log "ERROR: No matching DB dump found in $artifact_dir for manifest rewrite"
    exit 1
  }

  TIMESTAMP="$(extract_timestamp_from_path "$local_db_dump")"
  uploads_archive="$artifact_dir/mail-archiver-uploads-${TIMESTAMP}.tar.gz"
  manifest_file="$artifact_dir/mail-archiver-manifest-${TIMESTAMP}.txt"

  collect_manifest_metrics
  write_manifest_file "$manifest_file" "$TIMESTAMP" "$local_db_dump" "$uploads_archive"
  log "Rewrote schema-aware manifest $(basename "$manifest_file")"

  sync_artifacts_to_offsite "$manifest_file"
  verify_offsite_artifacts "$(basename "$manifest_file")"
  log "Manifest rewrite complete — local/offsite manifests refreshed"
  exit 0
fi

log "=== mail-archiver backup start (730XD offsite) ==="
log "Destination: 730XD canonical backup plane ($OFFSITE_HOST:$OFFSITE_BASE)"

DB_DUMP="$BACKUP_STAGING/mail-archiver-db-${TIMESTAMP}.sql.gz"
docker exec mail-archiver-db pg_dump -U mailuser MailArchiver 2>&1 | gzip > "$DB_DUMP"
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  log "FAIL: pg_dump failed"
  rm -f "$DB_DUMP"
  exit 1
fi
log "OK: DB dump created $(du -h "$DB_DUMP" | cut -f1)"

UPLOADS_ARCHIVE="$BACKUP_STAGING/mail-archiver-uploads-${TIMESTAMP}.tar.gz"
if [[ -d "$UPLOADS_DIR" ]]; then
  tar -czf "$UPLOADS_ARCHIVE" -C "$(dirname "$UPLOADS_DIR")" "$(basename "$UPLOADS_DIR")" 2>&1
  log "OK: uploads archive $(du -h "$UPLOADS_ARCHIVE" | cut -f1)"
else
  log "WARN: uploads dir not found, skipping"
fi

DB_SIZE="$(stat_bytes "$DB_DUMP")"
if (( DB_SIZE < 104857600 )); then
  log "WARN: DB dump is smaller than expected (${DB_SIZE} bytes), but proceeding"
fi

collect_manifest_metrics
MANIFEST_FILE="$BACKUP_STAGING/mail-archiver-manifest-${TIMESTAMP}.txt"
write_manifest_file "$MANIFEST_FILE" "$TIMESTAMP" "$DB_DUMP" "$UPLOADS_ARCHIVE"
log "Schema-aware manifest written $(basename "$MANIFEST_FILE")"

sync_artifacts_to_offsite "$DB_DUMP" "$UPLOADS_ARCHIVE" "$MANIFEST_FILE"
verify_offsite_artifacts \
  "mail-archiver-db-${TIMESTAMP}.sql.gz" \
  "mail-archiver-uploads-${TIMESTAMP}.tar.gz" \
  "mail-archiver-manifest-${TIMESTAMP}.txt"
perform_retention_cleanup

log "=== Success: Archiving local recovery point ==="
rm -rf "$BACKUP_ARCHIVE_NEXT" "$BACKUP_ARCHIVE_PREV"
install -d -m 755 "$BACKUP_ARCHIVE_NEXT"
cp -a "$BACKUP_STAGING"/* "$BACKUP_ARCHIVE_NEXT"/
if [[ -d "$BACKUP_ARCHIVE" ]]; then
  mv "$BACKUP_ARCHIVE" "$BACKUP_ARCHIVE_PREV"
fi
mv "$BACKUP_ARCHIVE_NEXT" "$BACKUP_ARCHIVE"
rm -rf "$BACKUP_ARCHIVE_PREV"
touch "$SUCCESS_MARKER"

log "mail-archiver backup SUCCEEDED — 730XD sync verified, local archive updated"
log "Local archive: $BACKUP_ARCHIVE"
log "730XD location: $OFFSITE_HOST:$OFFSITE_BASE"
exit 0
