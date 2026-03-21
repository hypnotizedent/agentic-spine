#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# endpoint-resolve.sh — Service endpoint resolution for spine
# ═══════════════════════════════════════════════════════════════
#
# Source this in any gate or capability that needs service endpoints.
# Reads from topology.closure.graph.yaml (service_endpoints) and
# resolves hosts via ssh-resolve.sh.
#
# Usage:
#   source "${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/ops/lib/endpoint-resolve.sh"
#
#   # Resolve a service health URL with transport-aware fallback
#   url="$(endpoint_resolve_health_url "radarr")"
#   # => http://192.168.1.209:7878/ping  (or Tailscale IP if LAN unreachable)
#
#   # Resolve just the base URL (no health path)
#   base="$(endpoint_resolve_base_url "radarr")"
#   # => http://192.168.1.209:7878
#
#   # Get endpoint metadata
#   port="$(endpoint_resolve_port "radarr")"        # => 7878
#   path="$(endpoint_resolve_health_path "radarr")"  # => /ping
#   host_ref="$(endpoint_resolve_host_ref "radarr")" # => download-stack
#
# Depends on: ssh-resolve.sh (sourced automatically if not already loaded)
#
# ═══════════════════════════════════════════════════════════════

_ENDPOINT_RESOLVE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
_ENDPOINT_RESOLVE_GRAPH="${_ENDPOINT_RESOLVE_ROOT}/ops/bindings/topology.closure.graph.yaml"

# Source ssh-resolve.sh if not already loaded
if ! type -t ssh_resolve_host >/dev/null 2>&1; then
  # shellcheck source=ssh-resolve.sh
  source "${_ENDPOINT_RESOLVE_ROOT}/ops/lib/ssh-resolve.sh"
fi

# ─── Field accessors ───

endpoint_resolve_host_ref() {
  local service_id="$1"
  yq -r ".service_endpoints[\"$service_id\"].host_ref // \"\"" \
    "$_ENDPOINT_RESOLVE_GRAPH" 2>/dev/null || echo ""
}

endpoint_resolve_port() {
  local service_id="$1"
  yq -r ".service_endpoints[\"$service_id\"].port // \"\"" \
    "$_ENDPOINT_RESOLVE_GRAPH" 2>/dev/null || echo ""
}

endpoint_resolve_health_path() {
  local service_id="$1"
  yq -r ".service_endpoints[\"$service_id\"].health_path // \"\"" \
    "$_ENDPOINT_RESOLVE_GRAPH" 2>/dev/null || echo ""
}

endpoint_resolve_health_expect() {
  local service_id="$1"
  yq -r ".service_endpoints[\"$service_id\"].health_expect // \"200\"" \
    "$_ENDPOINT_RESOLVE_GRAPH" 2>/dev/null || echo "200"
}

endpoint_resolve_protocol() {
  local service_id="$1"
  yq -r ".service_endpoints[\"$service_id\"].protocol // \"http\"" \
    "$_ENDPOINT_RESOLVE_GRAPH" 2>/dev/null || echo "http"
}

endpoint_resolve_address_source() {
  local service_id="$1"
  yq -r ".service_endpoints[\"$service_id\"].address_source // \"\"" \
    "$_ENDPOINT_RESOLVE_GRAPH" 2>/dev/null || echo ""
}

endpoint_resolve_public_url() {
  local service_id="$1"
  yq -r ".service_endpoints[\"$service_id\"].public_url // \"\"" \
    "$_ENDPOINT_RESOLVE_GRAPH" 2>/dev/null || echo ""
}

# ─── Compound resolvers ───

# Resolve the runtime host IP for a service, honoring access_policy
# and address_source overrides.
# Returns: "resolved_ip path_used" (space-separated)
endpoint_resolve_host() {
  local service_id="$1"
  local timeout="${2:-3}"
  local host_ref address_source

  host_ref="$(endpoint_resolve_host_ref "$service_id")"
  [[ -n "$host_ref" && "$host_ref" != "null" ]] || {
    echo "ENDPOINT_RESOLVE_ERROR: no host_ref for service '$service_id'" >&2
    return 1
  }

  address_source="$(endpoint_resolve_address_source "$service_id")"

  # Some services (like mint-modules-minio) always use tailscale_ip
  if [[ "$address_source" == "tailscale_ip" ]]; then
    local ts_ip
    ts_ip="$(ssh_resolve_tailscale_ip "$host_ref")"
    if [[ -n "$ts_ip" && "$ts_ip" != "null" ]]; then
      printf '%s tailscale\n' "$ts_ip"
      return 0
    fi
  fi

  # Default: use ssh_resolve_host_with_fallback for transport-aware resolution
  ssh_resolve_host_with_fallback "$host_ref" "$timeout"
}

# Resolve a full base URL: {protocol}://{resolved_ip}:{port}
# Returns: "url path_used" (space-separated)
endpoint_resolve_base_url() {
  local service_id="$1"
  local timeout="${2:-3}"
  local protocol port result resolved_ip path_used

  protocol="$(endpoint_resolve_protocol "$service_id")"
  port="$(endpoint_resolve_port "$service_id")"

  [[ -n "$port" && "$port" != "null" ]] || {
    echo "ENDPOINT_RESOLVE_ERROR: no port for service '$service_id'" >&2
    return 1
  }

  result="$(endpoint_resolve_host "$service_id" "$timeout")" || {
    printf '%s unreachable\n' "${protocol}://unknown:${port}"
    return 1
  }
  resolved_ip="$(echo "$result" | awk '{print $1}')"
  path_used="$(echo "$result" | awk '{print $2}')"

  printf '%s://%s:%s %s\n' "$protocol" "$resolved_ip" "$port" "$path_used"
}

# Resolve a full health check URL: {protocol}://{resolved_ip}:{port}{health_path}
# Returns: "url path_used" (space-separated)
endpoint_resolve_health_url() {
  local service_id="$1"
  local timeout="${2:-3}"
  local health_path result base_url path_used

  health_path="$(endpoint_resolve_health_path "$service_id")"
  [[ -n "$health_path" && "$health_path" != "null" ]] || {
    echo "ENDPOINT_RESOLVE_ERROR: no health_path for service '$service_id'" >&2
    return 1
  }

  result="$(endpoint_resolve_base_url "$service_id" "$timeout")" || return 1
  base_url="$(echo "$result" | awk '{print $1}')"
  path_used="$(echo "$result" | awk '{print $2}')"

  printf '%s%s %s\n' "$base_url" "$health_path" "$path_used"
}

# List all service IDs in the topology graph
endpoint_list_services() {
  yq -r '.service_endpoints | keys | .[]' "$_ENDPOINT_RESOLVE_GRAPH" 2>/dev/null
}

# List all services on a given host_ref
endpoint_list_services_on_host() {
  local host_ref="$1"
  yq -r ".service_endpoints | to_entries[] | select(.value.host_ref == \"$host_ref\") | .key" \
    "$_ENDPOINT_RESOLVE_GRAPH" 2>/dev/null
}

# Get dependency edges FROM a service (what it depends on)
endpoint_resolve_dependencies() {
  local service_id="$1"
  yq -r ".dependency_edges[] | select(.from == \"$service_id\") | .to" \
    "$_ENDPOINT_RESOLVE_GRAPH" 2>/dev/null
}

# Get dependency edges TO a service (what depends on it)
endpoint_resolve_dependents() {
  local service_id="$1"
  yq -r ".dependency_edges[] | select(.to == \"$service_id\") | .from" \
    "$_ENDPOINT_RESOLVE_GRAPH" 2>/dev/null
}

# Check if a service has cross-VM dependencies
endpoint_has_cross_vm_deps() {
  local service_id="$1"
  local count
  count="$(yq -r "[.dependency_edges[] | select(.from == \"$service_id\" and .cross_vm == true)] | length" \
    "$_ENDPOINT_RESOLVE_GRAPH" 2>/dev/null || echo "0")"
  [[ "$count" -gt 0 ]]
}
