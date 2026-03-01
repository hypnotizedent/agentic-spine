#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: monthly Ronny finance action queue (day 1)
# LaunchAgent: com.ronny.finance-action-queue-monthly
# Gap: GAP-OP-737

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[finance-action-queue-monthly] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run "finance-action-queue-monthly:secrets.binding" \
  "$CAP_RUNNER" cap run secrets.binding
spine_job_run "finance-action-queue-monthly:secrets.auth.status" \
  "$CAP_RUNNER" cap run secrets.auth.status
spine_job_run "finance-action-queue-monthly:finance.ronny.action.queue" \
  "$CAP_RUNNER" cap run finance.ronny.action.queue --cadence monthly --json

echo "[finance-action-queue-monthly] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
