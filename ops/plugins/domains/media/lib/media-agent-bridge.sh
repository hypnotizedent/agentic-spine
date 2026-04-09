#!/usr/bin/env bash
# Thin shim — canonical source is now in workbench repo.
# Source the canonical copy instead of this file.
MEDIA_TARGET_REPO="${MEDIA_TARGET_REPO:-/Users/ronnyworks/code/workbench}"
source "$MEDIA_TARGET_REPO/agents/media/tools/spine-plugin-media/lib/media-agent-bridge.sh"
