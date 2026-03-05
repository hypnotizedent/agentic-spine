#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
ARCHIVER="${SPINE_ROOT}/ops/plugins/proposals/bin/proposals-archive"
OUTBOX_RETENTION="${SPINE_ROOT}/ops/plugins/mailroom-bridge/bin/mailroom-outbox-retention"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

if [[ ! -x "$ARCHIVER" ]]; then
  echo "[proposals-retention-daily] missing archiver: $ARCHIVER" >&2
  exit 2
fi
if [[ ! -x "$OUTBOX_RETENTION" ]]; then
  echo "[proposals-retention-daily] missing outbox retention binary: $OUTBOX_RETENTION" >&2
  exit 2
fi

echo "[proposals-retention-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
spine_job_run "proposals-retention-daily:proposals-archive" "$ARCHIVER"
spine_job_run "proposals-retention-daily:outbox-retention" "$OUTBOX_RETENTION" --execute
echo "[proposals-retention-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
