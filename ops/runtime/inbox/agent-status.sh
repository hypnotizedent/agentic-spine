#!/usr/bin/env bash
set -euo pipefail

# agent-status.sh — Canonical watcher status (launchd + PID + lock)
#
# Usage: agent-status.sh
#
# Displays:
#   - LaunchAgent state (running/loaded/not loaded)
#   - PID file status (alive/stale/absent)
#   - Lock status (held/free)
#   - Queue counts (queued/running/done/failed/parked)
#   - Last 10 ledger entries
#   - Latest outbox result
#
# Safety: read-only except for stale-lock cleanup (auto-clears dead PIDs)

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '3,15p' "$0" | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

LABEL="com.ronny.agent-inbox"
SPINE="${SPINE_REPO:-$HOME/code/agentic-spine}"
STATE_DIR="${SPINE_STATE:-$SPINE/mailroom/state}"
INBOX="${SPINE_INBOX:-$SPINE/mailroom/inbox}"
OUTBOX="${SPINE_OUTBOX:-$SPINE/mailroom/outbox}"
LOG_DIR="${SPINE_LOGS:-$SPINE/mailroom/logs}"
PID_FILE="${STATE_DIR}/agent-inbox.pid"
LOCK_DIR="${STATE_DIR}/locks/agent-inbox.lock"
LEDGER="${STATE_DIR}/ledger.csv"

echo "== LAUNCHD =="
echo "service: $LABEL"
WATCHER_PRINT="$(launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null || true)"
if [[ -n "$WATCHER_PRINT" ]]; then
  WATCHER_STATE="$(echo "$WATCHER_PRINT" | awk -F' = ' '/state =/{print $2; exit}')"
  WATCHER_PID="$(echo "$WATCHER_PRINT" | awk '/pid =/{print $3; exit}')"
  if [[ "$WATCHER_STATE" == "running" && -n "$WATCHER_PID" ]]; then
    echo "state: running"
    echo "pid: $WATCHER_PID"
  else
    echo "state: ${WATCHER_STATE:-unknown}"
    [[ -n "$WATCHER_PID" ]] && echo "pid: $WATCHER_PID"
  fi
else
  # Fallback for older launchctl output formats
  WATCHER_INFO="$(launchctl list "$LABEL" 2>/dev/null || true)"
  if [[ -n "$WATCHER_INFO" ]]; then
    WATCHER_PID="$(echo "$WATCHER_INFO" | sed -n 's/.*"PID" = \([0-9]*\).*/\1/p')"
    WATCHER_EXIT="$(echo "$WATCHER_INFO" | sed -n 's/.*"LastExitStatus" = \([0-9]*\).*/\1/p')"
    if [[ -n "$WATCHER_PID" ]]; then
      echo "state: running"
      echo "pid: $WATCHER_PID"
    else
      echo "state: loaded (not running; last_exit=${WATCHER_EXIT:-unknown})"
    fi
  else
    echo "state: not loaded"
  fi
fi

echo
echo "== PID FILE =="
if [[ -f "$PID_FILE" ]]; then
  STORED_PID="$(cat "$PID_FILE" 2>/dev/null || echo "")"
  if [[ -n "$STORED_PID" ]] && kill -0 "$STORED_PID" 2>/dev/null; then
    echo "pid_file: $STORED_PID (alive)"
  else
    echo "pid_file: $STORED_PID (stale — clearing)"
    rm -f "$PID_FILE"
    if [[ -d "$LOCK_DIR" ]]; then
      rm -rf "$LOCK_DIR"
      echo "lock: cleared stale lock"
    fi
  fi
else
  echo "pid_file: absent"
fi

echo
echo "== LOCK =="
if [[ -d "$LOCK_DIR" ]]; then
  echo "lock: held"
else
  echo "lock: free"
fi

echo
echo "== QUEUE =="
for lane in queued running done failed parked; do
  count="$(find "$INBOX/$lane" -maxdepth 1 -type f \
    ! -name '.keep' \
    ! -name '.DS_Store' \
    ! -name '.*.swp' \
    2>/dev/null | wc -l | tr -d ' ')"
  printf "%-10s %s\n" "$lane:" "$count"
done

echo
echo "== LEDGER (last 10) =="
if [[ -f "$LEDGER" ]]; then
  tail -10 "$LEDGER"
else
  echo "(no ledger)"
fi

echo
echo "== OUTBOX (latest) =="
LATEST="$(ls -1t "$OUTBOX"/*_RESULT.md 2>/dev/null | head -1 || true)"
if [[ -n "$LATEST" ]]; then
  echo "file: $(basename "$LATEST")"
  echo "time: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$LATEST" 2>/dev/null || stat -c '%y' "$LATEST" 2>/dev/null | cut -d. -f1)"
else
  echo "(no results)"
fi
