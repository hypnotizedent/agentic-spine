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

RECEIPTS_DIR="$SPINE_REPO/receipts/sessions"
LEDGER="$STATE_DIR/ledger.csv"

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

# ── Collect (deprecated — no-op) ──────────────────────────────────────────
collect_loops() {
    echo "=== ops loops collect — DEPRECATED ==="
    echo ""
    echo "Loop state moved from open_loops.jsonl to scope files."
    echo "Canonical tracking: mailroom/state/loop-scopes/*.scope.md"
    echo ""
    echo "To see open work:  ops status"
    echo "To list loops:     ops loops list --open"
    echo "To create a loop:  create a scope file in $SCOPES_DIR/"
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
