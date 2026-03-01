#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RUNTIME_JOB_LOG="${SPINE_RUNTIME_JOB_LOG:-$SPINE_ROOT/mailroom/logs/runtime-jobs.ndjson}"
EMAIL_INTENT_DIR="${SPINE_ROOT}/mailroom/outbox/alerts/email-intents"

spine_enqueue_email_intent() {
  local domain_id="$1"
  local severity="$2"
  local title="$3"
  local summary="$4"
  local source_alert="${5:-runtime-job-wrapper}"
  local intent_id created_at intent_file

  intent_id="email-intent-$(date -u +%Y%m%dT%H%M%SZ)-${RANDOM}"
  created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  intent_file="${EMAIL_INTENT_DIR}/${intent_id}.yaml"

  mkdir -p "${EMAIL_INTENT_DIR}"
  cat >"${intent_file}" <<INTENT
intent_id: "${intent_id}"
created_at: "${created_at}"
domain_id: "${domain_id}"
severity: "${severity}"
title: "${title}"
summary: |-
$(printf '%s\n' "${summary}" | sed 's/^/  /')
suggested_recipient: "alerts@spine.ronny.works"
source_alert: "${source_alert}"
flush_status: pending
INTENT
}

spine_job_run() {
  local job_name="$1"
  shift

  local start_epoch end_epoch rc duration_s started_at ended_at
  start_epoch="$(date +%s)"
  started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  set +e
  "$@"
  rc=$?
  set -e

  end_epoch="$(date +%s)"
  ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  duration_s=$(( end_epoch - start_epoch ))

  mkdir -p "$(dirname "$RUNTIME_JOB_LOG")"
  if command -v jq >/dev/null 2>&1; then
    jq -cn \
      --arg job_name "$job_name" \
      --arg started_at "$started_at" \
      --arg ended_at "$ended_at" \
      --argjson duration_s "$duration_s" \
      --argjson exit_code "$rc" \
      '{job_name:$job_name,started_at:$started_at,ended_at:$ended_at,duration_s:$duration_s,exit_code:$exit_code}' >> "$RUNTIME_JOB_LOG"
  else
    printf '{"job_name":"%s","started_at":"%s","ended_at":"%s","duration_s":%s,"exit_code":%s}\n' \
      "$job_name" "$started_at" "$ended_at" "$duration_s" "$rc" >> "$RUNTIME_JOB_LOG"
  fi

  if [[ "$rc" -ne 0 ]]; then
    spine_enqueue_email_intent \
      "runtime-jobs" \
      "incident" \
      "Scheduled job failed: ${job_name}" \
      "job=${job_name} exit_code=${rc} duration_s=${duration_s}" \
      "runtime-job-wrapper"
  fi

  return "$rc"
}
