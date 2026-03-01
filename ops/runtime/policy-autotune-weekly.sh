#!/usr/bin/env bash
set -euo pipefail

# policy-autotune-weekly.sh
# Weekly control loop runner:
# observe -> decide -> auto-propose (submit only) -> human apply (manual)

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
LOG_PREFIX="[policy-autotune-weekly]"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

if [[ ! -x "$CAP_RUNNER" ]]; then
  echo "$LOG_PREFIX STOP: capability runner missing at $CAP_RUNNER" >&2
  exit 2
fi

echo "$LOG_PREFIX start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "$LOG_PREFIX step 1/2: policy.autotune.weekly"
spine_job_run \
  "policy-autotune-weekly:policy.autotune.weekly" \
  "$CAP_RUNNER" cap run policy.autotune.weekly

echo "$LOG_PREFIX step 2/2: policy.autotune.propose"
spine_job_run \
  "policy-autotune-weekly:policy.autotune.propose" \
  "$CAP_RUNNER" cap run policy.autotune.propose

echo "$LOG_PREFIX done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
