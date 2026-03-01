#!/usr/bin/env bash
set -euo pipefail

# Weekly non-mutating rehearsal to catch ARR key drift early.
# This validates canonical key routing/auth plus downstream media pipeline health.

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

echo "[media-arr-key-roll-drill-weekly] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "media-arr-key-roll-drill-weekly:secrets.bundle.apply" \
  "$CAP_RUNNER" cap run secrets.bundle.apply media-arr --verify-only
spine_job_run \
  "media-arr-key-roll-drill-weekly:verify.pack.run.media" \
  "$CAP_RUNNER" cap run verify.pack.run media

echo "[media-arr-key-roll-drill-weekly] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
