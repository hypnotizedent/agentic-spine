#!/usr/bin/env bash
# registry helpers for ops commands
set -eo pipefail

if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fi

REGISTRY_FILE="$REPO_ROOT/docs/governance/SERVICE_REGISTRY.yaml"

require_yq() {
  if ! command -v yq >/dev/null 2>&1; then
    echo "yq is required to read $REGISTRY_FILE" >&2
    return 1
  fi
}

require_registry_file() {
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    echo "Missing $REGISTRY_FILE" >&2
    return 1
  fi
}

resolve_service_field() {
  local service="$1"
  local field="$2"
  require_yq || return 1
  require_registry_file || return 1
  yq -r ".services[\"$service\"].$field // \"\"" "$REGISTRY_FILE"
}

resolve_host_ip() {
  local host="$1"
  require_yq || return 1
  require_registry_file || return 1
  local ip
  ip=$(yq -r ".hosts[\"$host\"].tailscale_ip // \"\"" "$REGISTRY_FILE")
  if [[ -n "$ip" ]]; then
    echo "$ip"
  else
    echo "$host"
  fi
}

get_service_host() {
  resolve_service_field "$1" host
}

get_service_health_url() {
  local service="$1"
  local host
  host=$(get_service_host "$service")
  if [[ -z "$host" ]]; then
    return 1
  fi

  local port
  port=$(resolve_service_field "$service" port)
  local health
  health=$(resolve_service_field "$service" health)
  [[ -z "$health" ]] && health="/health"

  local base_ip
  base_ip=$(resolve_host_ip "$host")

  local port_suffix=""
  if [[ -n "$port" ]]; then
    port_suffix=":$port"
  fi

  echo "http://${base_ip}${port_suffix}${health}"
}
