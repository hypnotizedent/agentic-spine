#!/usr/bin/env bash
# media-home config primary archive plus cold-copy sync
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
SSH_TARGETS_FILE="${SSH_TARGETS_FILE:-${SPINE_ROOT:-$HOME/code/agentic-spine}/ops/bindings/ssh.targets.yaml}"
PRIMARY_TARGET_ID="${PRIMARY_TARGET_ID:-nas}"
SECONDARY_TARGET_ID="${SECONDARY_TARGET_ID:-pve}"
PRIMARY_REMOTE_PATH="${PRIMARY_REMOTE_PATH:-/volume1/backups/apps/media-config/media-home}"
SECONDARY_REMOTE_PATH="${SECONDARY_REMOTE_PATH:-/md1400/backup-cold/apps/media-config/media-home}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
LOG_PREFIX="[media-config-backup]"

[[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || {
  echo "$LOG_PREFIX retention_days must be numeric" >&2
  exit 1
}

resolve_target() {
  local target_id="$1"
  local field="$2"
  if [[ -f "$SSH_TARGETS_FILE" ]] && command -v yq >/dev/null 2>&1; then
    yq -r ".ssh.targets[] | select(.id == \"${target_id}\") | .${field} // \"\"" "$SSH_TARGETS_FILE" | head -n1
    return 0
  fi
  case "$target_id" in
    nas)
      case "$field" in
        host) echo "100.102.199.111" ;;
        user) echo "ronadmin" ;;
        port) echo "22" ;;
      esac
      ;;
    pve)
      case "$field" in
        host) echo "100.96.211.33" ;;
        user) echo "root" ;;
        port) echo "22" ;;
      esac
      ;;
    *)
      echo ""
      ;;
  esac
}

PRIMARY_HOST="$(resolve_target "$PRIMARY_TARGET_ID" host)"
PRIMARY_USER="$(resolve_target "$PRIMARY_TARGET_ID" user)"
PRIMARY_PORT="$(resolve_target "$PRIMARY_TARGET_ID" port)"
SECONDARY_HOST="$(resolve_target "$SECONDARY_TARGET_ID" host)"
SECONDARY_USER="$(resolve_target "$SECONDARY_TARGET_ID" user)"
SECONDARY_PORT="$(resolve_target "$SECONDARY_TARGET_ID" port)"

PRIMARY_PORT="${PRIMARY_PORT:-22}"
SECONDARY_PORT="${SECONDARY_PORT:-22}"
PRIMARY_USER="${PRIMARY_USER:-root}"
SECONDARY_USER="${SECONDARY_USER:-root}"

[[ -n "$PRIMARY_HOST" ]] || {
  echo "$LOG_PREFIX missing SSH target: $PRIMARY_TARGET_ID" >&2
  exit 2
}
[[ -n "$SECONDARY_HOST" ]] || {
  echo "$LOG_PREFIX missing SSH target: $SECONDARY_TARGET_ID" >&2
  exit 2
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

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
PRIMARY_SSH="${PRIMARY_USER}@${PRIMARY_HOST}"
SECONDARY_SSH="${SECONDARY_USER}@${SECONDARY_HOST}"

ssh "${SSH_OPTS[@]}" -p "$PRIMARY_PORT" "$PRIMARY_SSH" "mkdir -p '${PRIMARY_REMOTE_PATH}'"
rsync -az --chmod=F644,D755 -e "ssh ${SSH_OPTS[*]} -p ${PRIMARY_PORT}" \
  "$archive_path" "${PRIMARY_SSH}:${PRIMARY_REMOTE_PATH}/"
ssh "${SSH_OPTS[@]}" -p "$PRIMARY_PORT" "$PRIMARY_SSH" "find '${PRIMARY_REMOTE_PATH}' -maxdepth 1 -type f -name 'media-home-config-*.tar.gz' -mtime +${RETENTION_DAYS} -delete || true"

ssh "${SSH_OPTS[@]}" -p "$SECONDARY_PORT" "$SECONDARY_SSH" "mkdir -p '${SECONDARY_REMOTE_PATH}'"
rsync -az --chmod=F644,D755 -e "ssh ${SSH_OPTS[*]} -p ${SECONDARY_PORT}" \
  "$archive_path" "${SECONDARY_SSH}:${SECONDARY_REMOTE_PATH}/"
ssh "${SSH_OPTS[@]}" -p "$SECONDARY_PORT" "$SECONDARY_SSH" "find '${SECONDARY_REMOTE_PATH}' -maxdepth 1 -type f -name 'media-home-config-*.tar.gz' -mtime +${RETENTION_DAYS} -delete || true"

echo "$LOG_PREFIX done ${archive_path}"
