#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
ARCHIVER="${SPINE_ROOT}/ops/plugins/proposals/bin/proposals-archive"

if [[ ! -x "$ARCHIVER" ]]; then
  echo "[proposals-retention-daily] missing archiver: $ARCHIVER" >&2
  exit 2
fi

echo "[proposals-retention-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
"$ARCHIVER"
echo "[proposals-retention-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
