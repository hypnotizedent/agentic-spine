#!/usr/bin/env bash
# Shared Cloudflare API helpers for plugin scripts.
# Auth strategy: prefer scoped API token; fallback to global key only on auth/scope failure.

set -euo pipefail

CF_AUTH_MODE_EFFECTIVE="${CF_AUTH_MODE_EFFECTIVE:-}"
CF_AUTH_MODE_PREFERRED="${CF_AUTH_MODE_PREFERRED:-}"
CF_LAST_HTTP_STATUS=""
CF_LAST_MODE=""
CF_LAST_BODY=""

cf_require_auth() {
  if [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]; then
    CF_AUTH_MODE_PREFERRED="${CF_AUTH_MODE_PREFERRED:-token}"
    return 0
  fi
  if [[ -n "${CLOUDFLARE_AUTH_EMAIL:-}" && -n "${CLOUDFLARE_GLOBAL_API_KEY:-}" ]]; then
    CF_AUTH_MODE_PREFERRED="${CF_AUTH_MODE_PREFERRED:-global}"
    return 0
  fi
  echo "STOP: Cloudflare auth missing. Require CLOUDFLARE_API_TOKEN or CLOUDFLARE_AUTH_EMAIL+CLOUDFLARE_GLOBAL_API_KEY." >&2
  return 2
}

cf_has_global_auth() {
  [[ -n "${CLOUDFLARE_AUTH_EMAIL:-}" && -n "${CLOUDFLARE_GLOBAL_API_KEY:-}" ]]
}

cf_has_token_auth() {
  [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]
}

cf_is_fallback_status() {
  local status="${1:-}"
  [[ "$status" == "401" || "$status" == "403" || "$status" == "429" ]]
}

cf__curl_with_mode() {
  local mode="$1"
  local method="$2"
  local url="$3"
  local payload="${4:-}"

  local -a curl_cmd
  curl_cmd=(curl -sS -X "$method")

  if [[ "$mode" == "token" ]]; then
    curl_cmd+=(-H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}")
  else
    curl_cmd+=(-H "X-Auth-Email: ${CLOUDFLARE_AUTH_EMAIL}")
    curl_cmd+=(-H "X-Auth-Key: ${CLOUDFLARE_GLOBAL_API_KEY}")
  fi
  curl_cmd+=(-H "Content-Type: application/json")

  if [[ -n "$payload" ]]; then
    curl_cmd+=(--data "$payload")
  fi
  curl_cmd+=("$url" -w $'\n%{http_code}')

  local response body status
  if ! response="$("${curl_cmd[@]}" 2>&1)"; then
    CF_LAST_MODE="$mode"
    CF_LAST_HTTP_STATUS="000"
    CF_LAST_BODY="$response"
    return 1
  fi

  status="${response##*$'\n'}"
  body="${response%$'\n'*}"

  CF_LAST_MODE="$mode"
  CF_LAST_HTTP_STATUS="$status"
  CF_LAST_BODY="$body"

  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    printf '%s\n' "$body"
    return 0
  fi
  return 1
}

cf_api_request() {
  local method="$1"
  local url="$2"
  local payload="${3:-}"

  cf_require_auth || return $?

  # Preferred token path (secure default), fallback to global key on auth/scope failure.
  if [[ "${CF_AUTH_MODE_PREFERRED}" == "token" && "$(cf_has_token_auth && echo yes || echo no)" == "yes" ]]; then
    if cf__curl_with_mode "token" "$method" "$url" "$payload"; then
      CF_AUTH_MODE_EFFECTIVE="token"
      return 0
    fi
    if cf_is_fallback_status "${CF_LAST_HTTP_STATUS}" && cf_has_global_auth; then
      if cf__curl_with_mode "global" "$method" "$url" "$payload"; then
        CF_AUTH_MODE_PREFERRED="global"
        CF_AUTH_MODE_EFFECTIVE="global"
        return 0
      fi
    fi
    echo "STOP: Cloudflare API request failed (${method} ${url}) status=${CF_LAST_HTTP_STATUS} mode=${CF_LAST_MODE}" >&2
    [[ -n "${CF_LAST_BODY:-}" ]] && echo "$CF_LAST_BODY" >&2
    return 1
  fi

  if [[ "${CF_AUTH_MODE_PREFERRED}" == "global" && "$(cf_has_global_auth && echo yes || echo no)" == "yes" ]]; then
    if cf__curl_with_mode "global" "$method" "$url" "$payload"; then
      CF_AUTH_MODE_EFFECTIVE="global"
      return 0
    fi
    # If global key fails auth and token exists, allow a recovery attempt.
    if cf_is_fallback_status "${CF_LAST_HTTP_STATUS}" && cf_has_token_auth; then
      if cf__curl_with_mode "token" "$method" "$url" "$payload"; then
        CF_AUTH_MODE_PREFERRED="token"
        CF_AUTH_MODE_EFFECTIVE="token"
        return 0
      fi
    fi
    echo "STOP: Cloudflare API request failed (${method} ${url}) status=${CF_LAST_HTTP_STATUS} mode=${CF_LAST_MODE}" >&2
    [[ -n "${CF_LAST_BODY:-}" ]] && echo "$CF_LAST_BODY" >&2
    return 1
  fi

  # Fallback for unset/unknown preferred mode.
  if cf_has_token_auth; then
    CF_AUTH_MODE_PREFERRED="token"
    cf_api_request "$method" "$url" "$payload"
    return $?
  fi
  if cf_has_global_auth; then
    CF_AUTH_MODE_PREFERRED="global"
    cf_api_request "$method" "$url" "$payload"
    return $?
  fi

  echo "STOP: Cloudflare auth unavailable." >&2
  return 2
}

cf_api_get() {
  local url="$1"
  cf_api_request "GET" "$url"
}

cf_api_post() {
  local url="$1"
  local payload="${2:-}"
  cf_api_request "POST" "$url" "$payload"
}

cf_api_put() {
  local url="$1"
  local payload="${2:-}"
  cf_api_request "PUT" "$url" "$payload"
}

cf_api_delete() {
  local url="$1"
  cf_api_request "DELETE" "$url"
}

cf_zone_id_from_binding() {
  local binding_file="$1"
  local zone_name="$2"
  python3 - "$binding_file" "$zone_name" <<'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2].strip().lower()
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
for row in data.get("zones", []):
    if str(row.get("name", "")).strip().lower() == name:
        zid = str(row.get("id", "")).strip()
        if zid:
            print(zid)
            raise SystemExit(0)
raise SystemExit(0)
PY
}

cf_zone_id_lookup_live() {
  local cf_api="$1"
  local zone_name="$2"
  local resp
  resp="$(cf_api_get "${cf_api}/zones?name=${zone_name}&per_page=1")" || return 1
  printf '%s\n' "$resp" | python3 - <<'PY'
import json, sys
data = json.load(sys.stdin)
rows = data.get("result") or []
if rows:
    print(str(rows[0].get("id", "")).strip())
PY
}

cf_zone_id_resolve() {
  local cf_api="$1"
  local binding_file="$2"
  local zone_id="${3:-}"
  local zone_name="${4:-}"

  if [[ -n "$zone_id" ]]; then
    printf '%s\n' "$zone_id"
    return 0
  fi

  if [[ -z "$zone_name" ]]; then
    return 1
  fi

  local resolved=""
  if [[ -f "$binding_file" ]]; then
    resolved="$(cf_zone_id_from_binding "$binding_file" "$zone_name" || true)"
  fi
  if [[ -z "$resolved" ]]; then
    resolved="$(cf_zone_id_lookup_live "$cf_api" "$zone_name" || true)"
  fi

  if [[ -z "$resolved" ]]; then
    return 1
  fi
  printf '%s\n' "$resolved"
}

cf_account_id_resolve() {
  local binding_file="${1:-}"
  if [[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
    printf '%s\n' "${CLOUDFLARE_ACCOUNT_ID}"
    return 0
  fi

  if [[ -n "$binding_file" && -f "$binding_file" ]]; then
    command -v yq >/dev/null 2>&1 || return 1
    local resolved
    resolved="$(yq -r '.account_id // ""' "$binding_file" 2>/dev/null || true)"
    if [[ -n "$resolved" && "$resolved" != "null" ]]; then
      printf '%s\n' "$resolved"
      return 0
    fi
  fi

  return 1
}
