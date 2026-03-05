#!/usr/bin/env bash
set -euo pipefail

# agent-watchdog.sh — Check watcher health and alert if unhealthy
#
# Usage: agent-watchdog.sh
#
# Checks:
#   - fswatch process count (expects 1)
#   - hot-folder-watcher.sh process count (expects >=1)
#
# If unhealthy, writes alert to outbox and logs to watchdog.out
# Intended to run periodically via cron or launchd.

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '3,12p' "$0" | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

# SPINE paths (canonical)
SPINE="${SPINE_REPO:-$HOME/code/agentic-spine}"
source "$SPINE/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths
OUTBOX="${SPINE_OUTBOX}"
LOG="${SPINE_LOGS}/watchdog.out"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
INBOX_BASENAME="$(basename "${SPINE_INBOX}")"

mkdir -p "$(dirname "$LOG")" "$OUTBOX"

fswatch_count="$(ps aux | grep "fswatch.*${INBOX_BASENAME}" | grep -cv grep || true)"
watcher_count="$(ps aux | grep "hot-folder-watcher\.sh" | grep -cv grep || true)"

status="OK"
reason=""

if [[ "${fswatch_count:-0}" -ne 1 ]]; then
  status="BAD"; reason+="fswatch_count=$fswatch_count (expected 1). "
fi
if [[ "${watcher_count:-0}" -lt 1 ]]; then
  status="BAD"; reason+="watcher_count=$watcher_count (expected >=1). "
fi

echo "[$TS] status=$status $reason" | tee -a "$LOG"

if [[ "$status" != "OK" ]]; then
  ALERT="$OUTBOX/ALERT_agent_watchdog_${TS//[:]/}.md"
  cat > "$ALERT" <<EOF
# Agent Watchdog Alert

Time (UTC): $TS
Status: $status
Reason: $reason

Suggested checks:
- ps aux | rg -n "hot-folder-watcher\\.sh|fswatch"
- tail -n 80 $SPINE_LOGS/agent-inbox.out
- tail -n 80 $SPINE_STATE/ledger.csv
EOF
  echo "Wrote alert: $ALERT"
fi
