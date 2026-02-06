#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-/Users/ronnyworks/ronny-ops}"
STATE_DIR="${HOME}/.config/agentic-spine"
STATE_FILE="${STATE_DIR}/legacy-freeze.state"

if [[ ! -d "$TARGET" ]]; then
  echo "legacy-freeze: target missing: $TARGET" >&2
  exit 1
fi

mkdir -p "$STATE_DIR"

cat >"$STATE_FILE" <<EOF
frozen_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
target=$TARGET
operator=${USER}
EOF

# Freeze write access while preserving read/execute behavior.
find "$TARGET" -type d -exec chmod ugo-w {} +
find "$TARGET" -type f -exec chmod ugo-w {} +

echo "legacy-freeze: read-only freeze applied to $TARGET"
echo "state: $STATE_FILE"
