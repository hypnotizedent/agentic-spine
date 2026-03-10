#!/usr/bin/env bash
set -euo pipefail
TARGET="${WORKBENCH_ROOT:-$HOME/code/workbench}/scripts/agents/cloudflare-agent.sh"
[[ -f "$TARGET" ]] || { echo "ERROR: workbench cloudflare agent missing: $TARGET" >&2; exit 1; }
exec bash "$TARGET" "$@"
