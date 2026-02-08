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

SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
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

Environment:
  LOOPS_LEDGER_FAILURE_WINDOW_HOURS  Failed-run reconciliation window (default: 0, disabled)
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

# Extract open loops from a receipt (file-based rule engine).
#
# Scans a receipt directory and applies three rules to decide whether
# the run produces an open loop requiring human or agent follow-up.
#
# Rule 1: Non-OK status         → open loop (high severity)
# Rule 2: Outbox markers        → open loop (WARNING/NEEDS_INPUT/BLOCKED = action required)
# Rule 3: Dry-run outputs       → open loop (low severity, requires explicit approval)
#
# If a loop is created it is appended to the JSONL ledger (append-only).
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

    # ── Rule 1: Non-OK status → open loop ──
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

    # ── Rule 2: Outbox markers (WARNING/NEEDS_INPUT/BLOCKED) → action required ──
    if [[ -f "$outbox_file" ]]; then
        if grep -qiE "WARNING:|NEEDS_INPUT:|BLOCKED|MANUAL|APPROVAL" "$outbox_file" 2>/dev/null; then
            needs_loop=true
            severity="medium"
            title="Action required: $run_key"
            next_action="Review outbox and take required action"
        fi

        # ── Rule 3: Dry-run outputs → require explicit approval ──
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

    # ── Write section: JSONL append-only ledger ──
    if [[ "$needs_loop" == "true" ]]; then
        local loop_id
        loop_id="$(gen_loop_id "$run_key" "$(echo "$run_key" | cut -d'_' -f3 | head -c10)")"
        local created_at
        created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

        # Build evidence array
        local evidence="[\"$receipt_file\""
        [[ -n "$outbox_file" ]] && evidence+=",\"$outbox_file\""
        evidence+="]"

        # Append JSONL record (append-only, never overwrite)
        cat >> "$LOOPS_FILE" <<EOF
{"loop_id":"$loop_id","run_key":"$run_key","created_at":"$created_at","status":"open","severity":"$severity","owner":"$owner","title":"$title","next_action":"$next_action","evidence":$evidence}
EOF

        echo "  CREATED: $loop_id ($severity) - $title"
    fi
}

collect_failed_from_ledger() {
    python3 - "$LOOPS_FILE" "$LEDGER" "$RECEIPTS_DIR" "$OUTBOX_DIR" <<'PY'
import csv
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

loops_file = Path(sys.argv[1])
ledger_file = Path(sys.argv[2])
receipts_dir = Path(sys.argv[3])
outbox_dir = Path(sys.argv[4])

window_hours = int(os.environ.get("LOOPS_LEDGER_FAILURE_WINDOW_HOURS", "0"))
now_utc = datetime.now(timezone.utc)
cutoff = now_utc - timedelta(hours=window_hours) if window_hours > 0 else None

existing_run_keys = set()
existing_loop_ids = set()

if loops_file.exists():
    with loops_file.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            run_key = row.get("run_key")
            loop_id = row.get("loop_id")
            if run_key:
                existing_run_keys.add(run_key)
            if loop_id:
                existing_loop_ids.add(loop_id)

latest_by_run_id = {}
if ledger_file.exists():
    with ledger_file.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            run_id = row.get("run_id", "")
            if run_id:
                latest_by_run_id[run_id] = row

def parse_iso(ts: str):
    ts = (ts or "").strip()
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return None

def new_loop_id(run_key: str) -> str:
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    suffix = re.sub(r"[^A-Za-z0-9]+", "_", run_key).strip("_")[:10] or "failed"
    base = f"OL_{ts}_{suffix}"
    if base not in existing_loop_ids:
        existing_loop_ids.add(base)
        return base

    i = 2
    while True:
        candidate = f"{base}{i}"
        if candidate not in existing_loop_ids:
            existing_loop_ids.add(candidate)
            return candidate
        i += 1

new_rows = []
for run_id, row in latest_by_run_id.items():
    status = (row.get("status") or "").strip().lower()
    if status != "failed":
        continue

    created_at_row = parse_iso(row.get("created_at"))
    if cutoff is not None:
        if created_at_row is None or created_at_row < cutoff:
            continue

    prompt_file = (row.get("prompt_file") or "").strip()
    if prompt_file.endswith(".md") or prompt_file.endswith(".txt"):
        run_key = Path(prompt_file).stem
    else:
        run_key = run_id

    if not run_key or run_key in existing_run_keys:
        continue

    created_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    loop_id = new_loop_id(run_key)

    evidence = [str(ledger_file)]

    receipt_candidates = [
        receipts_dir / f"R{run_key}" / "receipt.md",
        receipts_dir / f"R{run_id}" / "receipt.md",
    ]
    for cand in receipt_candidates:
        if cand.exists():
            evidence.append(str(cand))
            break

    result_file = (row.get("result_file") or "").strip()
    if result_file and result_file != "receipt.md":
        outbox_file = outbox_dir / result_file
        if outbox_file.exists():
            evidence.append(str(outbox_file))

    new_row = {
        "loop_id": loop_id,
        "run_key": run_key,
        "created_at": created_at,
        "status": "open",
        "severity": "high",
        "owner": "unassigned",
        "title": f"Run failed: {run_key}",
        "next_action": "Investigate failure and retry or escalate",
        "evidence": evidence,
    }
    new_rows.append(new_row)
    existing_run_keys.add(run_key)

if not new_rows:
    if cutoff is not None:
        print(f"  LEDGER: no new failed-run loops in last {window_hours}h")
    else:
        print("  LEDGER: no new failed-run loops")
    sys.exit(0)

loops_file.parent.mkdir(parents=True, exist_ok=True)
with loops_file.open("a", encoding="utf-8") as f:
    for row in new_rows:
        f.write(json.dumps(row, separators=(",", ":")) + "\n")

print(f"  LEDGER: created {len(new_rows)} failed-run loop(s)")
for row in new_rows:
    print(f"  CREATED: {row['loop_id']} (high) - {row['title']}")
PY
}

# Collect loops from receipts and ledger latest-state failures.
collect_loops() {
    echo "=== COLLECTING OPEN LOOPS ==="
    echo ""

    local scanned=0
    local before_receipt_lines=0
    local after_receipt_lines=0
    local before_ledger_lines=0
    local after_ledger_lines=0

    before_receipt_lines="$(wc -l < "$LOOPS_FILE" 2>/dev/null || echo 0)"

    while IFS= read -r receipt_dir; do
        [[ -d "$receipt_dir" ]] || continue
        extract_loops_from_receipt "$receipt_dir"
        scanned=$((scanned + 1))
    done < <(find "$RECEIPTS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

    after_receipt_lines="$(wc -l < "$LOOPS_FILE" 2>/dev/null || echo 0)"

    before_ledger_lines="$after_receipt_lines"
    collect_failed_from_ledger
    after_ledger_lines="$(wc -l < "$LOOPS_FILE" 2>/dev/null || echo 0)"

    echo ""
    echo "Scanned receipts: $scanned"
    echo "Created from receipts: $((after_receipt_lines - before_receipt_lines))"
    echo "Created from ledger failures: $((after_ledger_lines - before_ledger_lines))"
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

    # Canonical jq reducer:
    # 1. Normalize close records: {id, action:close} → {loop_id, status:closed}
    # 2. Deduplicate by loop_id (last entry per loop_id wins)
    # 3. Apply close records to filter out closed loops
    local jq_reduce
    jq_reduce='[.[] | if .action == "close" then {loop_id: .id, status: "closed", closed_at: .closed_at, close_reason: .reason} else . end | select(.loop_id != null)] | reduce .[] as $i ({}; .[$i.loop_id] = ((.[$i.loop_id] // {}) * $i)) | [.[]]'

    case "$filter" in
        --open)
            while IFS=$'\t' read -r loop_id severity owner title; do
                printf "  [%s] %-12s %-15s %s\n" "$severity" "$owner" "$loop_id" "$title"
            done < <(jq -s -r "$jq_reduce | .[] | select(.status==\"open\") | \"\(.loop_id)\t\(.severity)\t\(.owner)\t\(.title)\"" "$LOOPS_FILE")
            ;;
        --closed)
            while IFS=$'\t' read -r loop_id severity owner title; do
                printf "  [%s] %-12s %-15s %s\n" "$severity" "$owner" "$loop_id" "$title"
            done < <(jq -s -r "$jq_reduce | .[] | select(.status==\"closed\") | \"\(.loop_id)\t\(.severity)\t\(.owner)\t\(.title)\"" "$LOOPS_FILE")
            ;;
        --all)
            while IFS=$'\t' read -r loop_id status severity owner title; do
                printf "  [%s] %-6s %-12s %-15s %s\n" "$severity" "$status" "$owner" "$loop_id" "$title"
            done < <(jq -s -r "$jq_reduce | .[] | \"\(.loop_id)\t\(.status)\t\(.severity)\t\(.owner)\t\(.title)\"" "$LOOPS_FILE")
            ;;
    esac

    echo ""
    local open_count
    open_count="$(jq -s -r "$jq_reduce | [.[] | select(.status==\"open\")] | length" "$LOOPS_FILE")"
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

# Summary - uses canonical reducer for deduped counts
summary() {
    echo "=== LOOP SUMMARY ==="
    echo ""

    # Use canonical reducer for deterministic deduped counts
    local reducer="$SPINE_REPO/ops/plugins/loops/bin/loops-ledger-reduce"

    if [[ ! -x "$reducer" ]]; then
        echo "ERROR: loops-ledger-reduce not found or not executable" >&2
        exit 1
    fi

    "$reducer" --summary
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
