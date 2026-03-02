#!/usr/bin/env bash
# proxy-session.sh - Shared proxy lifecycle for Vaultwarden bw CLI operations
#
# Source this file, then call vw_proxy_start / vw_proxy_stop / vw_bw.
# All bw commands within a session share the same proxy instance.
#
# Usage:
#   source "$SCRIPT_DIR/../lib/proxy-session.sh"
#   vw_proxy_start                     # starts HTTPS proxy, configures bw
#   vw_bw login --apikey               # runs bw through proxy
#   SESSION="$(vw_bw unlock ...)"      # all commands hit same proxy
#   vw_bw list items --session "$S"
#   vw_proxy_stop                      # kills proxy
#
# Env:
#   VW_PROXY_TARGET - Vaultwarden backend (default sourced from services.health binding)
#                     This is the endpoint the proxy forwards to.
#                     Callers should NOT change this unless testing a different VW instance.

# Guard against double-source
[[ -z "${_VW_PROXY_SESSION_LOADED:-}" ]] || return 0
_VW_PROXY_SESSION_LOADED=1

_VW_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_VW_PROXY_SCRIPT="$_VW_LIB_DIR/scope-proxy.py"
_VW_PROXY_PID=""
_VW_PROXY_PORT=""
_VW_PROXY_OUTPUT=""

# Default: derive from services.health SSOT only; callers can override via env.
_VW_SPINE_ROOT="$(cd "$_VW_LIB_DIR/../../../.." && pwd)"
_VW_SERVICES_HEALTH="$_VW_SPINE_ROOT/ops/bindings/services.health.yaml"
_VW_DEFAULT_TARGET=""
if command -v yq >/dev/null 2>&1 && [[ -f "$_VW_SERVICES_HEALTH" ]]; then
  _vw_health_url="$(yq e -r '.endpoints[] | select(.id=="vaultwarden") | .url // ""' "$_VW_SERVICES_HEALTH" 2>/dev/null | head -n1)"
  if [[ -n "$_vw_health_url" ]]; then
    _VW_DEFAULT_TARGET="${_vw_health_url%/alive}"
  fi
fi
VW_PROXY_TARGET="${VW_PROXY_TARGET:-$_VW_DEFAULT_TARGET}"

vw_proxy_start() {
  # Idempotent: if proxy already running, just return
  if [[ -n "$_VW_PROXY_PID" ]] && kill -0 "$_VW_PROXY_PID" 2>/dev/null; then
    return 0
  fi

  [[ -n "$VW_PROXY_TARGET" ]] || {
    echo "STOP (2): VW_PROXY_TARGET unresolved (set env or register vaultwarden url in services.health.yaml)" >&2
    return 2
  }

  [[ -f "$_VW_PROXY_SCRIPT" ]] || { echo "STOP (2): missing scope-proxy.py" >&2; return 2; }
  command -v python3 >/dev/null 2>&1 || { echo "STOP (2): python3 not found" >&2; return 2; }
  command -v bw >/dev/null 2>&1 || { echo "STOP (2): bw CLI not found" >&2; return 2; }

  # Machine-path fallback: try primary (LAN) target, fall back to Tailscale if unreachable.
  # Resolution order: LAN IP (services.health) → Tailscale IP (ssh.targets) → fail.
  local _effective_target="$VW_PROXY_TARGET"
  if ! curl -sf --connect-timeout 3 "${_effective_target}/alive" >/dev/null 2>&1; then
    local _ts_ip=""
    local _ssh_targets="$_VW_SPINE_ROOT/ops/bindings/ssh.targets.yaml"
    if command -v yq >/dev/null 2>&1 && [[ -f "$_ssh_targets" ]]; then
      _ts_ip="$(yq -r '.ssh.targets[] | select(.id == "infra-core") | .tailscale_ip // ""' "$_ssh_targets" 2>/dev/null || echo "")"
    fi
    if [[ -n "$_ts_ip" ]]; then
      local _ts_target="http://${_ts_ip}:8081"
      if curl -sf --connect-timeout 3 "${_ts_target}/alive" >/dev/null 2>&1; then
        echo "INFO: LAN target unreachable, falling back to Tailscale (${_ts_ip})" >&2
        _effective_target="$_ts_target"
      else
        echo "WARN: both LAN and Tailscale targets unreachable" >&2
      fi
    fi
  fi

  _VW_PROXY_OUTPUT="$(mktemp)"
  python3 "$_VW_PROXY_SCRIPT" --target "$_effective_target" > "$_VW_PROXY_OUTPUT" 2>/dev/null &
  _VW_PROXY_PID=$!

  # Wait for proxy ready (up to 5s)
  local _i
  for _i in $(seq 1 50); do
    grep -q "status: ready" "$_VW_PROXY_OUTPUT" 2>/dev/null && break
    if ! kill -0 "$_VW_PROXY_PID" 2>/dev/null; then
      rm -f "$_VW_PROXY_OUTPUT"
      echo "STOP (2): scope proxy exited unexpectedly" >&2
      return 2
    fi
    sleep 0.1
  done

  if ! grep -q "status: ready" "$_VW_PROXY_OUTPUT" 2>/dev/null; then
    rm -f "$_VW_PROXY_OUTPUT"
    echo "STOP (2): scope proxy failed to start within 5 seconds" >&2
    return 2
  fi

  _VW_PROXY_PORT="$(grep '^proxy_url:' "$_VW_PROXY_OUTPUT" | sed 's|.*://127.0.0.1:||')"
  rm -f "$_VW_PROXY_OUTPUT"
  _VW_PROXY_OUTPUT=""

  [[ -n "$_VW_PROXY_PORT" ]] || { echo "STOP (2): could not determine proxy port" >&2; return 2; }

  # Configure bw to use the HTTPS proxy
  NODE_TLS_REJECT_UNAUTHORIZED=0 bw config server "https://127.0.0.1:${_VW_PROXY_PORT}" >/dev/null 2>&1

  return 0
}

vw_proxy_stop() {
  if [[ -n "$_VW_PROXY_PID" ]]; then
    kill "$_VW_PROXY_PID" 2>/dev/null || true
    wait "$_VW_PROXY_PID" 2>/dev/null || true
    _VW_PROXY_PID=""
  fi
  [[ -z "$_VW_PROXY_OUTPUT" ]] || rm -f "$_VW_PROXY_OUTPUT"
  _VW_PROXY_PORT=""
}

vw_bw() {
  # Run bw with TLS verification disabled (self-signed cert on localhost proxy)
  NODE_TLS_REJECT_UNAUTHORIZED=0 bw "$@"
}

vw_proxy_port() {
  echo "$_VW_PROXY_PORT"
}
