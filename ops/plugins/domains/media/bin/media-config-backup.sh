#!/usr/bin/env bash
# Thin shim — canonical source is now in projects/media.
set -euo pipefail
export SECONDARY_REMOTE_PATH="${SECONDARY_REMOTE_PATH:-/md1400/backups/configs/media-config/media-home}"
exec "/Users/ronnyworks/code/projects/media/tools/spine-plugin-media/bin/media-config-backup.sh" "$@"
