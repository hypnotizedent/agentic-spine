#!/usr/bin/env bash

_PLATFORM_CONTROL_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
_PLATFORM_CONTROL_BINDING="${_PLATFORM_CONTROL_ROOT}/ops/bindings/platform.control.surfaces.yaml"

if [[ ! -r "${_PLATFORM_CONTROL_ROOT}/ops/lib/ssh-resolve.sh" ]]; then
  echo "STOP: missing ssh-resolve helper at ${_PLATFORM_CONTROL_ROOT}/ops/lib/ssh-resolve.sh" >&2
  return 2 2>/dev/null || exit 2
fi

# shellcheck source=/Users/ronnyworks/code/agentic-spine/ops/lib/ssh-resolve.sh
source "${_PLATFORM_CONTROL_ROOT}/ops/lib/ssh-resolve.sh"

control_surface_binding_path() {
  printf '%s\n' "$_PLATFORM_CONTROL_BINDING"
}

control_surface_field() {
  local service_id="$1"
  local field_path="$2"
  yq -r ".services.${service_id}.${field_path} // \"\"" "$_PLATFORM_CONTROL_BINDING"
}

control_surface_has_service() {
  local service_id="$1"
  [[ -n "$(control_surface_field "$service_id" "service_registry_id")" ]]
}

control_surface_admin_url() {
  control_surface_field "$1" "admin_url"
}

control_surface_health_path() {
  local value
  value="$(control_surface_field "$1" "health_path")"
  printf '%s\n' "${value:-/}"
}

control_surface_secret_project() {
  control_surface_field "$1" "secrets.project"
}

control_surface_secret_path() {
  control_surface_field "$1" "secrets.path"
}

control_surface_mutation_mode() {
  control_surface_field "$1" "control.mutation_mode"
}

control_surface_mutation_surface() {
  control_surface_field "$1" "control.mutation_surface"
}

control_surface_runtime_wrapper() {
  control_surface_field "$1" "control.runtime_wrapper"
}

control_surface_backend_target() {
  control_surface_field "$1" "backend.ssh_target"
}

control_surface_backend_scheme() {
  local value
  value="$(control_surface_field "$1" "backend.scheme")"
  printf '%s\n' "${value:-http}"
}

control_surface_backend_port() {
  control_surface_field "$1" "backend.port"
}

control_surface_backend_host() {
  local target_id
  target_id="$(control_surface_backend_target "$1")"
  [[ -n "$target_id" ]] || return 1
  ssh_resolve_host "$target_id"
}

control_surface_backend_url() {
  local service_id="$1"
  local host port scheme
  host="$(control_surface_backend_host "$service_id")"
  port="$(control_surface_backend_port "$service_id")"
  scheme="$(control_surface_backend_scheme "$service_id")"
  [[ -n "$host" && -n "$port" ]] || return 1
  printf '%s://%s:%s\n' "$scheme" "$host" "$port"
}

control_surface_backend_resolved_url() {
  local service_id="$1"
  local timeout="${2:-3}"
  local target_id port scheme result resolved_host path_used
  target_id="$(control_surface_backend_target "$service_id")"
  port="$(control_surface_backend_port "$service_id")"
  scheme="$(control_surface_backend_scheme "$service_id")"
  [[ -n "$target_id" && -n "$port" ]] || return 1

  result="$(ssh_resolve_host_with_fallback "$target_id" "$timeout")" || true
  resolved_host="$(awk '{print $1}' <<<"$result")"
  path_used="$(awk '{print $2}' <<<"$result")"
  if [[ -z "$resolved_host" || "$path_used" == "unreachable" ]]; then
    return 1
  fi

  printf '%s://%s:%s %s\n' "$scheme" "$resolved_host" "$port" "$path_used"
}

control_surface_probe_url() {
  local service_id="$1"
  printf '%s%s\n' "$(control_surface_admin_url "$service_id")" "$(control_surface_health_path "$service_id")"
}

control_surface_git_transport_target() {
  control_surface_field "$1" "git_transport.ssh_target"
}

control_surface_git_transport_host_mode() {
  control_surface_field "$1" "git_transport.host_mode"
}

control_surface_git_transport_user() {
  local value
  value="$(control_surface_field "$1" "git_transport.ssh_user")"
  printf '%s\n' "${value:-git}"
}

control_surface_git_transport_port() {
  control_surface_field "$1" "git_transport.port"
}

control_surface_git_transport_host() {
  local service_id="$1"
  local target_id host_mode
  target_id="$(control_surface_git_transport_target "$service_id")"
  host_mode="$(control_surface_git_transport_host_mode "$service_id")"
  [[ -n "$target_id" ]] || return 1

  case "$host_mode" in
    tailscale_ip)
      ssh_resolve_tailscale_ip "$target_id"
      ;;
    host|"")
      ssh_resolve_host "$target_id"
      ;;
    *)
      return 1
      ;;
  esac
}

control_surface_git_origin_url() {
  local service_id="$1"
  local owner="$2"
  local repo_name="$3"
  local host port user
  host="$(control_surface_git_transport_host "$service_id")"
  port="$(control_surface_git_transport_port "$service_id")"
  user="$(control_surface_git_transport_user "$service_id")"
  [[ -n "$host" && -n "$port" && -n "$owner" && -n "$repo_name" ]] || return 1
  printf 'ssh://%s@%s:%s/%s/%s.git\n' "$user" "$host" "$port" "$owner" "$repo_name"
}
