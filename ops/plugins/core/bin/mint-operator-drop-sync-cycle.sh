#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/lib/job-wrapper.sh"

echo "[mint-operator-drop-sync-cycle] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
spine_job_run \
  "mint-operator-drop-sync-cycle:mint.operator.drop.sync" \
  "$CAP_RUNNER" cap run mint.operator.drop.sync -- --execute --quiet
echo "[mint-operator-drop-sync-cycle] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
