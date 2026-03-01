#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: reconcile gate registry + entry-surface projections.
# LaunchAgent: com.ronny.projection-reconcile

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[projection-reconcile] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "projection-reconcile:projection.reconcile" \
  "$CAP_RUNNER" cap run projection.reconcile

echo "[projection-reconcile] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
