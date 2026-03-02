#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# ssh-resolve.sh — Shared SSH target resolution for spine gates
# ═══════════════════════════════════════════════════════════════
#
# Source this in any gate or capability that SSHes to targets.
# Reads from ops/bindings/ssh.targets.yaml (SSOT).
#
# Usage:
#   source "${SPINE_ROOT:-$HOME/code/agentic-spine}/ops/lib/ssh-resolve.sh"
#   ref="$(ssh_resolve_ref "download-stack")"    # => ubuntu@192.168.1.209
#   host="$(ssh_resolve_host "download-stack")"  # => 192.168.1.209
#   user="$(ssh_resolve_user "download-stack")"  # => ubuntu
#
# ═══════════════════════════════════════════════════════════════

_SSH_RESOLVE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
_SSH_RESOLVE_BINDING="${_SSH_RESOLVE_ROOT}/ops/bindings/ssh.targets.yaml"

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

ssh_resolve_access_policy() {
  local target_id="$1"
  yq -r ".ssh.targets[] | select(.id == \"$target_id\") | .access_policy // \"lan_first\"" \
    "$_SSH_RESOLVE_BINDING" 2>/dev/null || echo "lan_first"
}

# Resolve host with LAN→Tailscale fallback for lan_first targets.
# Returns: "resolved_ip path_used" (space-separated)
# path_used: lan | tailscale | direct
ssh_resolve_host_with_fallback() {
  local target_id="$1"
  local timeout="${2:-3}"
  local host ts_ip policy
  host="$(ssh_resolve_host "$target_id")"
  ts_ip="$(ssh_resolve_tailscale_ip "$target_id")"
  policy="$(ssh_resolve_access_policy "$target_id")"

  if [[ "$policy" != "lan_first" ]]; then
    # tailscale_required or lan_only: use host as-is
    printf '%s direct\n' "$host"
    return 0
  fi

  # LAN-first: try LAN, fall back to Tailscale
  if [[ -n "$host" ]] && ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
    printf '%s lan\n' "$host"
    return 0
  fi

  if [[ -n "$ts_ip" && "$ts_ip" != "$host" ]] && ping -c 1 -W "$timeout" "$ts_ip" >/dev/null 2>&1; then
    printf '%s tailscale\n' "$ts_ip"
    return 0
  fi

  # Both unreachable — return host for error reporting
  printf '%s unreachable\n' "$host"
  return 1
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

# Standard SSH options for non-interactive batch mode
SSH_BATCH_OPTS=(-o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
