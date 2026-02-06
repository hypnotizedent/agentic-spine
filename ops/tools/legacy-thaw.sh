#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-/Users/ronnyworks/ronny-ops}"
STATE_FILE="${HOME}/.config/agentic-spine/legacy-freeze.state"
CONFIRM="${2:-}"

if [[ "$CONFIRM" != "--confirm" ]]; then
  echo "usage: $0 [target] --confirm" >&2
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "legacy-thaw: target missing: $TARGET" >&2
  exit 1
fi

# Restore owner write bit. Group/other write remain disabled.
find "$TARGET" -type d -exec chmod u+w {} +
find "$TARGET" -type f -exec chmod u+w {} +

if [[ -f "$STATE_FILE" ]]; then
  rm -f "$STATE_FILE"
fi

echo "legacy-thaw: owner write restored for $TARGET"
