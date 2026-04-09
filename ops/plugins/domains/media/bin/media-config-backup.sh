#!/usr/bin/env bash
# Thin shim — canonical source is now in workbench media tooling.
set -euo pipefail
export SECONDARY_REMOTE_PATH="${SECONDARY_REMOTE_PATH:-/md1400/backups/configs/media-config/media-home}"
exec "${MEDIA_TARGET_REPO:-/Users/ronnyworks/code/workbench/agents/media/tools/spine-plugin-media/bin}/media-config-backup.sh" "$@"
