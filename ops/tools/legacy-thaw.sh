#!/usr/bin/env bash
set -euo pipefail
TARGET="${WORKBENCH_ROOT:-$HOME/code/workbench}/scripts/agents/legacy-thaw.sh"
[[ -f "$TARGET" ]] || { echo "ERROR: workbench legacy-thaw missing: $TARGET" >&2; exit 1; }
exec bash "$TARGET" "$@"
