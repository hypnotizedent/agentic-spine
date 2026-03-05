#!/usr/bin/env bash
# D366: mailroom-bridge-token-plaintext-lock
# Block plaintext MAILROOM_BRIDGE_TOKEN values in LaunchAgent templates/materialized plists.
set -euo pipefail

resolve_root() {
  if [[ -n "${SPINE_ROOT:-}" && -f "${SPINE_ROOT}/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$SPINE_ROOT"
    return 0
  fi
  local detected_root=""
  detected_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$detected_root" && -f "$detected_root/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$detected_root"
    return 0
  fi
  printf '%s\n' "$HOME/code/agentic-spine"
}

ROOT="$(resolve_root)"
TEMPLATE="$ROOT/ops/runtime/launchd/com.ronny.mailroom-bridge.plist"
MATERIALIZED="$HOME/Library/LaunchAgents/com.ronny.mailroom-bridge.plist"

fail() {
  echo "D366 FAIL: $*" >&2
  exit 1
}

[[ -f "$TEMPLATE" ]] || fail "missing template plist: $TEMPLATE"

if grep -q '<key>MAILROOM_BRIDGE_TOKEN</key>' "$TEMPLATE"; then
  fail "template plist contains MAILROOM_BRIDGE_TOKEN env key (use MAILROOM_BRIDGE_TOKEN_FILE)"
fi

if grep -q 'MAILROOM_BRIDGE_TOKEN=' "$TEMPLATE"; then
  fail "template plist embeds MAILROOM_BRIDGE_TOKEN assignment"
fi

if [[ -f "$MATERIALIZED" ]] && [[ -x /usr/libexec/PlistBuddy ]]; then
  token_value="$(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:MAILROOM_BRIDGE_TOKEN' "$MATERIALIZED" 2>/dev/null || true)"
  if [[ -n "$token_value" ]]; then
    fail "materialized bridge plist contains MAILROOM_BRIDGE_TOKEN value"
  fi
fi

echo "D366 PASS: bridge plists use file-based token sourcing (no plaintext MAILROOM_BRIDGE_TOKEN values)"
