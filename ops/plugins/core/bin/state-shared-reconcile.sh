#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: SQLite shared authority self-heal reconcile.
# LaunchAgent: com.ronny.state-shared-reconcile

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../lib/runtime-managed-worktree.sh"
CONTROL_ROOT="$(spine_runtime_resolve_control_root "${BASH_SOURCE[0]}")"
spine_runtime_activate_managed_worktree "$CONTROL_ROOT"
RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"
CAP_RUNNER="${RUNTIME_ROOT}/bin/ops"
source "${RUNTIME_ROOT}/ops/lib/job-wrapper.sh"

echo "[state-shared-reconcile] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[state-shared-reconcile] control_root=${CONTROL_ROOT}"
echo "[state-shared-reconcile] runtime_root=${RUNTIME_ROOT}"
echo "[state-shared-reconcile] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

spine_job_run \
  "state-shared-reconcile:state.shared.reconcile" \
  "$CAP_RUNNER" cap run state.shared.reconcile -- --fix --json

echo "[state-shared-reconcile] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
