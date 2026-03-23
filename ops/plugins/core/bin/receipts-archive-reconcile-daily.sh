#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../lib/runtime-managed-worktree.sh"
CONTROL_ROOT="$(spine_runtime_resolve_control_root "${BASH_SOURCE[0]}")"
spine_runtime_activate_managed_worktree "$CONTROL_ROOT"
RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"
INDEX_BUILD="$RUNTIME_ROOT/ops/plugins/core/evidence/bin/receipts-index-build"
ROTATE_CMD="$RUNTIME_ROOT/ops/plugins/core/evidence/bin/receipts-rotate"
MAILROOM_LOG_ROTATE="$RUNTIME_ROOT/ops/plugins/core/lifecycle/bin/mailroom-log-rotate"
LAUNCHD_LOG_ROTATE="$RUNTIME_ROOT/ops/plugins/core/lifecycle/bin/launchd-log-rotate"
CHECKSUM="$RUNTIME_ROOT/ops/plugins/core/evidence/bin/receipts-checksum-parity-report"
source "${RUNTIME_ROOT}/ops/lib/job-wrapper.sh"

echo "[receipts-archive-reconcile-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[receipts-archive-reconcile-daily] control_root=${CONTROL_ROOT}"
echo "[receipts-archive-reconcile-daily] runtime_root=${RUNTIME_ROOT}"
echo "[receipts-archive-reconcile-daily] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

spine_job_run "receipts-archive-reconcile-daily:receipts.index.build" \
  "$INDEX_BUILD"
spine_job_run "receipts-archive-reconcile-daily:receipts-checksum-parity-report" \
  "$CHECKSUM"
spine_job_run "receipts-archive-reconcile-daily:receipts.rotate" \
  "$ROTATE_CMD" --execute
spine_job_run "receipts-archive-reconcile-daily:mailroom.log.rotate" \
  "$MAILROOM_LOG_ROTATE"
spine_job_run "receipts-archive-reconcile-daily:launchd.log.rotate" \
  "$LAUNCHD_LOG_ROTATE"

echo "[receipts-archive-reconcile-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
