#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: refresh cc-benefits deterministic status + queue artifacts
# LaunchAgent: com.ronny.cc-benefits-refresh-daily

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../lib/runtime-managed-worktree.sh"
CONTROL_ROOT="$(spine_runtime_resolve_control_root "${BASH_SOURCE[0]}")"
spine_runtime_activate_managed_worktree "$CONTROL_ROOT"
RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"
CAP_RUNNER="${RUNTIME_ROOT}/bin/ops"
source "${RUNTIME_ROOT}/ops/lib/job-wrapper.sh"

as_of_local="$(TZ="${SPINE_OPERATOR_TZ:-America/New_York}" date +%Y-%m-%d)"

echo "[cc-benefits-refresh-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ) as_of=${as_of_local}"
echo "[cc-benefits-refresh-daily] control_root=${CONTROL_ROOT}"
echo "[cc-benefits-refresh-daily] runtime_root=${RUNTIME_ROOT}"
echo "[cc-benefits-refresh-daily] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

spine_job_run "cc-benefits-refresh-daily:finance.cc_benefits.refresh" \
  "$CAP_RUNNER" cap run finance.cc_benefits.refresh -- --as-of "$as_of_local"

echo "[cc-benefits-refresh-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
