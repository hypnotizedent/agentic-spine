#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: reconcile friction queue into matched/filed governed gaps.
# LaunchAgent: com.ronny.friction-reconcile

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../lib/runtime-managed-worktree.sh"
CONTROL_ROOT="$(spine_runtime_resolve_control_root "${BASH_SOURCE[0]}")"
spine_runtime_activate_managed_worktree "$CONTROL_ROOT"
RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"
CAP_RUNNER="${RUNTIME_ROOT}/bin/ops"
FRICTION_LOOP_ID="${FRICTION_RECONCILE_LOOP_ID:-LOOP-AGENT-FRICTION-QUEUE-OPERATIONS-20260302}"
source "${RUNTIME_ROOT}/ops/lib/job-wrapper.sh"

echo "[friction-reconcile] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[friction-reconcile] control_root=${CONTROL_ROOT}"
echo "[friction-reconcile] runtime_root=${RUNTIME_ROOT}"
echo "[friction-reconcile] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

spine_job_run \
  "friction-reconcile:friction.reconcile" \
  "$CAP_RUNNER" cap run friction.reconcile --loop-id "$FRICTION_LOOP_ID" --json

echo "[friction-reconcile] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
