#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: SLO evidence collection at 23:59
# LaunchAgent: com.ronny.slo-evidence-daily
# Gaps: GAP-OP-736

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
MAX_ATTEMPTS="${SLO_EVIDENCE_MAX_ATTEMPTS:-3}"
BASE_BACKOFF_SECONDS="${SLO_EVIDENCE_BACKOFF_SECONDS:-20}"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

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

spine_job_run "slo-evidence-daily:services.health.status" run_with_retry "services.health.status" \
  "$CAP_RUNNER" cap run services.health.status
spine_job_run "slo-evidence-daily:verify.run.fast" run_with_retry "verify.run fast" \
  "$CAP_RUNNER" cap run verify.run -- fast
spine_job_run "slo-evidence-daily:verify.freshness.reconcile" run_with_retry "verify.freshness.reconcile" \
  "$CAP_RUNNER" cap run verify.freshness.reconcile
spine_job_run "slo-evidence-daily:docs.freshness.audit" run_with_retry "docs.freshness.audit" \
  "$CAP_RUNNER" cap run docs.freshness.audit
spine_job_run "slo-evidence-daily:slo.evidence.daily" run_with_retry "slo.evidence.daily" \
  "$CAP_RUNNER" cap run slo.evidence.daily
spine_job_run "slo-evidence-daily:verify-failure-classify.core" run_with_retry "verify-failure-classify core" \
  "$SPINE_ROOT/ops/plugins/verify/bin/verify-failure-classify" core

latest_slo_report="$(ls -1t "${SPINE_ROOT}/receipts/audits/governance"/slo-evidence-*.md 2>/dev/null | head -n1 || true)"
if [[ -n "$latest_slo_report" ]]; then
  slo_state="$(awk -F': *' '/^slo_pass:/{print $2; exit}' "$latest_slo_report" | tr -d '"' | tr -d "'" || true)"
  if [[ "$slo_state" == "FAIL" ]]; then
    spine_enqueue_email_intent \
      "slo-evidence" \
      "incident" \
      "SLO evidence daily reported FAIL" \
      "Latest report: ${latest_slo_report}; run verify + stability triage and review failing metrics." \
      "slo-evidence-daily"
  fi
fi

echo "[slo-evidence-daily] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
