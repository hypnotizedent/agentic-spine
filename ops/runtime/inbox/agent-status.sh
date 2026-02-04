#!/usr/bin/env bash
set -euo pipefail

# agent-status.sh — Canonical watcher status (launchd + PID + lock)
# Safety: read-only except for stale-lock cleanup
# NOTE: This script auto-clears stale PID files and lock dirs when the
#       recorded PID is no longer alive. This is intentional — a dead
#       watcher's lock must not block restart via launchd KeepAlive.

LABEL="com.ronny.agent-inbox"
SPINE="${SPINE_REPO:-$HOME/Code/agentic-spine}"
STATE_DIR="${SPINE_STATE:-$SPINE/mailroom/state}"
INBOX="${SPINE_INBOX:-$SPINE/mailroom/inbox}"
OUTBOX="${SPINE_OUTBOX:-$SPINE/mailroom/outbox}"
LOG_DIR="${SPINE_LOGS:-$SPINE/mailroom/logs}"
PID_FILE="${STATE_DIR}/agent-inbox.pid"
LOCK_DIR="${STATE_DIR}/locks/agent-inbox.lock"
LEDGER="${STATE_DIR}/ledger.csv"

echo "== LAUNCHD =="
echo "service: $LABEL"
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
  count="$(find "$INBOX/$lane" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
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
