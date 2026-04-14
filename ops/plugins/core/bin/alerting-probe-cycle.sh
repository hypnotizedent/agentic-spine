#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: alerting probe + dispatch every 15 minutes
# LaunchAgent: com.ronny.alerting-probe-cycle
# Node role: watcher_node
#
# Watcher v1 scope: probes only domains in the scoped external-escalation path.
# Domain filter is governed by stability.control.contract.yaml#watcher_v1_scope.
#
# Restored after spine-lite governance-layer removal deleted the prior
# wrapper and the `alerting.probe` / `alerting.dispatch` capability forms.
# This wrapper calls the alerting bin scripts directly at their canonical
# plugin paths; no capability indirection.

SPINE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)}"
INFISICAL_AGENT="${SPINE_ROOT}/ops/plugins/providers/bin/infisical-agent.sh"
PROBE_BIN="${SPINE_ROOT}/ops/plugins/core/alerting/bin/alerting-probe"
DISPATCH_BIN="${SPINE_ROOT}/ops/plugins/core/alerting/bin/alerting-dispatch"
SNAPSHOT_FILE="/tmp/spine-alerting-probe-latest.json"
RECOVERY_DISPATCH_BIN="${SPINE_ROOT}/ops/plugins/core/recovery/bin/recovery-dispatch"

# Watcher v1 scope: only probe domains in the scoped external-escalation path.
# Authority: stability.control.contract.yaml#watcher_v1_scope
WATCHER_V1_DOMAINS="infra-core-stack"

source "${SPINE_ROOT}/ops/lib/job-wrapper.sh"

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

# Source host-local watcher secret file if present, BEFORE Infisical hydration.
# This decouples the watcher interrupt path from infra-core-stack:
# if ALERTING_HA_URL and ALERTING_HA_TOKEN are already set from this file,
# the Infisical call (which depends on secrets.ronny.works on infra-core-stack)
# is never made.
#
# Mac path:  $HOME/.config/spine/watcher-alerting.env
# Linux path: /etc/spine/watcher-secrets.env
WATCHER_SECRET_FILE="${WATCHER_SECRET_FILE:-${HOME}/.config/spine/watcher-alerting.env}"
if [[ -f "$WATCHER_SECRET_FILE" ]]; then
  # shellcheck source=/dev/null
  set -a
  source "$WATCHER_SECRET_FILE"
  set +a
fi

hydrate_ha_alerting_secrets

[[ -x "${PROBE_BIN}" ]] || { echo "[alerting-probe-cycle] FAIL: missing probe bin: ${PROBE_BIN}" >&2; exit 1; }
[[ -x "${DISPATCH_BIN}" ]] || { echo "[alerting-probe-cycle] FAIL: missing dispatch bin: ${DISPATCH_BIN}" >&2; exit 1; }

if ! spine_job_run "alerting-probe-cycle:alerting.probe" "${PROBE_BIN}" --out "${SNAPSHOT_FILE}" --domains "${WATCHER_V1_DOMAINS}"; then
  spine_enqueue_email_intent \
    "control-plane-alerting" \
    "incident" \
    "alerting.probe failed" \
    "Scheduled alerting probe failed; dispatch was not executed." \
    "alerting-probe-cycle"
  exit 1
fi

if ! spine_job_run "alerting-probe-cycle:alerting.dispatch" "${DISPATCH_BIN}" --no-probe --snapshot "${SNAPSHOT_FILE}"; then
  spine_enqueue_email_intent \
    "control-plane-alerting" \
    "incident" \
    "alerting.dispatch failed" \
    "Scheduled alerting dispatch failed; review alerting logs and channel health." \
    "alerting-probe-cycle"
  exit 1
fi

# If alerting snapshot exposes failing_gates, opportunistically trigger deterministic recovery.
if command -v jq >/dev/null 2>&1 && [[ -f "$SNAPSHOT_FILE" && -x "$RECOVERY_DISPATCH_BIN" ]]; then
  while IFS= read -r gid; do
    [[ -n "$gid" ]] || continue
    "$RECOVERY_DISPATCH_BIN" --gate-id "$gid" --failure-class deterministic >/dev/null 2>&1 || true
  done < <(jq -r '([.failing_gates[]?] + [.domains[]?.failing_gates[]?]) | unique | .[]?' "$SNAPSHOT_FILE" 2>/dev/null || true)
fi

echo "[alerting-probe-cycle] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
