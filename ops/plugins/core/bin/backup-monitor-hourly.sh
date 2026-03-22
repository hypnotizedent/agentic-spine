#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: backup monitor and governed alert intent enqueue
# LaunchAgent: com.ronny.backup-monitor-hourly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../lib/runtime-managed-worktree.sh"
CONTROL_ROOT="$(spine_runtime_resolve_control_root "${BASH_SOURCE[0]}")"
spine_runtime_activate_managed_worktree "$CONTROL_ROOT"
RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"
CAP_RUNNER="${RUNTIME_ROOT}/bin/ops"
# Default scheduled backup probes to passive mode to avoid interactive tailscale
# browser auth prompts on operator workstations.
export VERIFY_TAILSCALE_PROBE_MODE="${VERIFY_TAILSCALE_PROBE_MODE:-passive}"
source "${RUNTIME_ROOT}/ops/lib/job-wrapper.sh"

echo "[backup-monitor-hourly] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[backup-monitor-hourly] control_root=${CONTROL_ROOT}"
echo "[backup-monitor-hourly] runtime_root=${RUNTIME_ROOT}"
echo "[backup-monitor-hourly] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

spine_job_run \
  "backup-monitor-hourly:backup.posture.snapshot.build" \
  "$CAP_RUNNER" cap run backup.posture.snapshot.build

spine_job_run \
  "backup-monitor-hourly:backup.monitor" \
  "$CAP_RUNNER" cap run backup.monitor --json

echo "[backup-monitor-hourly] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
