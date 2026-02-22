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
#
# ═══════════════════════════════════════════════════════════════

require_tailscale() {
  # Fast path: if tailscale CLI isn't installed, skip
  if ! command -v tailscale >/dev/null 2>&1; then
    echo "SKIP: tailscale CLI not found (gate requires Tailscale network)"
    exit 0
  fi

  # Check if connected — jq parses the status JSON
  local online
  online="$(tailscale status --json 2>/dev/null | jq -r '.Self.Online // false' 2>/dev/null || echo "false")"

  if [[ "$online" != "true" ]]; then
    echo "SKIP: Tailscale not connected (gate requires Tailscale network)"
    exit 0
  fi
}
