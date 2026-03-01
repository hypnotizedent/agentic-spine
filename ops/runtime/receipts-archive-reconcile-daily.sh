#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="$SPINE_ROOT/bin/ops"
CHECKSUM="$SPINE_ROOT/ops/plugins/evidence/bin/receipts-checksum-parity-report"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[receipts-archive-reconcile-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run "receipts-archive-reconcile-daily:receipts.index.build" \
  "$CAP_RUNNER" cap run receipts.index.build
spine_job_run "receipts-archive-reconcile-daily:receipts-checksum-parity-report" \
  "$CHECKSUM"
spine_job_run "receipts-archive-reconcile-daily:receipts.rotate" \
  "$CAP_RUNNER" cap run receipts.rotate -- --execute
spine_job_run "receipts-archive-reconcile-daily:mailroom.log.rotate" \
  "$CAP_RUNNER" cap run mailroom.log.rotate
spine_job_run "receipts-archive-reconcile-daily:launchd.log.rotate" \
  "$CAP_RUNNER" cap run launchd.log.rotate

echo "[receipts-archive-reconcile-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
