#!/usr/bin/env bash
# Home Assistant service call adapter (L2 shared infrastructure).
#
# Owns: HA REST API call, bearer auth, JSON payload construction.
# Does NOT own: alerting policy, channel selection, severity gates.
#
# Extracted from ops/plugins/core/alerting/lib/alert-channels.sh
# Loop: LOOP-SPINE-HA-ALERTING-ADAPTER-EXTRACTION-20260413
set -euo pipefail

# Resolve ROOT only if not already set by the sourcing caller.
: "${ROOT:="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"}"

# ha_service_call — POST to a Home Assistant service endpoint.
#
# Arguments:
#   $1  channel_key   — key into alerting.rules.yaml channels (e.g. "ha", "mobile-push")
#   $2  title         — notification title
#   $3  message       — notification body
#
# Reads endpoint_env, token_env, service_path from alerting.rules.yaml channels.$channel_key.
# Returns 0 on success, 1 on missing credentials or delivery failure.
ha_service_call() {
  local channel_key="$1"
  local title="$2"
  local message="$3"

  local ha_url_var ha_token_var ha_url ha_token service_path url

  ha_url_var="$(yq -r ".channels.\"${channel_key}\".endpoint_env // \"ALERTING_HA_URL\"" "$ROOT/ops/bindings/alerting.rules.yaml")"
  ha_token_var="$(yq -r ".channels.\"${channel_key}\".token_env // \"ALERTING_HA_TOKEN\"" "$ROOT/ops/bindings/alerting.rules.yaml")"
  service_path="$(yq -r ".channels.\"${channel_key}\".service_path" "$ROOT/ops/bindings/alerting.rules.yaml")"

  ha_url="${!ha_url_var:-}"
  ha_token="${!ha_token_var:-}"

  if [[ -z "$ha_url" || -z "$ha_token" ]]; then
    echo "WARN ha-provider: ${channel_key} channel skipped (missing ${ha_url_var}/${ha_token_var})" >&2
    return 1
  fi

  url="${ha_url%/}${service_path}"

  curl -fsS -X POST "$url" \
    -H "Authorization: Bearer $ha_token" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg t "$title" --arg m "$message" '{title:$t, message:$m}')" >/dev/null
}
