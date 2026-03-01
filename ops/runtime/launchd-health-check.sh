#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
REGISTRY="${SPINE_ROOT}/ops/bindings/launchd.scheduler.registry.yaml"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

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

  mapfile -t labels < <(yq -r '.labels[] | select(.state == "active" and .monitor == true) | .label' "$REGISTRY")
  if [[ "${#labels[@]}" -eq 0 ]]; then
    echo "[launchd-health-check] no monitorable labels in registry"
    return 0
  fi

  local uid_val missing
  uid_val="$(id -u)"
  missing=0
  missing_labels=()
  for label in "${labels[@]}"; do
    if launchctl print "gui/${uid_val}/${label}" >/dev/null 2>&1; then
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] OK ${label}"
    else
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] MISSING ${label}"
      missing=$((missing + 1))
      missing_labels+=("$label")
    fi
  done

  echo "[launchd-health-check] labels=${#labels[@]} missing=${missing}"
  if [[ "$missing" -gt 0 ]]; then
    spine_enqueue_email_intent \
      "launchd-health-check" \
      "incident" \
      "LaunchAgent health check detected missing labels" \
      "missing=${missing} of total=${#labels[@]} labels. Missing labels: ${missing_labels[*]}" \
      "launchd-health-check"
  fi
  [[ "$missing" -eq 0 ]]
}

echo "[launchd-health-check] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
spine_job_run "launchd-health-check:monitor" check_launchd_health
echo "[launchd-health-check] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
