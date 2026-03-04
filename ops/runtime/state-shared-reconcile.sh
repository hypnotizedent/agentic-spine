#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: SQLite shared authority self-heal reconcile.
# LaunchAgent: com.ronny.state-shared-reconcile

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[state-shared-reconcile] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "state-shared-reconcile:state.shared.reconcile" \
  "$CAP_RUNNER" cap run state.shared.reconcile -- --fix --json

echo "[state-shared-reconcile] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
