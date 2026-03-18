#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: verify.run fast + loop_gap + live D399 mailbox lock.
# LaunchAgent: com.ronny.verify-run-daily

SPINE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
VERIFY_RESPONSE_LOOP="${SPINE_ROOT}/ops/plugins/core/verify/bin/verify-response-loop"
D399_CMD="${SPINE_ROOT}/surfaces/verify/d399-microsoft-mint-customer-mailbox-canonical-lock.sh"
source "${SPINE_ROOT}/ops/lib/job-wrapper.sh"

run_daily_verify() {
  local fast_rc loop_gap_rc d399_rc verify_rc
  fast_rc=0
  loop_gap_rc=0
  d399_rc=0
  verify_rc=0

  [[ -x "$CAP_RUNNER" ]] || {
    echo "[verify-run-daily] missing cap runner: $CAP_RUNNER" >&2
    return 2
  }
  [[ -x "$VERIFY_RESPONSE_LOOP" ]] || {
    echo "[verify-run-daily] missing verify response loop: $VERIFY_RESPONSE_LOOP" >&2
    return 2
  }
  [[ -x "$D399_CMD" ]] || {
    echo "[verify-run-daily] missing mailbox lock verifier: $D399_CMD" >&2
    return 2
  }

  set +e
  "$CAP_RUNNER" cap run verify.run -- fast
  fast_rc=$?
  "$CAP_RUNNER" cap run verify.run -- domain loop_gap
  loop_gap_rc=$?
  "$D399_CMD"
  d399_rc=$?
  "$VERIFY_RESPONSE_LOOP" || true
  set -e

  (( fast_rc == 0 && loop_gap_rc == 0 && d399_rc == 0 )) || verify_rc=1
  if [[ "$verify_rc" -ne 0 ]]; then
    echo "[verify-run-daily] failure fast_rc=$fast_rc loop_gap_rc=$loop_gap_rc d399_rc=$d399_rc" >&2
  fi
  return "$verify_rc"
}

echo "[verify-run-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
spine_job_run "verify-run-daily:verify.run.fast+loop_gap+d399" run_daily_verify
echo "[verify-run-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
