#!/usr/bin/env bash
# Thin shim — canonical source is now in projects/media.
# Source the canonical copy instead of this file.
MEDIA_PROJECT_ROOT="${MEDIA_PROJECT_ROOT:-/Users/ronnyworks/code/projects/media}"
source "$MEDIA_PROJECT_ROOT/tools/spine-plugin-media/lib/media-agent-bridge.sh"
