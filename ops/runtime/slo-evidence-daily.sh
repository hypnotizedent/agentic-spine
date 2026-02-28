#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: SLO evidence collection at 23:59
# LaunchAgent: com.ronny.slo-evidence-daily
# Gaps: GAP-OP-736

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
MAX_ATTEMPTS="${SLO_EVIDENCE_MAX_ATTEMPTS:-3}"
BASE_BACKOFF_SECONDS="${SLO_EVIDENCE_BACKOFF_SECONDS:-20}"

echo "[slo-evidence-daily] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

run_with_retry() {
  local label="$1"
  shift
  local attempt=1
  local rc=0
  while (( attempt <= MAX_ATTEMPTS )); do
    if "$@"; then
      return 0
    fi
    rc=$?
    if (( attempt == MAX_ATTEMPTS )); then
      echo "[slo-evidence-daily] FAIL ${label} after ${attempt} attempt(s) rc=${rc}" >&2
      return "$rc"
    fi
    local sleep_s=$(( BASE_BACKOFF_SECONDS * attempt ))
    echo "[slo-evidence-daily] WARN ${label} attempt ${attempt} failed rc=${rc}; retry in ${sleep_s}s" >&2
    sleep "$sleep_s"
    attempt=$(( attempt + 1 ))
  done
  return "$rc"
}

run_with_retry "services.health.status" \
  "$CAP_RUNNER" cap run services.health.status
run_with_retry "verify.run fast" \
  "$CAP_RUNNER" cap run verify.run -- fast
run_with_retry "verify.freshness.reconcile" \
  "$CAP_RUNNER" cap run verify.freshness.reconcile
run_with_retry "slo.evidence.daily" \
  "$CAP_RUNNER" cap run slo.evidence.daily
run_with_retry "verify-failure-classify core" \
  "$SPINE_ROOT/ops/plugins/verify/bin/verify-failure-classify" core

echo "[slo-evidence-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
