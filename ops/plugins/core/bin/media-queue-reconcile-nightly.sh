#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: reconcile media queue items per C1-C6 policy.
# LaunchAgent: com.ronny.media-queue-reconcile-nightly

SPINE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/lib/job-wrapper.sh"

echo "[media-queue-reconcile-nightly] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "media-queue-reconcile-nightly:media.queue.reconcile" \
  "$CAP_RUNNER" cap run media.queue.reconcile -- --json

echo "[media-queue-reconcile-nightly] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
