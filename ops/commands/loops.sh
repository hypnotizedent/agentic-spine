#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops loops - Open Loop Engine (scope-file backed)
# ═══════════════════════════════════════════════════════════════════════════
#
# Usage:
#   ops loops list [--open|--closed|--all]   List loops from scope files
#   ops loops close <loop_id>                 Mark loop as closed (updates scope)
#   ops loops show <loop_id>                  Show loop scope file
#   ops loops summary                         Show loop counts by status/severity
#   ops loops collect                         (deprecated) Legacy receipt scanner
#
# Canonical: loop-scopes/*.scope.md are the SSOT for open work.
# See: LOOP-MAILROOM-CONSOLIDATION-20260210 for the migration rationale.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
STATE_DIR="$SPINE_REPO/mailroom/state"
SCOPES_DIR="$STATE_DIR/loop-scopes"

# Legacy paths (kept for collect backward compat)
LOOPS_FILE="$STATE_DIR/open_loops.jsonl"
RECEIPTS_DIR="$SPINE_REPO/receipts/sessions"
OUTBOX_DIR="$SPINE_REPO/mailroom/outbox"
LEDGER="$STATE_DIR/ledger.csv"
CURSOR_FILE="$STATE_DIR/loops_collect.cursor"

usage() {
    cat <<'EOF'
ops loops - Open Loop Engine (scope-file backed)

Usage:
  ops loops list [--open|--closed|--all]   List loops (default: open only)
  ops loops close <loop_id>                 Mark loop as closed
  ops loops show <loop_id>                  Show loop scope file
  ops loops summary                         Show loop counts by status/severity

Deprecated:
  ops loops collect                         Legacy receipt scanner (writes JSONL)

Canonical source: mailroom/state/loop-scopes/*.scope.md
EOF
}

# ── Frontmatter helpers ───────────────────────────────────────────────────
# Extract a single YAML frontmatter field from a scope file.
# Uses awk to isolate the frontmatter block, then grep+sed to pull the value.
_fm_field() {
    local file="$1" field="$2"
    awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$file" \
        | { grep "^${field}:" || true; } \
        | sed "s/^${field}: *//" \
        | tr -d '"' \
        | head -1
}

# Extract the title from the first markdown heading after frontmatter.
_scope_title() {
    local file="$1"
    local title
    title="$(awk '/^---$/{n++; next} n>=2{print}' "$file" \
        | grep -m1 '^#' \
        | sed 's/^#* *//' \
        | sed 's/^Loop Scope: //')"
    echo "${title:-$(basename "$file" .scope.md)}"
}

# Is this status considered "open"?
_is_open_status() {
    case "$1" in
        active|draft|open) return 0 ;;
        *) return 1 ;;
    esac
}

# ── List loops ────────────────────────────────────────────────────────────
list_loops() {
    local filter="${1:---open}"
    local label="OPEN LOOPS"
    [[ "$filter" == "--closed" ]] && label="CLOSED LOOPS"
    [[ "$filter" == "--all" ]] && label="ALL LOOPS"

    echo "=== $label ==="
    echo ""

    if [[ ! -d "$SCOPES_DIR" ]]; then
        echo "(no loops — $SCOPES_DIR not found)"
        return 0
    fi

    local has_scopes=false
    for f in "$SCOPES_DIR"/*.scope.md; do
        [[ -f "$f" ]] && has_scopes=true && break
    done
    if [[ "$has_scopes" == "false" ]]; then
        echo "(no loops)"
        return 0
    fi

    local count=0
    for scope_file in "$SCOPES_DIR"/*.scope.md; do
        [[ -f "$scope_file" ]] || continue

        local loop_id status severity owner title
        loop_id="$(_fm_field "$scope_file" "loop_id")"
        [[ -z "$loop_id" ]] && continue

        status="$(_fm_field "$scope_file" "status")"
        severity="$(_fm_field "$scope_file" "severity")"
        owner="$(_fm_field "$scope_file" "owner")"
        title="$(_scope_title "$scope_file")"

        # Normalize missing fields
        [[ -z "$status" ]] && status="unknown"
        [[ -z "$severity" ]] && severity="-"
        [[ -z "$owner" ]] && owner="unassigned"

        # Skip non-loop scope files (e.g. status: authoritative)
        case "$status" in
            active|draft|open|closed) ;;
            *) continue ;;
        esac

        # Only show title if it differs from loop_id
        local display_title=""
        [[ "$title" != "$loop_id" ]] && display_title="$title"

        case "$filter" in
            --open)
                _is_open_status "$status" || continue
                printf "  [%-8s] %-15s %s" "$severity" "$owner" "$loop_id"
                [[ -n "$display_title" ]] && printf "  %s" "$display_title"
                printf "\n"
                ;;
            --closed)
                _is_open_status "$status" && continue
                printf "  [%-8s] %-15s %s" "$severity" "$owner" "$loop_id"
                [[ -n "$display_title" ]] && printf "  %s" "$display_title"
                printf "\n"
                ;;
            --all)
                printf "  [%-8s] %-8s %-15s %s" "$severity" "$status" "$owner" "$loop_id"
                [[ -n "$display_title" ]] && printf "  %s" "$display_title"
                printf "\n"
                ;;
        esac
        count=$((count + 1))
    done

    echo ""
    if [[ "$filter" == "--open" ]]; then
        echo "Open loops: $count"
    else
        echo "Loops shown: $count"
    fi
}

# ── Show loop ─────────────────────────────────────────────────────────────
show_loop() {
    local loop_id="$1"
    local scope_file="$SCOPES_DIR/${loop_id}.scope.md"

    if [[ ! -f "$scope_file" ]]; then
        echo "ERROR: Scope file not found: $scope_file" >&2
        exit 1
    fi

    echo "=== LOOP: $loop_id ==="
    echo "File: $scope_file"
    echo ""
    cat "$scope_file"
}

# ── Close loop ────────────────────────────────────────────────────────────
close_loop() {
    local loop_id="$1"
    local scope_file="$SCOPES_DIR/${loop_id}.scope.md"

    if [[ ! -f "$scope_file" ]]; then
        echo "ERROR: Scope file not found: $scope_file" >&2
        exit 1
    fi

    local current_status
    current_status="$(_fm_field "$scope_file" "status")"
    if [[ "$current_status" == "closed" ]]; then
        echo "ALREADY CLOSED: $loop_id"
        return 0
    fi

    # Cross-platform sed -i
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' 's/^status: .*/status: closed/' "$scope_file"
    else
        sed -i 's/^status: .*/status: closed/' "$scope_file"
    fi

    echo "CLOSED: $loop_id (updated $scope_file)"
}

# ── Summary ───────────────────────────────────────────────────────────────
summary() {
    echo "=== LOOP SUMMARY ==="
    echo ""

    if [[ ! -d "$SCOPES_DIR" ]]; then
        echo "Open: 0"
        echo "Closed: 0"
        echo "Total: 0"
        return 0
    fi

    # Python for reliable counting (associative arrays need bash 4+, macOS ships bash 3)
    python3 - "$SCOPES_DIR" <<'PY'
import os
import re
import sys
from collections import Counter
from pathlib import Path

scopes_dir = Path(sys.argv[1])
if not scopes_dir.is_dir():
    print("Open: 0\nClosed: 0\nTotal: 0")
    sys.exit(0)

open_count = 0
closed_count = 0
total = 0
severity_counts = Counter()
owner_counts = Counter()

FM_RE = re.compile(r'^---\s*$')

for f in sorted(scopes_dir.glob("*.scope.md")):
    lines = f.read_text().splitlines()
    in_fm = False
    fm = {}
    for line in lines:
        if FM_RE.match(line):
            if in_fm:
                break
            in_fm = True
            continue
        if in_fm and ':' in line:
            key, _, val = line.partition(':')
            fm[key.strip()] = val.strip().strip('"')

    status = fm.get("status", "")
    if status not in ("active", "draft", "open", "closed"):
        continue

    total += 1
    severity = fm.get("severity", "unknown")
    owner = fm.get("owner", "unassigned")

    if status in ("active", "draft", "open"):
        open_count += 1
        severity_counts[severity] += 1
        owner_counts[owner] += 1
    elif status == "closed":
        closed_count += 1

print("By Status:")
print(f"  Open:   {open_count}")
print(f"  Closed: {closed_count}")
print(f"  Total:  {total}")
print()

print("By Severity (open only):")
for sev in ("critical", "high", "medium", "low", "unknown"):
    c = severity_counts.get(sev, 0)
    if c > 0 or sev in ("critical", "high", "medium", "low"):
        print(f"  {sev.capitalize():10s} {c}")
print()

print("By Owner (open only):")
if not owner_counts:
    print("  (none)")
else:
    for owner in sorted(owner_counts):
        print(f"  {owner}: {owner_counts[owner]}")
PY
}

# ── Collect (deprecated — kept for backward compat) ───────────────────────
collect_loops() {
    echo "=== COLLECTING OPEN LOOPS (DEPRECATED) ==="
    echo ""
    echo "WARNING: 'ops loops collect' writes to open_loops.jsonl which is deprecated."
    echo "Canonical work tracking now uses loop-scopes/*.scope.md files."
    echo "Machine-generated OL_* loops will continue to work but are not shown by 'ops loops list'."
    echo "To create a new loop: create a scope file in $SCOPES_DIR/"
    echo ""

    # Keep legacy collect functioning for receipt scanning
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq is required for legacy collect." >&2
        exit 2
    fi

    local scanned=0
    local backfill="${LOOPS_RECEIPT_BACKFILL:-0}"
    local cursor_epoch=""
    local now_epoch=""
    now_epoch="$(date +%s)"

    if [[ "$backfill" != "1" ]]; then
        if [[ -f "$CURSOR_FILE" ]]; then
            cursor_epoch="$(cat "$CURSOR_FILE" 2>/dev/null | tr -dc '0-9')"
        fi
        if [[ -z "$cursor_epoch" ]]; then
            cursor_epoch="$now_epoch"
            echo "$cursor_epoch" > "$CURSOR_FILE"
            echo "  CURSOR_INIT: skipping historical receipts"
            echo ""
        fi
    else
        cursor_epoch="0"
        echo "  BACKFILL: scanning all receipts"
        echo ""
    fi

    # Cross-platform mtime
    mtime_epoch() {
        local path="$1"
        if stat -f %m "$path" >/dev/null 2>&1; then
            stat -f %m "$path"
        else
            stat -c %Y "$path"
        fi
    }

    while IFS= read -r receipt_dir; do
        [[ -d "$receipt_dir" ]] || continue
        local base
        base="$(basename "$receipt_dir")"
        [[ "$base" == R* ]] || continue

        if [[ "$cursor_epoch" != "0" ]]; then
            local receipt_file="$receipt_dir/receipt.md"
            local mtime_path="$receipt_dir"
            [[ -f "$receipt_file" ]] && mtime_path="$receipt_file"
            local mtime
            mtime="$(mtime_epoch "$mtime_path" 2>/dev/null || echo 0)"
            [[ "$mtime" -ge "$cursor_epoch" ]] || continue
        fi

        # Legacy: append to JSONL (not scope files)
        _extract_loops_from_receipt "$receipt_dir"
        scanned=$((scanned + 1))
    done < <(find "$RECEIPTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

    if [[ "$backfill" != "1" ]]; then
        echo "$now_epoch" > "$CURSOR_FILE" 2>/dev/null || true
    fi

    echo ""
    echo "Scanned receipts: $scanned"
    echo "Note: results written to deprecated JSONL. Use scope files for canonical tracking."
}

# Legacy receipt extraction (writes JSONL, not scope files)
_extract_loops_from_receipt() {
    local receipt_dir="$1"
    local receipt_file="$receipt_dir/receipt.md"

    [[ -f "$receipt_file" ]] || return 0

    local run_key
    run_key="$(grep -m1 "Run Key" "$receipt_file" 2>/dev/null | sed 's/.*`\([^`]*\)`.*/\1/' || echo "")"
    [[ -z "$run_key" ]] && run_key="$(basename "$receipt_dir" | sed 's/^R//')"

    if grep -q "\"run_key\":\"$run_key\"" "$LOOPS_FILE" 2>/dev/null; then
        return 0
    fi

    local status
    status="$(grep -m1 "| Status |" "$receipt_file" 2>/dev/null | sed 's/.*| Status | *//' | sed 's/ *|.*//' || echo "unknown")"

    case "$status" in
        done|DONE|ok|OK|pass|PASS|success|SUCCESS) return 0 ;;
    esac

    local ts loop_id
    ts="$(date +%Y%m%d_%H%M%S)"
    loop_id="OL_${ts}_$(echo "$run_key" | cut -d'_' -f3 | head -c10)"
    local created_at
    created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    cat >> "$LOOPS_FILE" <<EOF
{"loop_id":"$loop_id","run_key":"$run_key","created_at":"$created_at","status":"open","severity":"high","owner":"unassigned","title":"Run failed: $run_key","next_action":"Investigate failure and retry or escalate","evidence":["$receipt_file"]}
EOF

    echo "  CREATED (JSONL): $loop_id - Run failed: $run_key"
}

# ── Main ──────────────────────────────────────────────────────────────────
case "${1:-}" in
    list)
        list_loops "${2:---open}"
        ;;
    collect)
        mkdir -p "$STATE_DIR"
        collect_loops
        ;;
    close)
        [[ -z "${2:-}" ]] && { echo "Usage: ops loops close <loop_id>"; exit 1; }
        close_loop "$2"
        ;;
    show)
        [[ -z "${2:-}" ]] && { echo "Usage: ops loops show <loop_id>"; exit 1; }
        show_loop "$2"
        ;;
    summary)
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
