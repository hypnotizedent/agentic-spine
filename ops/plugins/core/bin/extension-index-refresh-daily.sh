#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: extension transaction index refresh
# LaunchAgent template: com.ronny.extension-index-refresh-daily
# W69 freshness recovery: D178

CONTROL_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)}"
source "${CONTROL_ROOT}/ops/lib/runtime-managed-worktree.sh"
spine_runtime_activate_managed_worktree "$CONTROL_ROOT"
RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"
CAP_RUNNER="$RUNTIME_ROOT/bin/ops"
source "${RUNTIME_ROOT}/ops/lib/job-wrapper.sh"

echo "[extension-index-refresh-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[extension-index-refresh-daily] control_root=${CONTROL_ROOT}"
echo "[extension-index-refresh-daily] runtime_root=${RUNTIME_ROOT}"
echo "[extension-index-refresh-daily] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

spine_job_run \
  "extension-index-refresh-daily:platform.extension.index.build" \
  "$CAP_RUNNER" cap run platform.extension.index.build

echo "[extension-index-refresh-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
