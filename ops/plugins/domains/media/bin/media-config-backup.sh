#!/usr/bin/env bash
# media-home config cold-sync job
set -euo pipefail

# Repo plugin scripts must resolve spine paths when run from a checkout.
# This script is also deployed to /usr/local/bin on media-home, so keep the
# source/init optional when the repo tree is not present there.
SPINE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." 2>/dev/null && pwd || true)}"
if [[ -n "${SPINE_ROOT:-}" && -f "${SPINE_ROOT}/ops/lib/spine-paths.sh" ]]; then
  source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
  spine_paths_init
fi

BACKUP_ROOT="${BACKUP_ROOT:-/srv/appdata/backups/media-config}"
REMOTE_HOST="${REMOTE_HOST:-100.96.211.33}"
REMOTE_PATH="${REMOTE_PATH:-/md1400/backup-cold/apps/media-config/media-home}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
LOG_PREFIX="[media-config-backup]"

[[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || {
  echo "$LOG_PREFIX retention_days must be numeric" >&2
  exit 1
}

timestamp="$(date +%Y%m%d-%H%M%S)"
archive_path="${BACKUP_ROOT}/media-home-config-${timestamp}.tar.gz"
paths=(
  "/srv/appdata/compose/media-write/volumes"
  "/srv/appdata/compose/media-playback/volumes"
  "/srv/appdata/opt-appdata"
)
excludes=(
  "srv/media"
  "srv/appdata/compose/media-write/volumes/*/cache"
  "srv/appdata/compose/media-write/volumes/*/tmp"
  "srv/appdata/compose/media-playback/volumes/*/cache"
  "srv/appdata/compose/media-playback/volumes/*/tmp"
)

mkdir -p "$BACKUP_ROOT"

include_paths=()
for path in "${paths[@]}"; do
  [[ -e "$path" ]] && include_paths+=("${path#/}")
done

if [[ "${#include_paths[@]}" -eq 0 ]]; then
  echo "$LOG_PREFIX no include paths found" >&2
  exit 2
fi

tar_args=()
for pattern in "${excludes[@]}"; do
  tar_args+=(--exclude="$pattern")
done

echo "$LOG_PREFIX archive ${archive_path}"
tar "${tar_args[@]}" -czf "$archive_path" -C / "${include_paths[@]}"
find "$BACKUP_ROOT" -maxdepth 1 -type f -name 'media-home-config-*.tar.gz' -mtime +"$RETENTION_DAYS" -delete || true

ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "root@${REMOTE_HOST}" "mkdir -p '${REMOTE_PATH}'"
rsync -az --chmod=F644,D755 -e "ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  "$archive_path" "root@${REMOTE_HOST}:${REMOTE_PATH}/"
ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "root@${REMOTE_HOST}" "find '${REMOTE_PATH}' -maxdepth 1 -type f -name 'media-home-config-*.tar.gz' -mtime +${RETENTION_DAYS} -delete || true"

echo "$LOG_PREFIX done ${archive_path}"
