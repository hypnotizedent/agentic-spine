#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: dispatch cc-benefits reminder actions from queue
# LaunchAgent: com.ronny.cc-benefits-reminder-dispatch-daily

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[cc-benefits-reminder-dispatch-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run "cc-benefits-reminder-dispatch-daily:finance.cc_benefits.reminder.dispatch" \
  "$CAP_RUNNER" cap run finance.cc_benefits.reminder.dispatch -- --execute --json

echo "[cc-benefits-reminder-dispatch-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
