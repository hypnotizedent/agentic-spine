#!/usr/bin/env bash
# n8n-workflows-backup.sh - Package latest n8n snapshot and sync it to md1400
set -euo pipefail

SNAPSHOT_ROOT="/home/automation/backups/n8n-workflows"
WORK_ROOT="/home/automation/backups/n8n-cold-sync"
STAGING_DIR="$WORK_ROOT/staging"
LAST_GOOD_DIR="$WORK_ROOT/last-good"
LOCK_FILE="$WORK_ROOT/.n8n-workflows-backup.lock"
OFFSITE_USER="root"
OFFSITE_HOST="pve"
OFFSITE_BASE="/md1400/backup-cold/apps/infra-core/n8n"
OFFSITE_IDENTITY_FILE="${OFFSITE_IDENTITY_FILE:-/home/automation/.ssh/id_ed25519}"
RETENTION_DAYS=14
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"

SSH_OPTS=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -o ConnectTimeout=20
)
if [[ -n "$OFFSITE_IDENTITY_FILE" && -r "$OFFSITE_IDENTITY_FILE" ]]; then
  SSH_OPTS+=(-i "$OFFSITE_IDENTITY_FILE")
fi
printf -v RSYNC_SSH '%q ' ssh "${SSH_OPTS[@]}"
RSYNC_SSH="${RSYNC_SSH% }"

log() { echo "[$(date -Iseconds)] $*"; }
offsite_ssh() { ssh "${SSH_OPTS[@]}" "$OFFSITE_USER@$OFFSITE_HOST" "$@"; }

mkdir -p "$STAGING_DIR" "$LAST_GOOD_DIR"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "SKIP: n8n workflow cold sync already running"
  exit 0
fi

LATEST_DIR="$(find "$SNAPSHOT_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
if [[ -z "$LATEST_DIR" || ! -d "$LATEST_DIR" ]]; then
  log "FAIL: no n8n snapshot directory found under $SNAPSHOT_ROOT"
  exit 1
fi

WORKFLOW_COUNT="$(find "$LATEST_DIR" -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' ')"
if [[ "$WORKFLOW_COUNT" -eq 0 ]]; then
  log "FAIL: latest n8n snapshot has zero workflow JSON files: $LATEST_DIR"
  exit 1
fi

ARTIFACT="$STAGING_DIR/n8n-workflows-${TIMESTAMP}.tar.gz"
MANIFEST="$STAGING_DIR/n8n-workflows-${TIMESTAMP}.txt"
tar -czf "$ARTIFACT" -C "$(dirname "$LATEST_DIR")" "$(basename "$LATEST_DIR")"

{
  echo "timestamp_utc=$TIMESTAMP"
  echo "source_snapshot=$(basename "$LATEST_DIR")"
  echo "workflow_count=$WORKFLOW_COUNT"
} >"$MANIFEST"

offsite_ssh "mkdir -p '$OFFSITE_BASE'"
rsync -a --partial --inplace --timeout=120 -e "$RSYNC_SSH" "$ARTIFACT" "$MANIFEST" "$OFFSITE_USER@$OFFSITE_HOST:$OFFSITE_BASE/"
offsite_ssh "test -f '$OFFSITE_BASE/$(basename "$ARTIFACT")'"

find "$LAST_GOOD_DIR" -mindepth 1 -maxdepth 1 -type f -delete 2>/dev/null || true
cp -a "$ARTIFACT" "$MANIFEST" "$LAST_GOOD_DIR/"

find "$STAGING_DIR" -maxdepth 1 -type f -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
offsite_ssh "find '$OFFSITE_BASE' -maxdepth 1 -type f \\( -name 'n8n-workflows-*.tar.gz' -o -name 'n8n-workflows-*.txt' \\) -mtime +$RETENTION_DAYS -delete 2>/dev/null || true"

log "OK: synced $(basename "$ARTIFACT") to $OFFSITE_HOST:$OFFSITE_BASE"
