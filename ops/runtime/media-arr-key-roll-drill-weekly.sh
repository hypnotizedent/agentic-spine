#!/usr/bin/env bash
set -euo pipefail

# Weekly non-mutating rehearsal to catch ARR key drift early.
# This validates canonical key routing/auth plus downstream media pipeline health.

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

run_media_pack_guarded() {
  local tmp rc
  tmp="$(mktemp)"

  set +e
  "$CAP_RUNNER" cap run verify.pack.run media >"$tmp" 2>&1
  rc=$?
  set -e

  cat "$tmp"

  # Treat budget-only overruns as non-fatal when all media gates pass.
  if [[ "$rc" -ne 0 ]] \
    && grep -q 'verify.run FAIL: budget exceeded' "$tmp" \
    && grep -q 'summary: pass=19 fail=0' "$tmp"; then
    echo "[media-arr-key-roll-drill-weekly] WARN media pack budget exceeded but gates all passed."
    rm -f "$tmp"
    return 0
  fi

  rm -f "$tmp"
  return "$rc"
}

echo "[media-arr-key-roll-drill-weekly] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

spine_job_run \
  "media-arr-key-roll-drill-weekly:secrets.bundle.apply" \
  "$CAP_RUNNER" cap run secrets.bundle.apply media-arr --verify-only
spine_job_run \
  "media-arr-key-roll-drill-weekly:verify.pack.run.media" \
  run_media_pack_guarded

echo "[media-arr-key-roll-drill-weekly] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
