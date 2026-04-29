#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../lib/runtime-managed-worktree.sh"
CONTROL_ROOT="$(spine_runtime_resolve_control_root "${BASH_SOURCE[0]}")"
spine_runtime_activate_managed_worktree "$CONTROL_ROOT"
RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"
source "${RUNTIME_ROOT}/ops/lib/job-wrapper.sh"

echo "[rag-direct-incremental-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[rag-direct-incremental-daily] control_root=${CONTROL_ROOT}"
echo "[rag-direct-incremental-daily] runtime_root=${RUNTIME_ROOT}"
echo "[rag-direct-incremental-daily] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

spine_job_run \
  "rag-direct-incremental-daily:rag.direct.index" \
  "${RUNTIME_ROOT}/bin/ops" cap run rag.direct.index -- --changed-only --chunk-mode source_card --batch-size 1 --embed-batch-size 1 --progress-every 1 --pace-sec 1

echo "[rag-direct-incremental-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
