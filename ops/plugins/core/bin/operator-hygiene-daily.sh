#!/usr/bin/env bash
set -euo pipefail

CONTROL_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)}"
source "${CONTROL_ROOT}/ops/lib/runtime-managed-worktree.sh"
spine_runtime_activate_managed_worktree "$CONTROL_ROOT"
RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"
source "${RUNTIME_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
CAP_RUNNER="${RUNTIME_ROOT}/bin/ops"
source "${RUNTIME_ROOT}/ops/lib/job-wrapper.sh"

echo "[operator-hygiene-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[operator-hygiene-daily] control_root=${CONTROL_ROOT}"
echo "[operator-hygiene-daily] runtime_root=${RUNTIME_ROOT}"
echo "[operator-hygiene-daily] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"
spine_job_run \
  "operator-hygiene-daily:operator.hygiene.reconcile" \
  "$CAP_RUNNER" cap run operator.hygiene.reconcile -- --execute
echo "[operator-hygiene-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
