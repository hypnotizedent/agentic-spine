#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: daily briefing at 08:00
# LaunchAgent: com.ronny.spine-daily-briefing
# Gaps: GAP-OP-735

CONTROL_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)}"
source "${CONTROL_ROOT}/ops/lib/runtime-managed-worktree.sh"
spine_runtime_activate_managed_worktree "$CONTROL_ROOT"
RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"
CAP_RUNNER="${RUNTIME_ROOT}/bin/ops"
source "${RUNTIME_ROOT}/ops/lib/job-wrapper.sh"

echo "[spine-daily-briefing] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[spine-daily-briefing] control_root=${CONTROL_ROOT}"
echo "[spine-daily-briefing] runtime_root=${RUNTIME_ROOT}"
echo "[spine-daily-briefing] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

spine_job_run \
  "spine-daily-briefing:spine.briefing" \
  "$CAP_RUNNER" cap run spine.briefing --json

echo "[spine-daily-briefing] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
