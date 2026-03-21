#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: dispatch cc-benefits reminder actions from queue
# LaunchAgent: com.ronny.cc-benefits-reminder-dispatch-daily

CONTROL_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)}"
source "${CONTROL_ROOT}/ops/lib/runtime-managed-worktree.sh"
spine_runtime_activate_managed_worktree "$CONTROL_ROOT"
RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"
CAP_RUNNER="${RUNTIME_ROOT}/bin/ops"
source "${RUNTIME_ROOT}/ops/lib/job-wrapper.sh"

echo "[cc-benefits-reminder-dispatch-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[cc-benefits-reminder-dispatch-daily] control_root=${CONTROL_ROOT}"
echo "[cc-benefits-reminder-dispatch-daily] runtime_root=${RUNTIME_ROOT}"
echo "[cc-benefits-reminder-dispatch-daily] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

spine_job_run "cc-benefits-reminder-dispatch-daily:finance.cc_benefits.reminder.dispatch" \
  "$CAP_RUNNER" cap run finance.cc_benefits.reminder.dispatch -- --execute --json

echo "[cc-benefits-reminder-dispatch-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
