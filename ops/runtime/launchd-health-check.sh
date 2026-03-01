#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
REGISTRY="${SPINE_ROOT}/ops/bindings/launchd.scheduler.registry.yaml"
EMAIL_INTENT_DIR="${SPINE_ROOT}/mailroom/outbox/alerts/email-intents"

if [[ ! -f "$REGISTRY" ]]; then
  echo "[launchd-health-check] missing registry: $REGISTRY" >&2
  exit 2
fi
if ! command -v yq >/dev/null 2>&1; then
  echo "[launchd-health-check] missing yq" >&2
  exit 2
fi
if ! command -v launchctl >/dev/null 2>&1; then
  echo "[launchd-health-check] missing launchctl" >&2
  exit 2
fi

enqueue_email_intent() {
  local severity="$1"
  local title="$2"
  local summary="$3"
  local intent_id created_at intent_file
  intent_id="email-intent-$(date -u +%Y%m%dT%H%M%SZ)-${RANDOM}"
  created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  intent_file="${EMAIL_INTENT_DIR}/${intent_id}.yaml"
  mkdir -p "${EMAIL_INTENT_DIR}"
  cat >"${intent_file}" <<INTENT
intent_id: "${intent_id}"
created_at: "${created_at}"
domain_id: "launchd-health-check"
severity: "${severity}"
title: "${title}"
summary: |-
$(printf '%s\n' "${summary}" | sed 's/^/  /')
suggested_recipient: "alerts@spine.ronny.works"
source_alert: "launchd-health-check"
flush_status: pending
INTENT
}

mapfile -t labels < <(yq -r '.labels[] | select(.state == "active" and .monitor == true) | .label' "$REGISTRY")
if [[ "${#labels[@]}" -eq 0 ]]; then
  echo "[launchd-health-check] no monitorable labels in registry"
  exit 0
fi

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
  enqueue_email_intent \
    "incident" \
    "LaunchAgent health check detected missing labels" \
    "missing=${missing} of total=${#labels[@]} labels. Missing labels: ${missing_labels[*]}"
fi
[[ "$missing" -eq 0 ]]
