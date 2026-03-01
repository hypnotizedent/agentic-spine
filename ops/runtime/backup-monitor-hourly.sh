#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: backup monitor and governed alert intent enqueue
# LaunchAgent: com.ronny.backup-monitor-hourly

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
# Default scheduled backup probes to passive mode to avoid interactive tailscale
# browser auth prompts on operator workstations.
export VERIFY_TAILSCALE_PROBE_MODE="${VERIFY_TAILSCALE_PROBE_MODE:-passive}"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[backup-monitor-hourly] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "backup-monitor-hourly:backup.posture.snapshot.build" \
  "$CAP_RUNNER" cap run backup.posture.snapshot.build

spine_job_run \
  "backup-monitor-hourly:backup.monitor" \
  "$CAP_RUNNER" cap run backup.monitor --json

echo "[backup-monitor-hourly] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
