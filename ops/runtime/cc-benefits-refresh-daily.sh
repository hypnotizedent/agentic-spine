#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: refresh cc-benefits deterministic status + queue artifacts
# LaunchAgent: com.ronny.cc-benefits-refresh-daily

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

as_of_local="$(TZ="${SPINE_OPERATOR_TZ:-America/New_York}" date +%Y-%m-%d)"

echo "[cc-benefits-refresh-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ) as_of=${as_of_local}"

spine_job_run "cc-benefits-refresh-daily:finance.cc_benefits.refresh" \
  "$CAP_RUNNER" cap run finance.cc_benefits.refresh -- --as-of "$as_of_local"

echo "[cc-benefits-refresh-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
