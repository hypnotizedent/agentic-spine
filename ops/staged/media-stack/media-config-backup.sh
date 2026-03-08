#!/usr/bin/env bash
# media-config-backup.sh - Create config-state archive and sync it to md1400
set -euo pipefail

STACK_NAME="${STACK_NAME:-$(hostname -s)}"
BACKUP_ROOT="/mnt/docker/backups/media-config"
STAGING_DIR="$BACKUP_ROOT/staging"
LAST_GOOD_DIR="$BACKUP_ROOT/last-good"
LOCK_FILE="/var/lock/${STACK_NAME}-media-config-backup.lock"
OFFSITE_USER="root"
OFFSITE_HOST="pve"
OFFSITE_BASE="/md1400/backup-cold/apps/media-config/${STACK_NAME}"
OFFSITE_IDENTITY_FILE="${OFFSITE_IDENTITY_FILE:-/root/.ssh/id_ed25519}"
RETENTION_DAYS=14
TIMESTAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"

declare -a INCLUDE_PATHS
case "$STACK_NAME" in
  download-stack)
    INCLUDE_PATHS=(
      /mnt/docker/volumes/radarr/config
      /mnt/docker/volumes/sonarr/config
      /mnt/docker/volumes/lidarr/config
      /mnt/docker/volumes/prowlarr/config
      /mnt/docker/volumes/sabnzbd/config
      /mnt/docker/volumes/qbittorrent/config
      /mnt/docker/volumes/recyclarr/config
      /mnt/docker/volumes/flaresolverr/config
      /mnt/docker/volumes/trailarr/config
      /mnt/docker/volumes/autopulse
      /opt/appdata/radarr
      /opt/appdata/sonarr
      /opt/appdata/lidarr
      /opt/appdata/prowlarr
      /opt/appdata/sabnzbd
      /opt/appdata/qbittorrent
      /opt/appdata/trailarr
    )
    ;;
  streaming-stack)
    INCLUDE_PATHS=(
      /mnt/docker/volumes/jellyfin/config
      /mnt/docker/volumes/navidrome/data
      /mnt/docker/volumes/jellyseerr/config
      /mnt/docker/volumes/bazarr/config
      /mnt/docker/volumes/homarr/configs
      /opt/appdata/jellyfin
      /opt/appdata/navidrome
      /opt/appdata/jellyseerr
      /opt/appdata/bazarr
    )
    ;;
  *)
    echo "FAIL: unsupported media stack hostname '$STACK_NAME'" >&2
    exit 1
    ;;
esac

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
  log "SKIP: media config backup already running for $STACK_NAME"
  exit 0
fi

RELATIVE_PATHS=()
for path in "${INCLUDE_PATHS[@]}"; do
  [[ -e "$path" ]] && RELATIVE_PATHS+=("${path#/}")
done

if [[ "${#RELATIVE_PATHS[@]}" -eq 0 ]]; then
  log "FAIL: no configured paths exist for $STACK_NAME"
  exit 1
fi

ARTIFACT="$STAGING_DIR/${STACK_NAME}-config-${TIMESTAMP}.tar.gz"
MANIFEST="$STAGING_DIR/${STACK_NAME}-config-${TIMESTAMP}.txt"
tar -czf "$ARTIFACT" -C / "${RELATIVE_PATHS[@]}"

{
  echo "timestamp_utc=$TIMESTAMP"
  echo "stack=$STACK_NAME"
  echo "include_count=${#RELATIVE_PATHS[@]}"
  for rel in "${RELATIVE_PATHS[@]}"; do
    echo "include=$rel"
  done
} >"$MANIFEST"

offsite_ssh "mkdir -p '$OFFSITE_BASE'"
rsync -a --partial --inplace --timeout=120 -e "$RSYNC_SSH" "$ARTIFACT" "$MANIFEST" "$OFFSITE_USER@$OFFSITE_HOST:$OFFSITE_BASE/"
offsite_ssh "test -f '$OFFSITE_BASE/$(basename "$ARTIFACT")'"

find "$LAST_GOOD_DIR" -mindepth 1 -maxdepth 1 -type f -delete 2>/dev/null || true
cp -a "$ARTIFACT" "$MANIFEST" "$LAST_GOOD_DIR/"

find "$STAGING_DIR" -maxdepth 1 -type f -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
offsite_ssh "find '$OFFSITE_BASE' -maxdepth 1 -type f \\( -name '${STACK_NAME}-config-*.tar.gz' -o -name '${STACK_NAME}-config-*.txt' \\) -mtime +$RETENTION_DAYS -delete 2>/dev/null || true"

log "OK: synced $(basename "$ARTIFACT") to $OFFSITE_HOST:$OFFSITE_BASE"
