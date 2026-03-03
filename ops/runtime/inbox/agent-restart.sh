#!/usr/bin/env bash
set -euo pipefail

# agent-restart.sh — Restart and normalize canonical watcher launchd service
#
# Usage: agent-restart.sh
#
# Actions:
#   - Resolves canonical runtime paths from runtime contract.
#   - Rewrites watcher plist EnvironmentVariables to canonical paths.
#   - Restarts LaunchAgent, clears stale lock/PID, verifies process is running.
#
# Safety: mutating (rewrites LaunchAgent plist and restarts service)

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '3,12p' "$0" | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

LABEL="com.ronny.agent-inbox"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

SPINE="${SPINE_REPO:-$HOME/code/agentic-spine}"
source "$SPINE/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths
SPINE="$SPINE_REPO"

WATCHER_SCRIPT="$SPINE/ops/runtime/inbox/hot-folder-watcher.sh"
STATE_DIR="${SPINE_STATE}"
INBOX_DIR="${SPINE_INBOX}"
OUTBOX_DIR="${SPINE_OUTBOX}"
LOG_DIR="${SPINE_LOGS}"
PID_FILE="${STATE_DIR}/agent-inbox.pid"
LOCK_DIR="${STATE_DIR}/locks/agent-inbox.lock"
OUT_LOG="${LOG_DIR}/agent-inbox.out"
ERR_LOG="${LOG_DIR}/agent-inbox.err"

mkdir -p "$STATE_DIR" "$LOG_DIR" "$(dirname "$PLIST")"

if [[ ! -x "$WATCHER_SCRIPT" ]]; then
  echo "STOP: watcher script not executable: $WATCHER_SCRIPT"
  exit 2
fi

plist_env_value() {
  local key="$1"
  if [[ -f "$PLIST" && -x /usr/libexec/PlistBuddy ]]; then
    /usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:${key}" "$PLIST" 2>/dev/null || true
  else
    echo ""
  fi
}

append_env_xml() {
  local key="$1"
  local value="$2"
  if [[ -n "$value" ]]; then
    cat <<EOF
      <key>${key}</key>
      <string>${value}</string>
EOF
  fi
}

watcher_provider="${SPINE_WATCHER_PROVIDER:-$(plist_env_value SPINE_WATCHER_PROVIDER)}"
engine_provider="${SPINE_ENGINE_PROVIDER:-$(plist_env_value SPINE_ENGINE_PROVIDER)}"
watcher_provider="${watcher_provider:-local}"
engine_provider="${engine_provider:-zai}"
zai_model="${ZAI_MODEL:-$(plist_env_value ZAI_MODEL)}"
operator_tz="${SPINE_OPERATOR_TZ:-$(plist_env_value SPINE_OPERATOR_TZ)}"
runtime_tz="${TZ:-$(plist_env_value TZ)}"

echo "spine.watcher.restart"
echo "service: $LABEL"
echo "paths:"
echo "  inbox: $INBOX_DIR"
echo "  outbox: $OUTBOX_DIR"
echo "  state: $STATE_DIR"
echo "  logs: $LOG_DIR"
echo

cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/bash</string>
      <string>${WATCHER_SCRIPT}</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${SPINE}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>30</integer>
    <key>EnvironmentVariables</key>
    <dict>
      <key>SPINE_REPO</key>
      <string>${SPINE}</string>
      <key>SPINE_INBOX</key>
      <string>${INBOX_DIR}</string>
      <key>SPINE_OUTBOX</key>
      <string>${OUTBOX_DIR}</string>
      <key>SPINE_STATE</key>
      <string>${STATE_DIR}</string>
      <key>SPINE_LOGS</key>
      <string>${LOG_DIR}</string>
      <key>PATH</key>
      <string>${HOME}/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
$(append_env_xml "SPINE_WATCHER_PROVIDER" "$watcher_provider")
$(append_env_xml "SPINE_ENGINE_PROVIDER" "$engine_provider")
$(append_env_xml "ZAI_MODEL" "$zai_model")
$(append_env_xml "SPINE_OPERATOR_TZ" "$operator_tz")
$(append_env_xml "TZ" "$runtime_tz")
    </dict>
    <key>StandardOutPath</key>
    <string>${OUT_LOG}</string>
    <key>StandardErrorPath</key>
    <string>${ERR_LOG}</string>
  </dict>
</plist>
EOF

echo "plist: synced"

# Stop if running
echo
echo "== STOP =="
if launchctl list "$LABEL" >/dev/null 2>&1; then
  launchctl bootout "gui/$(id -u)" "$PLIST" 2>&1 || true
  echo "stopped"
else
  echo "not loaded (skip)"
fi

# Clear stale state
if [[ -d "$LOCK_DIR" ]]; then
  rm -rf "$LOCK_DIR"
  echo "cleared lock"
fi
if [[ -f "$PID_FILE" ]]; then
  rm -f "$PID_FILE"
  echo "cleared PID file"
fi

# Start
echo
echo "== START =="
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "bootstrapped"

# Verify
sleep 2
echo
echo "== VERIFY =="
WATCHER_INFO="$(launchctl list "$LABEL" 2>/dev/null || true)"
if [[ -n "$WATCHER_INFO" ]]; then
  WATCHER_PID="$(echo "$WATCHER_INFO" | sed -n 's/.*"PID" = \([0-9]*\).*/\1/p')"
  if [[ -n "$WATCHER_PID" ]]; then
    echo "status: running (PID: $WATCHER_PID)"
  else
    echo "status: loaded but no PID (may be throttled)"
  fi
else
  echo "status: FAIL (not loaded after bootstrap)"
  exit 1
fi
