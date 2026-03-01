#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: refresh media capacity runway snapshot projection.
# LaunchAgent: com.ronny.media-capacity-snapshot-daily

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[media-capacity-snapshot-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "media-capacity-snapshot-daily:media.capacity.snapshot.build" \
  "$CAP_RUNNER" cap run media.capacity.snapshot.build

echo "[media-capacity-snapshot-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
