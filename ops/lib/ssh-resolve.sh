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

# Standard SSH options for non-interactive batch mode
SSH_BATCH_OPTS=(-o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
