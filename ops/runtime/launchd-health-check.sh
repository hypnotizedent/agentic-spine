#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
REGISTRY="${SPINE_ROOT}/ops/bindings/launchd.scheduler.registry.yaml"
SCHEDULER_STATUS_SCRIPT="${SPINE_ROOT}/ops/plugins/host/bin/launchd-scheduler-health-status"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
AUTO_RESTART=0
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

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

  mapfile -t labels < <(yq -r '.labels[] | select(.state == "active" and .monitor == true) | .label' "$REGISTRY")
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
      if "$CAP_RUNNER" cap run recovery.launchd.restart -- --label "$label" >/dev/null 2>&1 && \
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

  local scheduler_payload scheduler_status scheduler_stale scheduler_failed scheduler_unknown scheduler_total
  local scheduler_stale_labels scheduler_failed_labels
  scheduler_payload="$("$SCHEDULER_STATUS_SCRIPT" --json 2>/dev/null || true)"
  scheduler_status="$(jq -r '.status // "unknown"' <<<"$scheduler_payload" 2>/dev/null || echo "unknown")"
  scheduler_stale="$(jq -r '.data.summary.stale // 0' <<<"$scheduler_payload" 2>/dev/null || echo "0")"
  scheduler_failed="$(jq -r '.data.summary.failed // 0' <<<"$scheduler_payload" 2>/dev/null || echo "0")"
  scheduler_unknown="$(jq -r '.data.summary.unknown // 0' <<<"$scheduler_payload" 2>/dev/null || echo "0")"
  scheduler_total="$(jq -r '.data.summary.total // 0' <<<"$scheduler_payload" 2>/dev/null || echo "0")"
  scheduler_stale_labels="$(jq -r '.data.stale_labels // [] | join(", ")' <<<"$scheduler_payload" 2>/dev/null || true)"
  scheduler_failed_labels="$(jq -r '.data.failed_labels // [] | join(", ")' <<<"$scheduler_payload" 2>/dev/null || true)"

  if [[ "$scheduler_status" == "warn" || "$scheduler_status" == "error" ]]; then
    spine_enqueue_email_intent \
      "launchd-health-check" \
      "incident" \
      "LaunchAgent recency/status drift detected" \
      "scheduler_status=${scheduler_status} total=${scheduler_total} stale=${scheduler_stale} failed=${scheduler_failed} unknown=${scheduler_unknown} stale_labels=${scheduler_stale_labels:-none} failed_labels=${scheduler_failed_labels:-none}" \
      "launchd-health-check"
  fi

  [[ "$missing" -eq 0 && "$scheduler_failed" -eq 0 && "$scheduler_stale" -eq 0 ]]
}

echo "[launchd-health-check] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
spine_job_run "launchd-health-check:monitor" check_launchd_health
echo "[launchd-health-check] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
