#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: daily briefing at 08:00
# LaunchAgent: com.ronny.spine-daily-briefing
# Gaps: GAP-OP-735

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[spine-daily-briefing] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "spine-daily-briefing:spine.briefing" \
  "$CAP_RUNNER" cap run spine.briefing --json

echo "[spine-daily-briefing] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
