#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths

# L2 provider adapter for Home Assistant service calls.
source "$ROOT/ops/plugins/providers/homeassistant/lib/ha-service-call.sh"

alert_now_epoch() {
  date +%s
}

alert_now_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

alert_yaml() {
  local expr="$1"
  local file="$2"
  yq -r "$expr" "$file"
}

alert_channel_bridge_push() {
  local alert_file="$1"
  local outbox_rel
  outbox_rel="$(yq -r '.channels."bridge-push".outbox_file // ""' "$ROOT/ops/bindings/alerting.rules.yaml")"
  [[ -n "$outbox_rel" && "$outbox_rel" != "null" ]] || outbox_rel="$SPINE_OUTBOX/alerts/bridge-push.log"
  local outbox_file
  outbox_file="$(spine_resolve_mailroom_path "$outbox_rel")"
  mkdir -p "$(dirname "$outbox_file")"

  {
    echo "[$(alert_now_utc)] $(basename "$alert_file")"
    yq -r '.summary' "$alert_file"
  } >>"$outbox_file"

  return 0
}

alert_channel_ha() {
  local alert_file="$1"
  local title message
  title="$(alert_yaml '.title' "$alert_file")"
  message="$(alert_yaml '.summary' "$alert_file")"
  ha_service_call "ha" "$title" "$message"
}

alert_channel_email_intent() {
  local alert_file="$1"
  local intent_dir="$SPINE_OUTBOX/alerts/email-intents"
  mkdir -p "$intent_dir"

  local domain_id status title summary created_at intent_id intent_file
  domain_id="$(alert_yaml '.domain_id' "$alert_file")"
  status="$(alert_yaml '.status' "$alert_file")"
  title="$(alert_yaml '.title' "$alert_file")"
  summary="$(alert_yaml '.summary' "$alert_file")"
  created_at="$(alert_now_utc)"
  intent_id="email-intent-$(date -u +%Y%m%dT%H%M%SZ)-${RANDOM}"
  intent_file="$intent_dir/${intent_id}.yaml"

  cat >"$intent_file" <<INTENT
intent_id: "${intent_id}"
created_at: "${created_at}"
domain_id: "${domain_id}"
severity: "${status}"
title: "${title}"
summary: "${summary}"
suggested_recipient: "alerts@spine.ronny.works"
source_alert: "$(basename "$alert_file")"
flush_status: pending
INTENT

  return 0
}

alert_channel_mobile_push() {
  local alert_file="$1"

  # L1 policy gate: mobile-push is scoped to operator-critical-interrupt.
  # Skip silently for non-incident alerts.
  local alert_status
  alert_status="$(alert_yaml '.status' "$alert_file")"
  if [[ "$alert_status" != "incident" ]]; then
    return 0
  fi

  local title message
  title="$(alert_yaml '.title' "$alert_file")"
  message="$(alert_yaml '.summary' "$alert_file")"
  ha_service_call "mobile-push" "$title" "$message"
}

alert_dispatch_channel() {
  local channel="$1"
  local alert_file="$2"

  case "$channel" in
    ha)
      alert_channel_ha "$alert_file"
      ;;
    bridge-push)
      alert_channel_bridge_push "$alert_file"
      ;;
    email)
      alert_channel_email_intent "$alert_file"
      ;;
    mobile-push)
      alert_channel_mobile_push "$alert_file"
      ;;
    *)
      echo "WARN alerting.dispatch: unknown channel '$channel'" >&2
      return 1
      ;;
  esac
}
