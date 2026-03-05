#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: domain inventory observed-feed refresh
# LaunchAgent template: com.ronny.domain-inventory-refresh-daily
# W69 freshness recovery: D188

CONTROL_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
source "${CONTROL_ROOT}/ops/runtime/lib/runtime-managed-worktree.sh"
RUNTIME_ROOT="$(spine_runtime_prepare_managed_worktree "$CONTROL_ROOT")"
CAP_RUNNER="$RUNTIME_ROOT/bin/ops"
source "${RUNTIME_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[domain-inventory-refresh-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[domain-inventory-refresh-daily] control_root=${CONTROL_ROOT}"
echo "[domain-inventory-refresh-daily] runtime_root=${RUNTIME_ROOT}"
echo "[domain-inventory-refresh-daily] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

spine_job_run \
  "domain-inventory-refresh-daily:domain-inventory-refresh" \
  "$CAP_RUNNER" cap run domain-inventory-refresh -- --once --apply

echo "[domain-inventory-refresh-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
