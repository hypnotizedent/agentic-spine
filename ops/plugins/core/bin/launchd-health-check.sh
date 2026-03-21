#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"

resolve_spine_root() {
  local git_root
  git_root="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "${git_root}" ]]; then
    printf '%s\n' "${git_root}"
    return
  fi

  if [[ -n "${SCRIPT_ROOT}" ]]; then
    printf '%s\n' "${SCRIPT_ROOT}"
    return
  fi

  if [[ -n "${SPINE_TARGET_REPO:-}" ]]; then
    printf '%s\n' "${SPINE_TARGET_REPO}"
    return
  fi

  if [[ -n "${SPINE_ROOT:-}" ]]; then
    printf '%s\n' "${SPINE_ROOT}"
    return
  fi

  printf '%s\n' "${SCRIPT_ROOT}"
}

SPINE_ROOT="$(resolve_spine_root)"
REGISTRY="${SPINE_ROOT}/ops/bindings/launchd.scheduler.registry.yaml"
SCHEDULER_STATUS_SCRIPT="${SPINE_ROOT}/ops/plugins/infra/host/bin/launchd-scheduler-health-status"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
TASK_WORKER_SCRIPT="${SPINE_ROOT}/ops/plugins/infra/mailroom-bridge/bin/mailroom-task-worker"
AUTO_RESTART=0
source "${SPINE_ROOT}/ops/lib/job-wrapper.sh"

run_cap() {
  env \
    SPINE_TARGET_REPO="${SPINE_ROOT}" \
    SPINE_ROOT="${SPINE_ROOT}" \
    SPINE_REPO="${SPINE_ROOT}" \
    SPINE_CODE="${SPINE_ROOT}" \
    "$CAP_RUNNER" cap run "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-restart) AUTO_RESTART=1; shift ;;
    -h|--help)
      echo "Usage: launchd-health-check.sh [--auto-restart]"
      exit 0
      ;;
    *)
      echo "[launchd-health-check] unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

check_task_worker_health() {
  if [[ ! -x "$TASK_WORKER_SCRIPT" ]]; then
    echo "[launchd-health-check] missing task worker script: $TASK_WORKER_SCRIPT" >&2
    return 2
  fi

  local status_out status_rc
  set +e
  status_out="$("$TASK_WORKER_SCRIPT" --status --brief --strict 2>&1)"
  status_rc=$?
  set -e
  if [[ "$status_rc" -eq 0 ]]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] OK mailroom.task.worker ${status_out}"
    return 0
  fi

  if [[ "$AUTO_RESTART" -eq 1 ]]; then
    OPS_CAP_AUTO_APPROVE=yes run_cap mailroom.task.worker.stop >/dev/null 2>&1 || true
    if OPS_CAP_AUTO_APPROVE=yes run_cap mailroom.task.worker.start >/dev/null 2>&1; then
      sleep 3
      set +e
      status_out="$("$TASK_WORKER_SCRIPT" --status --brief --strict 2>&1)"
      status_rc=$?
      set -e
      if [[ "$status_rc" -eq 0 ]]; then
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] RECOVERED mailroom.task.worker (auto-restart) ${status_out}"
        return 0
      fi
    fi
  fi

  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] FAIL mailroom.task.worker ${status_out}"
  spine_enqueue_email_intent \
    "launchd-health-check" \
    "incident" \
    "Mailroom task worker unhealthy" \
    "worker_status=${status_out:-unknown} auto_restart=${AUTO_RESTART}" \
    "launchd-health-check"
  return 1
}

check_launchd_health() {
  if [[ ! -f "$REGISTRY" ]]; then
    echo "[launchd-health-check] missing registry: $REGISTRY" >&2
    return 2
  fi
  if ! command -v yq >/dev/null 2>&1; then
    echo "[launchd-health-check] missing yq" >&2
    return 2
  fi
  if ! command -v launchctl >/dev/null 2>&1; then
    echo "[launchd-health-check] missing launchctl" >&2
    return 2
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "[launchd-health-check] missing jq" >&2
    return 2
  fi
  if [[ ! -x "$SCHEDULER_STATUS_SCRIPT" ]]; then
    echo "[launchd-health-check] missing scheduler status script: $SCHEDULER_STATUS_SCRIPT" >&2
    return 2
  fi

  local -a labels=()
  while IFS= read -r _lbl; do
    [[ -n "$_lbl" ]] && labels+=("$_lbl")
  done < <(yq -r '.labels[] | select(.state == "active" and .monitor == true) | .label' "$REGISTRY")
  if [[ "${#labels[@]}" -eq 0 ]]; then
    echo "[launchd-health-check] no monitorable labels in registry"
    return 0
  fi

  local uid_val missing recovered
  local -a missing_labels=()
  uid_val="$(id -u)"
  missing=0
  recovered=0
  for label in "${labels[@]}"; do
    if launchctl print "gui/${uid_val}/${label}" >/dev/null 2>&1; then
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] OK ${label}"
      continue
    fi

    if [[ "$AUTO_RESTART" -eq 1 ]]; then
      if run_cap recovery.launchd.restart -- --label "$label" >/dev/null 2>&1 && \
         launchctl print "gui/${uid_val}/${label}" >/dev/null 2>&1; then
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] RECOVERED ${label} (auto-restart)"
        recovered=$((recovered + 1))
        continue
      fi
    fi

    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] MISSING ${label}"
    missing=$((missing + 1))
    missing_labels+=("$label")
  done

  echo "[launchd-health-check] labels=${#labels[@]} missing=${missing} recovered=${recovered} auto_restart=${AUTO_RESTART}"
  if [[ "$missing" -gt 0 ]]; then
    spine_enqueue_email_intent \
      "launchd-health-check" \
      "incident" \
      "LaunchAgent health check detected missing labels" \
      "missing=${missing} of total=${#labels[@]} labels. Missing labels: ${missing_labels[*]}" \
      "launchd-health-check"
  fi

  local worker_rc=0
  check_task_worker_health || worker_rc=$?

  local scheduler_payload scheduler_status scheduler_stale scheduler_failed scheduler_unknown scheduler_total
  local scheduler_stale_labels scheduler_failed_labels scheduler_failed_labels_filtered
  scheduler_payload="$("$SCHEDULER_STATUS_SCRIPT" --json 2>/dev/null || true)"
  scheduler_status="$(jq -r '.status // "unknown"' <<<"$scheduler_payload" 2>/dev/null || echo "unknown")"
  scheduler_stale="$(jq -r '.data.summary.stale // 0' <<<"$scheduler_payload" 2>/dev/null || echo "0")"
  scheduler_failed="$(jq -r '.data.summary.failed // 0' <<<"$scheduler_payload" 2>/dev/null || echo "0")"
  scheduler_unknown="$(jq -r '.data.summary.unknown // 0' <<<"$scheduler_payload" 2>/dev/null || echo "0")"
  scheduler_total="$(jq -r '.data.summary.total // 0' <<<"$scheduler_payload" 2>/dev/null || echo "0")"
  scheduler_stale_labels="$(jq -r '.data.stale_labels // [] | join(", ")' <<<"$scheduler_payload" 2>/dev/null || true)"
  scheduler_failed_labels="$(jq -r '.data.failed_labels // [] | join(", ")' <<<"$scheduler_payload" 2>/dev/null || true)"
  scheduler_failed_labels_filtered="$(
    jq -r '
      (.data.failed_labels // [])
      | map(select(. != "com.ronny.launchd-health-check"))
      | join(", ")
    ' <<<"$scheduler_payload" 2>/dev/null || true
  )"
  if [[ -n "$scheduler_failed_labels_filtered" ]]; then
    scheduler_failed="$(jq -r '
      (.data.failed_labels // [])
      | map(select(. != "com.ronny.launchd-health-check"))
      | length
    ' <<<"$scheduler_payload" 2>/dev/null || echo "$scheduler_failed")"
  else
    scheduler_failed=0
  fi

  echo "[launchd-health-check] scheduler_status=${scheduler_status} total=${scheduler_total} stale=${scheduler_stale} failed=${scheduler_failed} unknown=${scheduler_unknown} stale_labels=${scheduler_stale_labels:-none} failed_labels=${scheduler_failed_labels_filtered:-none}"

  if [[ "$scheduler_stale" -gt 0 || "$scheduler_failed" -gt 0 || "$scheduler_unknown" -gt 0 ]]; then
    spine_enqueue_email_intent \
      "launchd-health-check" \
      "incident" \
      "LaunchAgent recency/status drift detected" \
      "scheduler_status=${scheduler_status} total=${scheduler_total} stale=${scheduler_stale} failed=${scheduler_failed} unknown=${scheduler_unknown} stale_labels=${scheduler_stale_labels:-none} failed_labels=${scheduler_failed_labels_filtered:-none}" \
      "launchd-health-check"
  fi

  [[ "$missing" -eq 0 && "$worker_rc" -eq 0 && "$scheduler_failed" -eq 0 && "$scheduler_stale" -eq 0 ]]
}

echo "[launchd-health-check] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
spine_job_run "launchd-health-check:monitor" check_launchd_health
echo "[launchd-health-check] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
