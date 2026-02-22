#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

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
  local outbox_file="$ROOT/$(yq -r '.channels."bridge-push".outbox_file // "mailroom/outbox/alerts/bridge-push.log"' "$ROOT/ops/bindings/alerting.rules.yaml")"
  mkdir -p "$(dirname "$outbox_file")"

  {
    echo "[$(alert_now_utc)] $(basename "$alert_file")"
    yq -r '.summary' "$alert_file"
  } >>"$outbox_file"

  return 0
}

alert_channel_ha() {
  local alert_file="$1"
  local ha_url_var ha_token_var ha_url ha_token service_path url title message

  ha_url_var="$(yq -r '.channels.ha.endpoint_env // "ALERTING_HA_URL"' "$ROOT/ops/bindings/alerting.rules.yaml")"
  ha_token_var="$(yq -r '.channels.ha.token_env // "ALERTING_HA_TOKEN"' "$ROOT/ops/bindings/alerting.rules.yaml")"
  service_path="$(yq -r '.channels.ha.service_path // "/api/services/persistent_notification/create"' "$ROOT/ops/bindings/alerting.rules.yaml")"

  ha_url="${!ha_url_var:-}"
  ha_token="${!ha_token_var:-}"

  if [[ -z "$ha_url" || -z "$ha_token" ]]; then
    echo "WARN alerting.dispatch: HA channel skipped (missing ${ha_url_var}/${ha_token_var})" >&2
    return 0
  fi

  title="$(alert_yaml '.title' "$alert_file")"
  message="$(alert_yaml '.summary' "$alert_file")"
  url="${ha_url%/}${service_path}"

  curl -fsS -X POST "$url" \
    -H "Authorization: Bearer $ha_token" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg t "$title" --arg m "$message" '{title:$t, message:$m}')" >/dev/null
}

alert_channel_email_intent() {
  local alert_file="$1"
  local intent_dir="$ROOT/mailroom/outbox/alerts/email-intents"
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
suggested_recipient: "alerts@spine.mintprints.co"
source_alert: "$(basename "$alert_file")"
flush_status: pending
INTENT

  return 0
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
    *)
      echo "WARN alerting.dispatch: unknown channel '$channel'" >&2
      return 1
      ;;
  esac
}
