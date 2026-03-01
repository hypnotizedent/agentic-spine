#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: reconcile friction queue into matched/filed governed gaps.
# LaunchAgent: com.ronny.friction-reconcile

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[friction-reconcile] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "friction-reconcile:friction.reconcile" \
  "$CAP_RUNNER" cap run friction.reconcile -- --loop-id LOOP-AGENT-FRICTION-AUTOPILOT-20260301 --json

echo "[friction-reconcile] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
