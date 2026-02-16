#!/usr/bin/env bash
set -euo pipefail
TARGET="${WORKBENCH_ROOT:-$HOME/code/workbench}/scripts/agents/legacy-freeze.sh"
[[ -f "$TARGET" ]] || { echo "ERROR: workbench legacy-freeze missing: $TARGET" >&2; exit 1; }
exec bash "$TARGET" "$@"
