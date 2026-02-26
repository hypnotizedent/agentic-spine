#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# tailscale-guard.sh — Network gate pre-flight
# ═══════════════════════════════════════════════════════════════
#
# Source this in any gate that makes curl/ssh calls to Tailscale IPs.
# Gates SKIP (exit 0) when Tailscale is down — not FAIL.
# This prevents:
#   1. macOS Tailscale login popup interrupting work
#   2. 10-60 second timeouts per gate when VPN is disconnected
#   3. False failures in verify output
#
# Usage:
#   source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
#   require_tailscale
# Optional cache:
#   VERIFY_TAILSCALE_GUARD_CACHE_FILE=<path>  # populated once by verify runtime
#
# ═══════════════════════════════════════════════════════════════

read_tailscale_cache_state() {
  local cache_file="${VERIFY_TAILSCALE_GUARD_CACHE_FILE:-}"
  [[ -n "$cache_file" && -r "$cache_file" ]] || return 1
  local cached
  cached="$(awk -F= '/^online=/{print $2; exit}' "$cache_file" 2>/dev/null || true)"
  case "$cached" in
    true|false|missing_cli)
      echo "$cached"
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

write_tailscale_cache_state() {
  local state="${1:-}"
  local cache_file="${VERIFY_TAILSCALE_GUARD_CACHE_FILE:-}"
  [[ -n "$cache_file" && -n "$state" ]] || return 0
  printf 'online=%s\n' "$state" >"$cache_file" 2>/dev/null || true
}

require_tailscale() {
  local cached_state
  if cached_state="$(read_tailscale_cache_state)"; then
    if [[ "$cached_state" == "true" ]]; then
      return 0
    fi
    if [[ "$cached_state" == "missing_cli" ]]; then
      echo "SKIP: tailscale CLI not found (gate requires Tailscale network)"
      exit 0
    fi
    echo "SKIP: Tailscale not connected (gate requires Tailscale network)"
    exit 0
  fi

  # Fast path: if tailscale CLI isn't installed, skip
  if ! command -v tailscale >/dev/null 2>&1; then
    write_tailscale_cache_state "missing_cli"
    echo "SKIP: tailscale CLI not found (gate requires Tailscale network)"
    exit 0
  fi

  # Check if connected — jq parses the status JSON
  local online
  online="$(tailscale status --json 2>/dev/null | jq -r '.Self.Online // false' 2>/dev/null || echo "false")"
  write_tailscale_cache_state "$online"

  if [[ "$online" != "true" ]]; then
    echo "SKIP: Tailscale not connected (gate requires Tailscale network)"
    exit 0
  fi
}
