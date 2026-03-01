#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: immich duplicate scan Sunday 02:00
# LaunchAgent: com.ronny.immich-reconcile-weekly
# Gaps: GAP-OP-741

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[immich-reconcile-weekly] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "immich-reconcile-weekly:immich.reconcile.scan" \
  "$CAP_RUNNER" cap run immich.reconcile.scan

echo "[immich-reconcile-weekly] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
