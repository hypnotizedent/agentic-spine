#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SPINE_OPERATOR_TZ="${SPINE_OPERATOR_TZ:-America/New_York}"
export SPINE_OPERATOR_TZ
export TZ="${SPINE_OPERATOR_TZ}"
if [[ -f "${SPINE_ROOT}/ops/lib/runtime-paths.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SPINE_ROOT}/ops/lib/runtime-paths.sh"
  spine_runtime_resolve_paths
fi

if [[ -f "${SPINE_ROOT}/ops/lib/spine-log.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SPINE_ROOT}/ops/lib/spine-log.sh"
fi

spine_job_wrapper_ps_comm() {
  local pid="${1:-}"
  [[ -n "$pid" ]] || return 1
  ps -o comm= -p "$pid" 2>/dev/null | awk 'NR==1 {print $1}' | xargs basename
}

spine_export_autonomous_scheduler_context() {
  local source_script="${1:-}"
  local source_basename label parent_comm

  [[ -n "$source_script" ]] || return 0

  parent_comm="$(spine_job_wrapper_ps_comm "${PPID:-}" || true)"
  [[ "$parent_comm" == "launchd" ]] || return 0

  source_basename="$(basename "$source_script")"
  source_basename="${source_basename%.sh}"
  [[ -n "$source_basename" ]] || return 0
  label="com.ronny.${source_basename}"

  export SPINE_AUTONOMOUS_EXECUTION_CONTEXT="${SPINE_AUTONOMOUS_EXECUTION_CONTEXT:-launchd_scheduler}"
  export SPINE_AUTONOMOUS_SOURCE="${SPINE_AUTONOMOUS_SOURCE:-runtime_job_wrapper}"
  export SPINE_AUTONOMOUS_PARENT_PROCESS="${SPINE_AUTONOMOUS_PARENT_PROCESS:-launchd}"
  export SPINE_AUTONOMOUS_ANCESTRY_CONFIRMED="${SPINE_AUTONOMOUS_ANCESTRY_CONFIRMED:-true}"
  export SPINE_AUTONOMOUS_SOURCE_SCRIPT="${SPINE_AUTONOMOUS_SOURCE_SCRIPT:-$source_script}"
  export SPINE_SCHEDULER_LABEL="${SPINE_SCHEDULER_LABEL:-$label}"
}

spine_export_autonomous_scheduler_context "${BASH_SOURCE[1]:-${0:-}}"

# Scheduled jobs run without terminal role context, so cap.sh falls back to
# the default "researcher" role which blocks mutating capabilities.
# Set worker role explicitly — scheduled jobs are automated workers that
# need mutating access (snapshot builds, index refreshes, reconciliation).
export SPINE_RUNTIME_ROLE="${SPINE_RUNTIME_ROLE:-worker}"

# Scheduled jobs run non-interactively — manual approval prompts would block
# indefinitely. Auto-approve capabilities that require manual consent.
export OPS_CAP_AUTO_APPROVE="${OPS_CAP_AUTO_APPROVE:-yes}"

RUNTIME_JOB_LOG="${SPINE_RUNTIME_JOB_LOG:-${SPINE_LOGS:-$HOME/code/.runtime/spine/logs}/runtime-jobs.ndjson}"
RUNTIME_JOB_LOG_KEEP_DAYS="${SPINE_RUNTIME_JOB_LOG_KEEP_DAYS:-14}"
EMAIL_INTENT_DIR="${SPINE_OUTBOX:-$HOME/code/.runtime/spine/mailroom/outbox}/alerts/email-intents"

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
  spine_rotate_runtime_job_log

  local status_text execution_source
  status_text="done"
  [[ "$rc" -eq 0 ]] || status_text="failed"
  execution_source="${SPINE_AUTONOMOUS_EXECUTION_CONTEXT:-manual}"

  if command -v jq >/dev/null 2>&1; then
    jq -cn \
      --arg job_name "$job_name" \
      --arg started_at "$started_at" \
      --arg ended_at "$ended_at" \
      --argjson duration_s "$duration_s" \
      --argjson exit_code "$rc" \
      --arg status "$status_text" \
      --arg execution_source "$execution_source" \
      '{job_name:$job_name,started_at:$started_at,ended_at:$ended_at,duration_s:$duration_s,exit_code:$exit_code,status:$status,execution_source:$execution_source}' >> "$RUNTIME_JOB_LOG"
  else
    printf '{"job_name":"%s","started_at":"%s","ended_at":"%s","duration_s":%s,"exit_code":%s,"status":"%s","execution_source":"%s"}\n' \
      "$job_name" "$started_at" "$ended_at" "$duration_s" "$rc" "$status_text" "$execution_source" >> "$RUNTIME_JOB_LOG"
  fi

  if command -v spine_log_event >/dev/null 2>&1; then
    spine_log_event \
      --event-type "runtime.job" \
      --domain "runtime" \
      --status "$status_text" \
      --message "job=${job_name} exit_code=${rc} duration_s=${duration_s}" \
      --source "ops/lib/job-wrapper.sh" \
      --meta-json "{\"job_name\":\"$job_name\",\"duration_s\":$duration_s,\"exit_code\":$rc}" || true
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

spine_rotate_runtime_job_log() {
  [[ -f "$RUNTIME_JOB_LOG" ]] || return 0
  [[ "$RUNTIME_JOB_LOG_KEEP_DAYS" =~ ^[0-9]+$ ]] || RUNTIME_JOB_LOG_KEEP_DAYS=14

  local log_day today archive_path
  log_day="$(date -r "$RUNTIME_JOB_LOG" +%Y%m%d 2>/dev/null || true)"
  today="$(date +%Y%m%d)"
  if [[ -z "$log_day" || "$log_day" == "$today" ]]; then
    return 0
  fi

  archive_path="${RUNTIME_JOB_LOG}.${log_day}"
  if [[ ! -f "$archive_path" ]]; then
    mv "$RUNTIME_JOB_LOG" "$archive_path"
  else
    cat "$RUNTIME_JOB_LOG" >> "$archive_path"
    rm -f "$RUNTIME_JOB_LOG"
  fi
  : > "$RUNTIME_JOB_LOG"

  find "$(dirname "$RUNTIME_JOB_LOG")" \
    -type f \
    -name "$(basename "$RUNTIME_JOB_LOG").20*" \
    -mtime +"$RUNTIME_JOB_LOG_KEEP_DAYS" \
    -delete 2>/dev/null || true
}
