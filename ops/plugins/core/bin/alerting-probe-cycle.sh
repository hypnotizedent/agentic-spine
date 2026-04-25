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

_watcher_cycle_start_epoch="$(date +%s)"
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

# --- Node-centric receipt: rolling cycle state ---
# Every cycle writes governed execution evidence to a state file discoverable
# through the capability layer (watcher.health). Replaces the old model where
# a human had to SSH to the watcher node to determine cycle health.
WATCHER_CYCLE_STATE="${SPINE_LOGS:-${HOME}/code/.runtime/spine/logs}/watcher-cycle-state.json"
WATCHER_CYCLE_MAX=20
WATCHER_THRESHOLD_DEGRADED=2
WATCHER_THRESHOLD_INTERVENTION=5

_watcher_write_cycle_state() {
  local cycle_status="$1"
  local cycle_duration="$2"
  local cycle_at
  cycle_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  command -v jq >/dev/null 2>&1 || return 0
  mkdir -p "$(dirname "$WATCHER_CYCLE_STATE")"

  local prev_state="{}"
  if [[ -f "$WATCHER_CYCLE_STATE" ]]; then
    prev_state="$(jq -c '.' "$WATCHER_CYCLE_STATE" 2>/dev/null || echo '{}')"
  fi

  local prev_consecutive_successes prev_consecutive_failures prev_last_success prev_last_failure prev_cycles
  prev_consecutive_successes="$(jq -r '.consecutive_successes // 0' <<<"$prev_state")"
  prev_consecutive_failures="$(jq -r '.consecutive_failures // 0' <<<"$prev_state")"
  prev_last_success="$(jq -r '.last_success_at // null' <<<"$prev_state")"
  prev_last_failure="$(jq -r '.last_failure_at // null' <<<"$prev_state")"
  prev_cycles="$(jq -c '.cycles // []' <<<"$prev_state")"

  local new_consecutive_successes=0 new_consecutive_failures=0
  local new_last_success="$prev_last_success" new_last_failure="$prev_last_failure"

  if [[ "$cycle_status" == "success" ]]; then
    new_consecutive_successes=$(( prev_consecutive_successes + 1 ))
    new_consecutive_failures=0
    new_last_success="$cycle_at"
  else
    new_consecutive_successes=0
    new_consecutive_failures=$(( prev_consecutive_failures + 1 ))
    new_last_failure="$cycle_at"
  fi

  local health="healthy"
  if (( new_consecutive_failures >= WATCHER_THRESHOLD_INTERVENTION )); then
    health="failed"
  elif (( new_consecutive_failures >= WATCHER_THRESHOLD_DEGRADED )); then
    health="degraded"
  fi

  local probe_status="unknown"
  if [[ -f "$SNAPSHOT_FILE" ]]; then
    probe_status="$(jq -r '.status // "unknown"' "$SNAPSHOT_FILE" 2>/dev/null || echo "unknown")"
  fi
  local alerts_created=0
  if [[ -f "$SNAPSHOT_FILE" ]]; then
    alerts_created="$(jq -r '.incident_count // 0' "$SNAPSHOT_FILE" 2>/dev/null || echo 0)"
  fi

  local new_cycle
  new_cycle="$(jq -cn \
    --arg at "$cycle_at" \
    --arg status "$cycle_status" \
    --argjson duration_s "$cycle_duration" \
    --arg probe_status "$probe_status" \
    --argjson alerts_created "$alerts_created" \
    '{at:$at,status:$status,duration_s:$duration_s,probe_status:$probe_status,alerts_created:$alerts_created}')"

  local updated_cycles
  updated_cycles="$(jq -c --argjson new "$new_cycle" --argjson max "$WATCHER_CYCLE_MAX" \
    '[$new] + . | .[:$max]' <<<"$prev_cycles")"

  # Threshold-based intervention birth: if consecutive failures cross the
  # intervention threshold, scaffold a governed intervention artifact.
  # This runs BEFORE state write so the pending count is accurate.
  if (( new_consecutive_failures == WATCHER_THRESHOLD_INTERVENTION )); then
    spine_enqueue_email_intent \
      "watcher-self-health" \
      "incident" \
      "Watcher intervention: ${new_consecutive_failures} consecutive probe failures" \
      "The watcher alerting-probe-cycle has failed ${new_consecutive_failures} consecutive times. Health: ${health}. Last failure: ${cycle_at}. Manual investigation required." \
      "watcher-cycle-state"

    # Generic intervention packet — shared schema with standing-program-intervention-birth
    local intervention_dir="${SPINE_STATE:-${HOME}/code/.runtime/spine/state}/interventions"
    mkdir -p "$intervention_dir"
    local _trigger_at
    _trigger_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local intervention_file="${intervention_dir}/INT-com.ronny.alerting-probe-cycle--failure.yaml"

    # Dedupe: only birth if no active intervention exists for this label::trigger_type
    local _skip=false
    if [[ -f "$intervention_file" ]]; then
      local _existing_disp
      _existing_disp="$(grep -m1 '^disposition:' "$intervention_file" 2>/dev/null | awk '{print $2}' | tr -d '"' || true)"
      if [[ "$_existing_disp" == "active" ]]; then
        _skip=true
      fi
    fi

    if ! $_skip; then
      cat > "$intervention_file" <<INTERVENTION
intervention_id: "INT-com.ronny.alerting-probe-cycle--failure"
label: "com.ronny.alerting-probe-cycle"
birth_mode: "standing_program"
trigger_type: "failure"
disposition: "active"
triggered_at_utc: "${_trigger_at}"
proof_channel:
  type: "cycle_state"
  host: "proxmox-home"
  stale_threshold_seconds: 1200
observed:
  health: "${health}"
  last_evidence_at_utc: "${cycle_at}"
  consecutive_failures: ${new_consecutive_failures}
  detail: "consecutive_failures >= ${WATCHER_THRESHOLD_INTERVENTION}"
INTERVENTION
      echo "[alerting-probe-cycle] INTERVENTION birthed: ${intervention_file}"
    else
      echo "[alerting-probe-cycle] INTERVENTION already active, skipping dedupe"
    fi
  fi

  # Count active interventions (generic schema — all INT-*.yaml files)
  local intervention_dir="${SPINE_STATE:-${HOME}/code/.runtime/spine/state}/interventions"
  local pending_count=0
  if [[ -d "$intervention_dir" ]]; then
    while IFS= read -r _f; do
      [[ -f "$_f" ]] || continue
      local _disp
      _disp="$(grep -m1 '^disposition:' "$_f" 2>/dev/null | awk '{print $2}' | tr -d '"' || true)"
      if [[ "$_disp" == "active" ]]; then
        pending_count=$((pending_count + 1))
      fi
    done < <(find "$intervention_dir" -name 'INT-*.yaml' -type f 2>/dev/null || true)
  fi

  # Write cycle state with embedded intervention count
  jq -n \
    --arg node "watcher_node" \
    --arg program "alerting-probe-cycle" \
    --arg last_run_at "$cycle_at" \
    --arg last_run_status "$cycle_status" \
    --arg last_success_at "$new_last_success" \
    --arg last_failure_at "$new_last_failure" \
    --argjson consecutive_successes "$new_consecutive_successes" \
    --argjson consecutive_failures "$new_consecutive_failures" \
    --arg health "$health" \
    --argjson cycles "$updated_cycles" \
    --argjson threshold_degraded "$WATCHER_THRESHOLD_DEGRADED" \
    --argjson threshold_intervention "$WATCHER_THRESHOLD_INTERVENTION" \
    --argjson pending_interventions "$pending_count" \
    '{
      node: $node,
      program: $program,
      last_run_at: $last_run_at,
      last_run_status: $last_run_status,
      last_success_at: $last_success_at,
      last_failure_at: (if $last_failure_at == "null" then null else $last_failure_at end),
      consecutive_successes: $consecutive_successes,
      consecutive_failures: $consecutive_failures,
      health: $health,
      pending_interventions: $pending_interventions,
      cycles: $cycles,
      threshold: {
        failure_count_for_degraded: $threshold_degraded,
        failure_count_for_intervention: $threshold_intervention
      }
    }' > "${WATCHER_CYCLE_STATE}.tmp" && mv "${WATCHER_CYCLE_STATE}.tmp" "$WATCHER_CYCLE_STATE"
}

_watcher_exit_with_failure() {
  local duration=$(( $(date +%s) - _watcher_cycle_start_epoch ))
  [[ "$duration" =~ ^[0-9]+$ ]] || duration=0
  _watcher_write_cycle_state "failure" "$duration"
  exit 1
}

# --- Execution ---

[[ -x "${PROBE_BIN}" ]] || { echo "[alerting-probe-cycle] FAIL: missing probe bin: ${PROBE_BIN}" >&2; exit 1; }
[[ -x "${DISPATCH_BIN}" ]] || { echo "[alerting-probe-cycle] FAIL: missing dispatch bin: ${DISPATCH_BIN}" >&2; exit 1; }

if ! spine_job_run "alerting-probe-cycle:alerting.probe" "${PROBE_BIN}" --out "${SNAPSHOT_FILE}" --domains "${WATCHER_V1_DOMAINS}"; then
  spine_enqueue_email_intent \
    "control-plane-alerting" \
    "incident" \
    "alerting.probe failed" \
    "Scheduled alerting probe failed; dispatch was not executed." \
    "alerting-probe-cycle"
  _watcher_exit_with_failure
fi

if ! spine_job_run "alerting-probe-cycle:alerting.dispatch" "${DISPATCH_BIN}" --no-probe --snapshot "${SNAPSHOT_FILE}"; then
  spine_enqueue_email_intent \
    "control-plane-alerting" \
    "incident" \
    "alerting.dispatch failed" \
    "Scheduled alerting dispatch failed; review alerting logs and channel health." \
    "alerting-probe-cycle"
  _watcher_exit_with_failure
fi

# If alerting snapshot exposes failing_gates, opportunistically trigger deterministic recovery.
if command -v jq >/dev/null 2>&1 && [[ -f "$SNAPSHOT_FILE" && -x "$RECOVERY_DISPATCH_BIN" ]]; then
  while IFS= read -r gid; do
    [[ -n "$gid" ]] || continue
    "$RECOVERY_DISPATCH_BIN" --gate-id "$gid" --failure-class deterministic >/dev/null 2>&1 || true
  done < <(jq -r '([.failing_gates[]?] + [.domains[]?.failing_gates[]?]) | unique | .[]?' "$SNAPSHOT_FILE" 2>/dev/null || true)
fi

echo "[alerting-probe-cycle] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Write cycle receipt — success path
_watcher_cycle_duration=$(( $(date +%s) - _watcher_cycle_start_epoch ))
[[ "$_watcher_cycle_duration" =~ ^[0-9]+$ ]] || _watcher_cycle_duration=0
_watcher_write_cycle_state "success" "$_watcher_cycle_duration"
