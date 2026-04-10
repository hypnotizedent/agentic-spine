#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: domain inventory observed-feed refresh
# LaunchAgent template: com.ronny.domain-inventory-refresh-daily
# W69 freshness recovery: D188

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../lib/runtime-managed-worktree.sh"
CONTROL_ROOT="$(spine_runtime_resolve_control_root "${BASH_SOURCE[0]}")"
spine_runtime_activate_managed_worktree "$CONTROL_ROOT"
RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"
REFRESH_CMD="$RUNTIME_ROOT/ops/plugins/core/authority/bin/domain-inventory-refresh"
source "${RUNTIME_ROOT}/ops/lib/job-wrapper.sh"

echo "[domain-inventory-refresh-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[domain-inventory-refresh-daily] control_root=${CONTROL_ROOT}"
echo "[domain-inventory-refresh-daily] runtime_root=${RUNTIME_ROOT}"
echo "[domain-inventory-refresh-daily] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

spine_job_run \
  "domain-inventory-refresh-daily:domain-inventory-refresh" \
  "$REFRESH_CMD" --once --check

echo "[domain-inventory-refresh-daily] autonomous ledger reconcile enabled (media/ha/network)"

echo "[domain-inventory-refresh-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
