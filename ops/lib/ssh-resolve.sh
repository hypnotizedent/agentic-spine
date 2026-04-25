#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# ssh-resolve.sh — Shared SSH target resolution for spine gates
# ═══════════════════════════════════════════════════════════════
#
# Source this in any gate or capability that SSHes to targets.
# Reads from ops/bindings/ssh.targets.yaml (SSOT).
#
# Usage:
#   source "${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/ops/lib/ssh-resolve.sh"
#   ref="$(ssh_resolve_ref "download-stack")"    # => ubuntu@192.168.1.209
#   host="$(ssh_resolve_host "download-stack")"  # => 192.168.1.209
#   user="$(ssh_resolve_user "download-stack")"  # => ubuntu
#
# RESOLVER CHOICE (CRITICAL):
#   - For SSH/deploy/docker operations: Use ssh_resolve_ssh_host_with_fallback (TCP/22 test)
#   - For HTTP-only health probes: Use ssh_resolve_host_with_fallback (ICMP ping)
#   - NEVER use ping-based resolver for deploy/mutation operations
#   - See: docs/reference/audits/AOF_NORMALIZATION_DRIFT_AUDIT_20260309.md
#
# ═══════════════════════════════════════════════════════════════

_SSH_RESOLVE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
_SSH_RESOLVE_BINDING="${_SSH_RESOLVE_ROOT}/ops/bindings/ssh.targets.yaml"

# ── Network location detection (cached per shell session) ──
# Determines whether this machine has a direct route to the shop LAN (192.168.1.0/24).
# If not, lan_first targets should skip the LAN attempt and go straight to Tailscale.
# This avoids 3-5 second timeouts per target when running from outside the shop.
_SSH_RESOLVE_ON_SHOP_LAN=""
_ssh_resolve_is_on_shop_lan() {
  if [[ -z "$_SSH_RESOLVE_ON_SHOP_LAN" ]]; then
    if ifconfig 2>/dev/null | grep -q 'inet 192\.168\.1\.' || \
       ip -4 addr show 2>/dev/null | grep -q 'inet 192\.168\.1\.'; then
      _SSH_RESOLVE_ON_SHOP_LAN="yes"
    else
      _SSH_RESOLVE_ON_SHOP_LAN="no"
    fi
  fi
  [[ "$_SSH_RESOLVE_ON_SHOP_LAN" == "yes" ]]
}

ssh_resolve_host() {
  local target_id="$1"
  yq -r ".ssh.targets[] | select(.id == \"$target_id\") | .host // \"\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || echo ""
}

ssh_resolve_user() {
  local target_id="$1"
  local default_user="${2:-ubuntu}"
  local user
  user="$(yq -r ".ssh.targets[] | select(.id == \"$target_id\") | .user // \"\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || true)"
  printf '%s\n' "${user:-$default_user}"
}

ssh_resolve_ref() {
  local target_id="$1"
  local host user
  host="$(ssh_resolve_host "$target_id")"
  user="$(ssh_resolve_user "$target_id")"
  [[ -n "$host" ]] || return 1
  printf '%s@%s\n' "$user" "$host"
}

ssh_resolve_tailscale_ip() {
  local target_id="$1"
  yq -r ".ssh.targets[] | select(.id == \"$target_id\") | .tailscale_ip // .host // \"\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || echo ""
}

ssh_resolve_primary_alias() {
  local target_id="$1"
  yq -r ".ssh.targets[] | select(.id == \"$target_id\") | (.aliases // [])[0] // \"\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || echo ""
}

ssh_resolve_access_policy() {
  local target_id="$1"
  yq -r ".ssh.targets[] | select(.id == \"$target_id\") | .access_policy // \"lan_first\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || echo "lan_first"
}

# ── Machine auth-origin identity resolution ──
# Resolves governed machine identity parallel to route resolution.

# Returns: explicit | ambient
ssh_resolve_machine_auth_origin() {
  local target_id="$1"
  local per_target per_target_file default_origin
  per_target="$(yq -r ".ssh.targets[] | select(.id == \"$target_id\") | .machine_auth_origin // \"\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || true)"
  per_target_file="$(yq -r ".ssh.targets[] | select(.id == \"$target_id\") | .machine_identity_file // \"\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || true)"
  if [[ -n "$per_target" ]]; then
    printf '%s\n' "$per_target"
    return
  fi
  if [[ -n "$per_target_file" ]]; then
    printf 'explicit\n'
    return
  fi
  default_origin="$(yq -r '.ssh.defaults.machine_auth_origin // "explicit"' \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || true)"
  printf '%s\n' "${default_origin:-explicit}"
}

# Returns the identity file path (expanded ~ if present).
ssh_resolve_machine_identity_file() {
  local target_id="$1"
  local per_target default_file resolved
  per_target="$(yq -r ".ssh.targets[] | select(.id == \"$target_id\") | .machine_identity_file // \"\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || true)"
  if [[ -n "$per_target" ]]; then
    resolved="${per_target/#\~/$HOME}"
    printf '%s\n' "$resolved"
    return
  fi
  default_file="$(yq -r '.ssh.defaults.machine_identity_file // ""' \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || true)"
  resolved="${default_file/#\~/$HOME}"
  printf '%s\n' "$resolved"
}

# Returns: "mode ref" (space-separated)
#   mode: explicit | defaulted | ambient
#   ref: identity file path (or "none" if ambient)
# "explicit" means per-target override, "defaulted" means inherited from defaults.
ssh_resolve_machine_auth_origin_detail() {
  local target_id="$1"
  local per_target_origin per_target_file default_origin identity_file
  per_target_origin="$(yq -r ".ssh.targets[] | select(.id == \"$target_id\") | .machine_auth_origin // \"\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || true)"
  per_target_file="$(yq -r ".ssh.targets[] | select(.id == \"$target_id\") | .machine_identity_file // \"\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || true)"

  if [[ "$per_target_origin" == "ambient" ]]; then
    printf 'ambient none\n'
    return
  fi

  if [[ -n "$per_target_origin" || -n "$per_target_file" ]]; then
    identity_file="$(ssh_resolve_machine_identity_file "$target_id")"
    printf 'explicit %s\n' "${identity_file:-none}"
    return
  fi

  # Inherited from defaults
  default_origin="$(yq -r '.ssh.defaults.machine_auth_origin // "explicit"' \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || true)"
  if [[ "${default_origin:-explicit}" == "ambient" ]]; then
    printf 'ambient none\n'
    return
  fi

  identity_file="$(ssh_resolve_machine_identity_file "$target_id")"
  printf 'defaulted %s\n' "${identity_file:-none}"
}

# Returns the OpenSSH flags needed for governed machine identity.
# For explicit/defaulted: "-i /path/to/key -o IdentitiesOnly=yes"
# For ambient: "" (empty, OpenSSH default discovery)
# If the identity file does not exist, returns the flags but sets exit code 2.
ssh_resolve_machine_identity_opts() {
  local target_id="$1"
  local detail mode ref
  detail="$(ssh_resolve_machine_auth_origin_detail "$target_id")"
  mode="$(echo "$detail" | awk '{print $1}')"
  ref="$(echo "$detail" | awk '{print $2}')"

  if [[ "$mode" == "ambient" ]]; then
    return 0
  fi

  if [[ -z "$ref" || "$ref" == "none" ]]; then
    return 2
  fi

  printf -- '-i %s -o IdentitiesOnly=yes' "$ref"
  if [[ ! -f "$ref" ]]; then
    return 2
  fi
  return 0
}

ssh_tcp_port_open() {
  local host="$1"
  local port="${2:-22}"
  local timeout="${3:-3}"
  [[ -n "$host" && "$host" != "null" ]] || return 1
  python3 - "$host" "$port" "$timeout" <<'PY' >/dev/null 2>&1
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])
timeout = float(sys.argv[3])

try:
    with socket.create_connection((host, port), timeout=timeout):
        pass
except OSError:
    raise SystemExit(1)

raise SystemExit(0)
PY
}

# Resolve host with LAN→Tailscale fallback for lan_first targets.
# Returns: "resolved_ip path_used" (space-separated)
# path_used: lan | tailscale | direct | unreachable
ssh_resolve_host_with_fallback() {
  local target_id="$1"
  local timeout="${2:-3}"
  local host ts_ip policy
  host="$(ssh_resolve_host "$target_id")"
  ts_ip="$(ssh_resolve_tailscale_ip "$target_id")"
  policy="$(ssh_resolve_access_policy "$target_id")"

  case "$policy" in
    tailscale_required)
      if [[ -n "$ts_ip" && "$ts_ip" != "null" ]]; then
        if [[ "$ts_ip" != "$host" ]]; then
          printf '%s tailscale\n' "$ts_ip"
        else
          printf '%s direct\n' "$ts_ip"
        fi
        return 0
      fi
      printf '%s unreachable\n' "$host"
      return 1
      ;;
    lan_only)
      if [[ -n "$host" && "$host" != "null" ]]; then
        printf '%s lan\n' "$host"
        return 0
      fi
      printf '%s unreachable\n' "$host"
      return 1
      ;;
    lan_first|"")
      ;;
    *)
      if [[ -n "$host" && "$host" != "null" ]]; then
        printf '%s direct\n' "$host"
        return 0
      fi
      printf '%s unreachable\n' "$host"
      return 1
      ;;
  esac

  # LAN-first: try LAN, fall back to Tailscale
  # Optimization: if we're not on the shop LAN, skip LAN attempt entirely
  if _ssh_resolve_is_on_shop_lan; then
    if [[ -n "$host" ]] && ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
      printf '%s lan\n' "$host"
      return 0
    fi
  fi

  if [[ -n "$ts_ip" && "$ts_ip" != "$host" ]] && ping -c 1 -W "$timeout" "$ts_ip" >/dev/null 2>&1; then
    printf '%s tailscale\n' "$ts_ip"
    return 0
  fi

  # On-LAN but Tailscale failed too, try LAN as last resort
  if ! _ssh_resolve_is_on_shop_lan && [[ -n "$host" ]] && ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
    printf '%s lan\n' "$host"
    return 0
  fi

  # Both unreachable — return host for error reporting
  printf '%s unreachable\n' "$host"
  return 1
}

# Resolve a stable probe host for health and verification surfaces.
# Probes must honor the same access policy contract as the rest of runtime
# discovery to avoid LAN/Tailscale drift between status surfaces.
# Returns: "resolved_ip path_used" (space-separated)
# path_used: lan | tailscale | direct | unreachable
ssh_resolve_probe_host() {
  local target_id="$1"
  local timeout="${2:-3}"
  ssh_resolve_host_with_fallback "$target_id" "$timeout"
}

# Resolve host for SSH operations using actual TCP/22 reachability instead of
# ICMP ping. This avoids deploy drift where a host answers ping but SSH is not
# reachable on that path.
# Returns: "resolved_ip path_used" (space-separated)
# path_used: lan | tailscale | direct | unreachable
ssh_resolve_ssh_host_with_fallback() {
  local target_id="$1"
  local timeout="${2:-3}"
  local host ts_ip policy
  host="$(ssh_resolve_host "$target_id")"
  ts_ip="$(ssh_resolve_tailscale_ip "$target_id")"
  policy="$(ssh_resolve_access_policy "$target_id")"

  case "$policy" in
    tailscale_required)
      if [[ -n "$ts_ip" && "$ts_ip" != "null" ]] && ssh_tcp_port_open "$ts_ip" 22 "$timeout"; then
        if [[ "$ts_ip" != "$host" ]]; then
          printf '%s tailscale\n' "$ts_ip"
        else
          printf '%s direct\n' "$ts_ip"
        fi
        return 0
      fi
      printf '%s unreachable\n' "${ts_ip:-$host}"
      return 1
      ;;
    lan_only)
      if [[ -n "$host" && "$host" != "null" ]] && ssh_tcp_port_open "$host" 22 "$timeout"; then
        printf '%s lan\n' "$host"
        return 0
      fi
      printf '%s unreachable\n' "$host"
      return 1
      ;;
    lan_first|"")
      # Optimization: if not on shop LAN, skip the LAN TCP probe (saves 3-5s per target)
      if _ssh_resolve_is_on_shop_lan; then
        if [[ -n "$host" && "$host" != "null" ]] && ssh_tcp_port_open "$host" 22 "$timeout"; then
          printf '%s lan\n' "$host"
          return 0
        fi
      fi
      if [[ -n "$ts_ip" && "$ts_ip" != "$host" ]] && ssh_tcp_port_open "$ts_ip" 22 "$timeout"; then
        printf '%s tailscale\n' "$ts_ip"
        return 0
      fi
      # Last resort: try LAN even if not detected on-LAN (maybe routing changed)
      if ! _ssh_resolve_is_on_shop_lan && [[ -n "$host" && "$host" != "null" ]] && ssh_tcp_port_open "$host" 22 "$timeout"; then
        printf '%s lan\n' "$host"
        return 0
      fi
      printf '%s unreachable\n' "${host:-$ts_ip}"
      return 1
      ;;
    *)
      if [[ -n "$host" && "$host" != "null" ]] && ssh_tcp_port_open "$host" 22 "$timeout"; then
        printf '%s direct\n' "$host"
        return 0
      fi
      printf '%s unreachable\n' "$host"
      return 1
      ;;
  esac
}

# Resolve an HTTP URL to use the correct host IP with fallback.
# Takes a URL with a LAN IP and the target_id, returns URL with resolved IP + path_used.
# Returns: "resolved_url path_used" (space-separated)
ssh_resolve_url_with_fallback() {
  local url="$1"
  local target_id="$2"
  local timeout="${3:-3}"
  local result resolved_ip path_used
  result="$(ssh_resolve_host_with_fallback "$target_id" "$timeout")" || true
  resolved_ip="$(echo "$result" | awk '{print $1}')"
  path_used="$(echo "$result" | awk '{print $2}')"

  if [[ -z "$resolved_ip" || "$path_used" == "unreachable" ]]; then
    printf '%s unreachable\n' "$url"
    return 1
  fi

  # Replace the host portion of the URL
  local lan_ip
  lan_ip="$(ssh_resolve_host "$target_id")"
  local resolved_url="${url//$lan_ip/$resolved_ip}"
  printf '%s %s\n' "$resolved_url" "$path_used"
  return 0
}

# Resolve SSH extra opts for a target (e.g. legacy key algorithms)
ssh_resolve_extra_opts() {
  local target_id="$1"
  local opts
  opts="$(yq -r ".ssh.targets[] | select(.id == \"$target_id\") | .ssh_extra_opts // \"\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || true)"
  printf '%s' "${opts:-}"
}

# Resolve probe_via (ProxyJump target) for lan_only devices.
# Returns the probe_via target ID, or empty if none configured.
ssh_resolve_probe_via() {
  local target_id="$1"
  yq -r ".ssh.targets[] | select(.id == \"$target_id\") | .probe_via // \"\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || echo ""
}

# Build SSH command array for a target, with optional ProxyJump.
# Usage: ssh_build_cmd_with_fallback "communications-stack" -> prints ssh command string
# Fallback chain: direct LAN (ssh reachable) -> direct Tailscale (ssh reachable)
# -> ProxyJump via probe_via target
#
# ProxyJump fallback is attempted when probe_via is configured in ssh.targets.yaml.
# For targets without probe_via, fallback stops at Tailscale.
# Targets that commonly need probe_via: communications-stack (via pve), lan_only devices.
#
# GAP-OP-1268: communications-stack now has probe_via: pve configured.
# Remaining: blanket ProxyJump for all lan_first targets needs ACL policy changes.
ssh_build_cmd_with_fallback() {
  local target_id="$1"
  local timeout="${2:-5}"
  local result resolved_ip path_used
  result="$(ssh_resolve_ssh_host_with_fallback "$target_id" "$timeout")" || true
  resolved_ip="$(echo "$result" | awk '{print $1}')"
  path_used="$(echo "$result" | awk '{print $2}')"
  local user
  user="$(ssh_resolve_user "$target_id")"
  local extra_opts
  extra_opts="$(ssh_resolve_extra_opts "$target_id")"

  local -a cmd=(ssh "${SSH_BATCH_OPTS[@]}")

  # Apply governed machine identity if auth-origin is explicit/defaulted
  local identity_opts
  identity_opts="$(ssh_resolve_machine_identity_opts "$target_id" 2>/dev/null)" || true
  if [[ -n "$identity_opts" ]]; then
    # shellcheck disable=SC2206
    cmd+=($identity_opts)
  fi

  if [[ -n "$extra_opts" ]]; then
    # shellcheck disable=SC2206
    cmd+=($extra_opts)
  fi

  if [[ "$path_used" == "unreachable" ]]; then
    # Try ProxyJump via probe_via target if configured
    local proxy_target
    proxy_target="$(ssh_resolve_probe_via "$target_id")"
    if [[ -n "$proxy_target" && "$proxy_target" != "null" ]]; then
      local proxy_ref
      proxy_ref="$(ssh_resolve_ref "$proxy_target")"
      if [[ -n "$proxy_ref" ]]; then
        cmd+=(-o "ProxyJump=${proxy_ref}")
        local lan_ip
        lan_ip="$(ssh_resolve_host "$target_id")"
        cmd+=("${user}@${lan_ip}")
        printf '%s\n' "${cmd[*]}"
        return 0
      fi
    fi
    # No fallback available
    cmd+=("${user}@${resolved_ip}")
    printf '%s\n' "${cmd[*]}"
    return 1
  fi

  cmd+=("${user}@${resolved_ip}")
  printf '%s\n' "${cmd[*]}"
  return 0
}

# Standard SSH options for non-interactive batch mode
SSH_BATCH_OPTS=(-o ConnectTimeout=8 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
