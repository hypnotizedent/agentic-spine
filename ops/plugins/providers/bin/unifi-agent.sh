#!/usr/bin/env bash
set -euo pipefail
TARGET="${WORKBENCH_ROOT:-$HOME/code/workbench}/scripts/agents/unifi-agent.sh"
[[ -f "$TARGET" ]] || { echo "ERROR: workbench unifi agent missing: $TARGET" >&2; exit 1; }
exec bash "$TARGET" "$@"
