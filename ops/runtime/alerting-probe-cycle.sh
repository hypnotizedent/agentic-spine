#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: alerting probe + dispatch every 15 minutes
# LaunchAgent: com.ronny.alerting-probe-cycle
# Gaps: GAP-OP-740

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
INFISICAL_AGENT="${SPINE_ROOT}/ops/tools/infisical-agent.sh"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

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

if ! spine_job_run "alerting-probe-cycle:alerting.probe" "$CAP_RUNNER" cap run alerting.probe; then
  spine_enqueue_email_intent \
    "control-plane-alerting" \
    "incident" \
    "alerting.probe failed" \
    "Scheduled alerting probe failed; dispatch was not executed." \
    "alerting-probe-cycle"
  exit 1
fi

if ! spine_job_run "alerting-probe-cycle:alerting.dispatch" "$CAP_RUNNER" cap run alerting.dispatch; then
  spine_enqueue_email_intent \
    "control-plane-alerting" \
    "incident" \
    "alerting.dispatch failed" \
    "Scheduled alerting dispatch failed; review alerting logs and channel health." \
    "alerting-probe-cycle"
  exit 1
fi

echo "[alerting-probe-cycle] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
