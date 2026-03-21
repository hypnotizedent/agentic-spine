#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/lib/job-wrapper.sh"

echo "[operator-hygiene-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
spine_job_run \
  "operator-hygiene-daily:operator.hygiene.reconcile" \
  "$CAP_RUNNER" cap run operator.hygiene.reconcile -- --execute
echo "[operator-hygiene-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
