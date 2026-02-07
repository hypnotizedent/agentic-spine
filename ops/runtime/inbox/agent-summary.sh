#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# agent-summary.sh - Quick pipeline status for daily triage
# ═══════════════════════════════════════════════════════════════════════════
#
# Usage:
#   ./agent-summary.sh           # Show summary
#   ./agent-summary.sh --watch   # Refresh every 5s
#
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

SPINE="${SPINE_REPO:-$HOME/code/agentic-spine}"
INBOX="${SPINE_INBOX:-$SPINE/mailroom/inbox}"
OUTBOX="${SPINE_OUTBOX:-$SPINE/mailroom/outbox}"
STATE_DIR="${SPINE_STATE:-$SPINE/mailroom/state}"

QUEUED="${INBOX}/queued"
RUNNING="${INBOX}/running"
DONE="${INBOX}/done"
FAILED="${INBOX}/failed"
PARKED="${INBOX}/parked"

LEDGER="${STATE_DIR}/ledger.csv"
PID_FILE="${STATE_DIR}/agent-inbox.pid"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

show_summary() {
    clear 2>/dev/null || true

    echo "═══════════════════════════════════════════════════════════════════════════"
    echo "  AGENT PIPELINE SUMMARY"
    echo "═══════════════════════════════════════════════════════════════════════════"
    echo ""

    # Counts
    local queued_count running_count done_count failed_count parked_count
    queued_count="$(find "$QUEUED" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
    running_count="$(find "$RUNNING" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
    done_count="$(find "$DONE" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
    failed_count="$(find "$FAILED" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
    parked_count="$(find "$PARKED" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"

    printf "  Queued: ${CYAN}%s${NC}  Running: ${YELLOW}%s${NC}  Done: ${GREEN}%s${NC}  Failed: ${RED}%s${NC}  Parked: ${YELLOW}%s${NC}\n" \
        "$queued_count" "$running_count" "$done_count" "$failed_count" "$parked_count"
    echo ""

    # Watcher status
    echo "───────────────────────────────────────────────────────────────────────────"
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null)"
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  Watcher: ${GREEN}Running${NC} (PID: $pid)"
        else
            echo -e "  Watcher: ${RED}Stale lock${NC} (PID $pid not running)"
        fi
    else
        echo -e "  Watcher: ${RED}Not running${NC}"
    fi
    echo ""

    # Last 3 failed (from ledger)
    if [[ "$failed_count" -gt 0 ]] && [[ -f "$LEDGER" ]]; then
        echo "───────────────────────────────────────────────────────────────────────────"
        echo -e "  ${RED}Last 3 Failed:${NC}"
        grep ",failed," "$LEDGER" 2>/dev/null | tail -3 | while IFS=, read -r run_id _ _ _ status prompt_file _ error _; do
            local short_error="${error:0:40}"
            [[ ${#error} -gt 40 ]] && short_error="${short_error}..."
            echo "    - ${prompt_file} (${short_error:-unknown})"
        done
        echo ""
    fi

    # Last 3 parked
    if [[ "$parked_count" -gt 0 ]]; then
        echo "───────────────────────────────────────────────────────────────────────────"
        echo -e "  ${YELLOW}Parked (needs attention):${NC}"
        ls -t "$PARKED"/*.md 2>/dev/null | head -3 | while read -r f; do
            echo "    - $(basename "$f")"
        done
        echo ""
    fi

    # Latest result
    echo "───────────────────────────────────────────────────────────────────────────"
    local latest
    latest="$(ls -t "$OUTBOX"/*_RESULT.md 2>/dev/null | head -1)"
    if [[ -n "$latest" ]]; then
        echo "  Latest Result: $latest"
        echo ""
        # Show first 5 lines of result (header only)
        head -12 "$latest" 2>/dev/null | sed 's/^/    /'
    else
        echo "  Latest Result: (none)"
    fi
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════"
}

# Main
if [[ "${1:-}" == "--watch" ]]; then
    while true; do
        show_summary
        echo ""
        echo "  (Refreshing every 5s - Ctrl+C to stop)"
        sleep 5
    done
else
    show_summary
fi
