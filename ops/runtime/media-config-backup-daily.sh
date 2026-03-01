#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: media config-state backup (download + streaming)
# LaunchAgent: com.ronny.media-config-backup-daily
# Scope: config/db metadata only (payload media excluded)

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[media-config-backup-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "media-config-backup-daily:media.backup.create.legacy" \
  "${SPINE_ROOT}/ops/plugins/media/bin/media-backup-create.legacy" \
  --retention 14

spine_job_run \
  "media-config-backup-daily:backup.monitor" \
  "$CAP_RUNNER" cap run backup.monitor

echo "[media-config-backup-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
