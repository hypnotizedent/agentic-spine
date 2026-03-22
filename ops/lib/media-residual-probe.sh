#!/usr/bin/env bash

# Shared SSH resolution + parked-service helpers for residual media probes.

_MEDIA_RESIDUAL_ROOT="${MEDIA_RESIDUAL_PROBE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
_MEDIA_RESIDUAL_SERVICES_BINDING="${MEDIA_RESIDUAL_PROBE_SERVICES_BINDING:-${_MEDIA_RESIDUAL_ROOT}/ops/bindings/media.services.yaml}"

# shellcheck source=/dev/null
source "${_MEDIA_RESIDUAL_ROOT}/ops/lib/ssh-resolve.sh"

media_residual_probe_require_deps() {
  command -v yq >/dev/null 2>&1 || { echo "MISSING_DEP: yq" >&2; return 2; }
  command -v ssh >/dev/null 2>&1 || { echo "MISSING_DEP: ssh" >&2; return 2; }
}

media_residual_probe_init() {
  local target_id="$1"
  local timeout="${2:-10}"
  local default_user="${3:-ubuntu}"
  local result

  MEDIA_RESIDUAL_TARGET_ID="$target_id"
  MEDIA_RESIDUAL_TIMEOUT="$timeout"

  if [[ -n "${MEDIA_RESIDUAL_PROBE_RESOLUTION:-}" ]]; then
    result="$MEDIA_RESIDUAL_PROBE_RESOLUTION"
  else
    result="$(ssh_resolve_ssh_host_with_fallback "$target_id" "$timeout")" || true
  fi

  MEDIA_RESIDUAL_HOST="$(awk '{print $1}' <<<"$result")"
  MEDIA_RESIDUAL_PATH_USED="$(awk '{print $2}' <<<"$result")"

  if [[ -n "${MEDIA_RESIDUAL_PROBE_USER_OVERRIDE:-}" ]]; then
    MEDIA_RESIDUAL_USER="$MEDIA_RESIDUAL_PROBE_USER_OVERRIDE"
  else
    MEDIA_RESIDUAL_USER="$(ssh_resolve_user "$target_id" "$default_user")"
  fi

  MEDIA_RESIDUAL_SSH_OPTS=(
    -o "ConnectTimeout=${timeout}"
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o BatchMode=yes
    -o LogLevel=ERROR
  )

  [[ -n "$MEDIA_RESIDUAL_HOST" && "$MEDIA_RESIDUAL_HOST" != "null" && "$MEDIA_RESIDUAL_PATH_USED" != "unreachable" ]]
}

media_residual_probe_stop_unreachable() {
  local target_id="$1"
  echo "STOP: ${target_id} SSH target not reachable via canonical SSH resolution" >&2
}

media_residual_probe_ssh() {
  local remote_cmd="$1"
  if [[ -n "${MEDIA_RESIDUAL_PROBE_SSH_WRAPPER:-}" ]]; then
    "$MEDIA_RESIDUAL_PROBE_SSH_WRAPPER" \
      "$MEDIA_RESIDUAL_USER" \
      "$MEDIA_RESIDUAL_HOST" \
      "$MEDIA_RESIDUAL_TARGET_ID" \
      "$MEDIA_RESIDUAL_PATH_USED" \
      "$remote_cmd"
    return $?
  fi

  ssh "${MEDIA_RESIDUAL_SSH_OPTS[@]}" "${MEDIA_RESIDUAL_USER}@${MEDIA_RESIDUAL_HOST}" "$remote_cmd" 2>/dev/null
}

media_residual_service_status() {
  local service="$1"
  yq -r ".services.\"${service}\".status // \"\"" "$_MEDIA_RESIDUAL_SERVICES_BINDING" 2>/dev/null || echo ""
}

media_residual_service_is_parked() {
  [[ "$(media_residual_service_status "$1")" == "parked" ]]
}

media_residual_all_services_parked() {
  local service
  for service in "$@"; do
    media_residual_service_is_parked "$service" || return 1
  done
}
