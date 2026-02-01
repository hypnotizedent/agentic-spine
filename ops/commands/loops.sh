#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops loops - Open Loop Engine (receipts → actionable tasks)
# ═══════════════════════════════════════════════════════════════════════════
#
# Usage:
#   ops loops list [--open|--closed|--all]   List open loops
#   ops loops collect                         Scan receipts, create new loops
#   ops loops close <loop_id>                 Mark loop as closed
#   ops loops show <loop_id>                  Show loop details
#
# Rule: Every non-OK run must yield an open loop.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$HOME/Code/agentic-spine}"
STATE_DIR="$SPINE_REPO/mailroom/state"
LOOPS_FILE="$STATE_DIR/open_loops.jsonl"
RECEIPTS_DIR="$SPINE_REPO/receipts/sessions"
OUTBOX_DIR="$SPINE_REPO/mailroom/outbox"
LEDGER="$STATE_DIR/ledger.csv"

# Dependency check - jq required for JSONL parsing
check_deps() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq is required for ops loops JSONL parsing." >&2
        echo "Install: brew install jq" >&2
        exit 2
    fi
}

# Ensure state directory exists before any writes
ensure_state_dir() {
    mkdir -p "$STATE_DIR"
}

usage() {
    cat <<'EOF'
ops loops - Open Loop Engine

Usage:
  ops loops list [--open|--closed|--all]   List loops (default: open only)
  ops loops collect                         Scan recent receipts, create loops
  ops loops close <loop_id>                 Mark loop as closed
  ops loops show <loop_id>                  Show loop details
  ops loops summary                         Show loop counts by status/owner

Examples:
  ops loops list
  ops loops collect
  ops loops close OL_20260201_183012_vendor
  ops loops summary
EOF
}

# Generate loop ID
gen_loop_id() {
    local run_key="$1"
    local suffix="$2"
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    echo "OL_${ts}_${suffix}"
}

# Check if loop already exists for a run_key
loop_exists_for_run() {
    local run_key="$1"
    grep -q "\"run_key\":\"$run_key\"" "$LOOPS_FILE" 2>/dev/null
}

# Extract open loops from a receipt
extract_loops_from_receipt() {
    local receipt_dir="$1"
    local receipt_file="$receipt_dir/receipt.md"

    [[ -f "$receipt_file" ]] || return 0

    # Extract run_key from receipt
    local run_key
    run_key="$(grep -m1 "Run Key" "$receipt_file" 2>/dev/null | sed 's/.*`\([^`]*\)`.*/\1/' || echo "")"
    [[ -z "$run_key" ]] && run_key="$(basename "$receipt_dir" | sed 's/^R//')"

    # Skip if loop already exists for this run
    if loop_exists_for_run "$run_key"; then
        return 0
    fi

    # Extract status
    local status
    status="$(grep -m1 "| Status |" "$receipt_file" 2>/dev/null | sed 's/.*| Status | *//' | sed 's/ *|.*//' || echo "unknown")"

    # Find corresponding outbox file
    local outbox_file=""
    for f in "$OUTBOX_DIR/${run_key}"*RESULT.md "$OUTBOX_DIR/${run_key}"*__RESULT.md; do
        [[ -f "$f" ]] && outbox_file="$f" && break
    done

    # Determine if this needs an open loop
    local needs_loop=false
    local severity="low"
    local title=""
    local next_action=""
    local owner="unassigned"

    # Rule 1: Non-OK status → loop
    case "$status" in
        done|DONE|ok|OK|pass|PASS|success|SUCCESS)
            ;;
        failed|FAILED|error|ERROR)
            needs_loop=true
            severity="high"
            title="Run failed: $run_key"
            next_action="Investigate failure and retry or escalate"
            ;;
        *)
            needs_loop=true
            severity="medium"
            title="Unknown status for: $run_key"
            next_action="Review and classify"
            ;;
    esac

    # Rule 2: Check outbox for warning/needs_input markers
    if [[ -f "$outbox_file" ]]; then
        if grep -qiE "WARNING:|NEEDS_INPUT:|BLOCKED|MANUAL|APPROVAL" "$outbox_file" 2>/dev/null; then
            needs_loop=true
            severity="medium"
            title="Action required: $run_key"
            next_action="Review outbox and take required action"
        fi

        # Rule 3: Check for "dry-run" markers
        if grep -qiE "dry.run|DRY_RUN|--dry" "$outbox_file" 2>/dev/null; then
            needs_loop=true
            severity="low"
            title="Dry-run needs approval: $run_key"
            next_action="Review dry-run output and execute if approved"
        fi

        # Try to extract owner from outbox content
        if grep -qiE "finance|invoice|receipt|payment" "$outbox_file" 2>/dev/null; then
            owner="finance"
        elif grep -qiE "customer|order|quote" "$outbox_file" 2>/dev/null; then
            owner="customer-service"
        elif grep -qiE "file|upload|asset|artwork" "$outbox_file" 2>/dev/null; then
            owner="files"
        fi
    fi

    # Write loop if needed
    if [[ "$needs_loop" == "true" ]]; then
        local loop_id
        loop_id="$(gen_loop_id "$run_key" "$(echo "$run_key" | cut -d'_' -f3 | head -c10)")"
        local created_at
        created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

        # Build evidence array
        local evidence="[\"$receipt_file\""
        [[ -n "$outbox_file" ]] && evidence+=",\"$outbox_file\""
        evidence+="]"

        # Write JSONL record
        cat >> "$LOOPS_FILE" <<EOF
{"loop_id":"$loop_id","run_key":"$run_key","created_at":"$created_at","status":"open","severity":"$severity","owner":"$owner","title":"$title","next_action":"$next_action","evidence":$evidence}
EOF

        echo "  CREATED: $loop_id ($severity) - $title"
    fi
}

# Collect loops from recent receipts
collect_loops() {
    echo "=== COLLECTING OPEN LOOPS ==="
    echo ""

    local count=0

    # Scan recent receipt directories (last 50)
    for receipt_dir in $(ls -1td "$RECEIPTS_DIR"/* 2>/dev/null | head -50); do
        [[ -d "$receipt_dir" ]] || continue
        extract_loops_from_receipt "$receipt_dir"
        count=$((count + 1))
    done

    echo ""
    echo "Scanned $count receipts"
    echo "Loops file: $LOOPS_FILE"
}

# List loops
list_loops() {
    local filter="${1:---open}"

    echo "=== OPEN LOOPS ==="
    echo ""

    if [[ ! -s "$LOOPS_FILE" ]]; then
        echo "(no loops)"
        return 0
    fi

    case "$filter" in
        --open)
            grep '"status":"open"' "$LOOPS_FILE" 2>/dev/null | while read -r line; do
                local loop_id severity owner title
                loop_id="$(echo "$line" | jq -r '.loop_id')"
                severity="$(echo "$line" | jq -r '.severity')"
                owner="$(echo "$line" | jq -r '.owner')"
                title="$(echo "$line" | jq -r '.title')"
                printf "  [%s] %-12s %-15s %s\n" "$severity" "$owner" "$loop_id" "$title"
            done
            ;;
        --closed)
            grep '"status":"closed"' "$LOOPS_FILE" 2>/dev/null | while read -r line; do
                local loop_id severity owner title
                loop_id="$(echo "$line" | jq -r '.loop_id')"
                severity="$(echo "$line" | jq -r '.severity')"
                owner="$(echo "$line" | jq -r '.owner')"
                title="$(echo "$line" | jq -r '.title')"
                printf "  [%s] %-12s %-15s %s\n" "$severity" "$owner" "$loop_id" "$title"
            done
            ;;
        --all)
            while read -r line; do
                local loop_id severity owner title status
                loop_id="$(echo "$line" | jq -r '.loop_id')"
                severity="$(echo "$line" | jq -r '.severity')"
                owner="$(echo "$line" | jq -r '.owner')"
                title="$(echo "$line" | jq -r '.title')"
                status="$(echo "$line" | jq -r '.status')"
                printf "  [%s] %-6s %-12s %-15s %s\n" "$severity" "$status" "$owner" "$loop_id" "$title"
            done < "$LOOPS_FILE"
            ;;
    esac

    echo ""
    local open_count
    open_count="$(grep -c '"status":"open"' "$LOOPS_FILE" 2>/dev/null || echo 0)"
    echo "Open loops: $open_count"
}

# Close a loop
close_loop() {
    local loop_id="$1"

    if ! grep -q "\"loop_id\":\"$loop_id\"" "$LOOPS_FILE" 2>/dev/null; then
        echo "ERROR: Loop not found: $loop_id"
        exit 1
    fi

    # Update status to closed (append new record with closed status)
    local closed_at
    closed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Get the original record and update it
    local original
    original="$(grep "\"loop_id\":\"$loop_id\"" "$LOOPS_FILE" | tail -1)"

    local updated
    updated="$(echo "$original" | jq -c ". + {\"status\":\"closed\",\"closed_at\":\"$closed_at\"}")"

    echo "$updated" >> "$LOOPS_FILE"

    echo "CLOSED: $loop_id at $closed_at"
}

# Show loop details
show_loop() {
    local loop_id="$1"

    local record
    record="$(grep "\"loop_id\":\"$loop_id\"" "$LOOPS_FILE" 2>/dev/null | tail -1)"

    if [[ -z "$record" ]]; then
        echo "ERROR: Loop not found: $loop_id"
        exit 1
    fi

    echo "=== LOOP: $loop_id ==="
    echo ""
    echo "$record" | jq .
}

# Summary
summary() {
    echo "=== LOOP SUMMARY ==="
    echo ""

    if [[ ! -s "$LOOPS_FILE" ]]; then
        echo "No loops recorded."
        return 0
    fi

    echo "By Status:"
    echo "  Open:   $(grep -c '"status":"open"' "$LOOPS_FILE" 2>/dev/null || echo 0)"
    echo "  Closed: $(grep -c '"status":"closed"' "$LOOPS_FILE" 2>/dev/null || echo 0)"
    echo ""

    echo "By Severity (open only):"
    echo "  High:   $(grep '"status":"open"' "$LOOPS_FILE" 2>/dev/null | grep -c '"severity":"high"' || echo 0)"
    echo "  Medium: $(grep '"status":"open"' "$LOOPS_FILE" 2>/dev/null | grep -c '"severity":"medium"' || echo 0)"
    echo "  Low:    $(grep '"status":"open"' "$LOOPS_FILE" 2>/dev/null | grep -c '"severity":"low"' || echo 0)"
    echo ""

    echo "By Owner (open only):"
    grep '"status":"open"' "$LOOPS_FILE" 2>/dev/null | jq -r '.owner' | sort | uniq -c | while read -r count owner; do
        printf "  %-15s %s\n" "$owner:" "$count"
    done
}

# Main
case "${1:-}" in
    list)
        check_deps
        ensure_state_dir
        list_loops "${2:---open}"
        ;;
    collect)
        ensure_state_dir
        collect_loops
        ;;
    close)
        [[ -z "${2:-}" ]] && { echo "Usage: ops loops close <loop_id>"; exit 1; }
        check_deps
        ensure_state_dir
        close_loop "$2"
        ;;
    show)
        [[ -z "${2:-}" ]] && { echo "Usage: ops loops show <loop_id>"; exit 1; }
        check_deps
        ensure_state_dir
        show_loop "$2"
        ;;
    summary)
        check_deps
        ensure_state_dir
        summary
        ;;
    -h|--help|"")
        usage
        ;;
    *)
        echo "Unknown subcommand: $1"
        usage
        exit 1
        ;;
esac
