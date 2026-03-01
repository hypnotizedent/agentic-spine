#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
ROTATE_SCRIPT="${SPINE_ROOT}/ops/plugins/lifecycle/bin/launchd-log-rotate"
LOG_DIR="${SPINE_ROOT}/mailroom/logs"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] log-rotation-daily starting"

if [[ ! -x "$ROTATE_SCRIPT" ]]; then
    echo "[log-rotation-daily] ERROR: rotate script not found: $ROTATE_SCRIPT" >&2
    exit 1
fi

"$ROTATE_SCRIPT" --max-bytes 5242880 --keep 3

# Also clean empty rotated files older than 7 days
find "$LOG_DIR" -name "*.out.[0-9]*" -empty -mtime +7 -delete 2>/dev/null || true
find "$LOG_DIR" -name "*.err.[0-9]*" -empty -mtime +7 -delete 2>/dev/null || true

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] log-rotation-daily complete"
