#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: alerting probe + dispatch every 15 minutes
# LaunchAgent: com.ronny.alerting-probe-cycle
# Gaps: GAP-OP-740

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
INFISICAL_AGENT="${SPINE_ROOT}/ops/tools/infisical-agent.sh"
EMAIL_INTENT_DIR="${SPINE_ROOT}/mailroom/outbox/alerts/email-intents"

enqueue_email_intent() {
  local domain_id="$1"
  local severity="$2"
  local title="$3"
  local summary="$4"
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
source_alert: "alerting-probe-cycle"
flush_status: pending
INTENT
}

hydrate_ha_alerting_secrets() {
  local ha_url_candidate ha_token_candidate
  [[ -x "${INFISICAL_AGENT}" ]] || return 0
  if [[ -z "${ALERTING_HA_URL:-}" ]]; then
    ha_url_candidate="$("${INFISICAL_AGENT}" get-cached infrastructure prod ALERTING_HA_URL 2>/dev/null || true)"
    if [[ "${ha_url_candidate}" =~ ^https?://[^[:space:]]+$ ]]; then
      ALERTING_HA_URL="${ha_url_candidate}"
      export ALERTING_HA_URL
    fi
  fi
  if [[ -z "${ALERTING_HA_TOKEN:-}" ]]; then
    ha_token_candidate="$("${INFISICAL_AGENT}" get-cached infrastructure prod ALERTING_HA_TOKEN 2>/dev/null || true)"
    if [[ -n "${ha_token_candidate}" && "${ha_token_candidate}" != *[[:space:]]* ]]; then
      ALERTING_HA_TOKEN="${ha_token_candidate}"
      export ALERTING_HA_TOKEN
    fi
  fi
}

echo "[alerting-probe-cycle] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

hydrate_ha_alerting_secrets

if ! "$CAP_RUNNER" cap run alerting.probe; then
  enqueue_email_intent \
    "control-plane-alerting" \
    "incident" \
    "alerting.probe failed" \
    "Scheduled alerting probe failed; dispatch was not executed."
  exit 1
fi

if ! "$CAP_RUNNER" cap run alerting.dispatch; then
  enqueue_email_intent \
    "control-plane-alerting" \
    "incident" \
    "alerting.dispatch failed" \
    "Scheduled alerting dispatch failed; review alerting logs and channel health."
  exit 1
fi

echo "[alerting-probe-cycle] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
