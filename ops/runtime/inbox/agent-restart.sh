#!/usr/bin/env bash
set -euo pipefail

# agent-restart.sh — Restart the canonical launchd watcher
#
# Usage: agent-restart.sh
#
# Stops the hot-folder-watcher LaunchAgent, clears stale locks/PID,
# and restarts it. Use when the watcher is stuck or after config changes.
#
# Safety: mutating (stops and starts the watcher service)

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '3,10p' "$0" | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

LABEL="com.ronny.agent-inbox"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
SPINE="${SPINE_REPO:-$HOME/Code/agentic-spine}"
STATE_DIR="${SPINE_STATE:-$SPINE/mailroom/state}"
PID_FILE="${STATE_DIR}/agent-inbox.pid"
LOCK_DIR="${STATE_DIR}/locks/agent-inbox.lock"

echo "spine.watcher.restart"
echo "service: $LABEL"
echo

# Check plist exists
if [[ ! -f "$PLIST" ]]; then
  echo "STOP: plist not found at $PLIST"
  exit 2
fi

# Stop if running
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
