#!/usr/bin/env bash
set -euo pipefail

# SPINE paths (canonical)
SPINE="${SPINE_REPO:-$HOME/Code/agentic-spine}"
INBOX="${SPINE_INBOX:-$SPINE/mailroom/inbox}"
OUTBOX="${SPINE_OUTBOX:-$SPINE/mailroom/outbox}"
STATE_DIR="${SPINE_STATE:-$SPINE/mailroom/state}"
LOG_DIR="${SPINE_LOGS:-$SPINE/mailroom/logs}"

echo "== PROCS =="
ps aux | grep -E "hot-folder-watcher\.sh|fswatch" | grep -v grep || true

echo -e "\n== LAUNCHD =="
launchctl list | grep com.ronny.agent-inbox || true

echo -e "\n== INBOX (pending) =="
find "$INBOX" -maxdepth 1 -type f -name "*.md" -print 2>/dev/null | sort || true

echo -e "\n== OUTBOX (newest) =="
ls -1t "$OUTBOX"/*_RESULT.md 2>/dev/null | head -n 5 || true

echo -e "\n== STATE (newest) =="
ls -1t "$STATE_DIR" 2>/dev/null | head -n 5 || true

echo -e "\n== LEDGER (tail) =="
tail -n 40 "$STATE_DIR/ledger.csv" 2>/dev/null || true

echo -e "\n== LOG (tail) =="
tail -n 40 "$LOG_DIR/agent-inbox.out" 2>/dev/null || true
