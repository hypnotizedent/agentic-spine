#!/usr/bin/env bash
# Thin shim — canonical source is now in media-domain repo.
# Source the canonical copy instead of this file.
MEDIA_TARGET_REPO="${MEDIA_TARGET_REPO:-/Users/ronnyworks/code/media-domain}"
source "$MEDIA_TARGET_REPO/scripts/lib/media-agent-bridge.sh"
