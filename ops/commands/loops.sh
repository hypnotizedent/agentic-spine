#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops loops - Open Loop Engine (scope-file backed)
# ═══════════════════════════════════════════════════════════════════════════
#
# Usage:
#   ops loops list [--open|--closed|--all]   List loops from scope files
#   ops loops close <loop_id> --disposition <state>  Mark loop as closed (updates scope)
#   ops loops show <loop_id>                  Show loop scope file
#   ops loops summary                         Show loop counts by status/severity
#   ops loops collect                         (deprecated) Legacy receipt scanner
#
# Canonical: loop-scopes/*.scope.md are the SSOT for open work.
# See: LOOP-MAILROOM-CONSOLIDATION-20260210 for the migration rationale.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SPINE_REPO/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths

STATE_DIR="$SPINE_STATE"
SCOPES_DIR="$STATE_DIR/loop-scopes"
source "$SPINE_REPO/ops/lib/git-lock.sh"

RECEIPTS_DIR="$SPINE_RECEIPTS"
LEDGER="$STATE_DIR/ledger.csv"
DISPOSITION_CONTRACT="$SPINE_REPO/ops/bindings/closeout.disposition.contract.yaml"

usage() {
    cat <<'EOF'
ops loops - Open Loop Engine (scope-file backed)

Usage:
  ops loops list [--open|--closed|--all]   List loops (default: open only)
  ops loops close <loop_id> --disposition <state> [--close-summary "<text>"]
                                           Mark loop as closed
  ops loops show <loop_id>                  Show loop scope file
  ops loops summary                         Show loop counts by status/severity

Deprecated:
  ops loops collect                         Legacy receipt scanner (writes JSONL)

Canonical source: .runtime/spine/state/loop-scopes/*.scope.md
EOF
}

_close_dispositions_csv() {
    local csv="landed,deferred,superseded,abandoned"
    local accum=""
    local disposition=""

    if command -v yq >/dev/null 2>&1 && [[ -f "$DISPOSITION_CONTRACT" ]]; then
        while IFS= read -r disposition; do
            [[ -n "$disposition" && "$disposition" != "null" ]] || continue
            if [[ -n "$accum" ]]; then
                accum+=",$disposition"
            else
                accum="$disposition"
            fi
        done < <(yq e -r '.terminal_dispositions.allowed[]?' "$DISPOSITION_CONTRACT" 2>/dev/null || true)
        [[ -n "$accum" ]] && csv="$accum"
    fi

    printf '%s\n' "$csv"
}

_require_close_disposition() {
    local disposition="${1:-}"
    local csv="${2:-$(_close_dispositions_csv)}"
    local missing_msg="Closed work must declare disposition: ${csv//,/|}."
    local invalid_msg="Disposition must be one of: ${csv//,/|}."
    local item=""

    if command -v yq >/dev/null 2>&1 && [[ -f "$DISPOSITION_CONTRACT" ]]; then
        missing_msg="$(yq e -r '.messages.missing // ""' "$DISPOSITION_CONTRACT" 2>/dev/null || echo "$missing_msg")"
        [[ -n "$missing_msg" && "$missing_msg" != "null" ]] || missing_msg="Closed work must declare disposition: ${csv//,/|}."
        invalid_msg="$(yq e -r '.messages.invalid // ""' "$DISPOSITION_CONTRACT" 2>/dev/null || echo "$invalid_msg")"
        [[ -n "$invalid_msg" && "$invalid_msg" != "null" ]] || invalid_msg="Disposition must be one of: ${csv//,/|}."
    fi

    if [[ -z "$disposition" ]]; then
        echo "ERROR: $missing_msg" >&2
        exit 1
    fi

    IFS=',' read -r -a _allowed_items <<< "$csv"
    for item in "${_allowed_items[@]}"; do
        [[ "$disposition" == "$item" ]] && return 0
    done

    echo "ERROR: $invalid_msg" >&2
    exit 1
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

# Return pending proposal count for a loop and emit matching proposal ids.
# Output format:
#   line 1: numeric pending count
#   line N: CP-... ids (one per line)
_pending_proposals_for_loop() {
    local loop_id="$1"
    local proposals_dir="$SPINE_OUTBOX/proposals"
    local proposal_dir manifest status cp_loop_id
    local count=0
    local matches=""

    [[ -d "$proposals_dir" ]] || {
        echo "0"
        return 0
    }

    for proposal_dir in "$proposals_dir"/CP-*; do
        [[ -d "$proposal_dir" ]] || continue
        [[ -f "$proposal_dir/.applied" ]] && continue

        manifest="$proposal_dir/manifest.yaml"
        [[ -f "$manifest" ]] || continue

        status="$(awk -F': *' '/^status:/{print $2; exit}' "$manifest" | tr -d '"' | tr -d "'" || true)"
        [[ -z "$status" ]] && status="pending"
        [[ "$status" != "pending" ]] && continue

        cp_loop_id="$(awk -F': *' '/^loop_id:/{print $2; exit}' "$manifest" | tr -d '"' | tr -d "'" || true)"
        [[ "$cp_loop_id" == "null" ]] && cp_loop_id=""

        if [[ "$cp_loop_id" == "$loop_id" ]]; then
            count=$((count + 1))
            matches="${matches}$(basename "$proposal_dir")"$'\n'
        fi
    done

    echo "$count"
    if [[ -n "$matches" ]]; then
        printf '%s' "$matches"
    fi
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

        local loop_id status severity owner title execution_mode active_terminal blocked_by
        local display_title="" state_tags="" detail=""
        loop_id="$(_fm_field "$scope_file" "loop_id")"
        [[ -z "$loop_id" ]] && continue

        status="$(_fm_field "$scope_file" "status")"
        severity="$(_fm_field "$scope_file" "severity")"
        owner="$(_fm_field "$scope_file" "owner")"
        title="$(_scope_title "$scope_file")"
        execution_mode="$(_fm_field "$scope_file" "execution_mode")"
        active_terminal="$(_fm_field "$scope_file" "active_terminal")"
        blocked_by="$(_fm_field "$scope_file" "blocked_by")"
        local horizon execution_readiness
        horizon="$(_fm_field "$scope_file" "horizon")"
        execution_readiness="$(_fm_field "$scope_file" "execution_readiness")"

        # Normalize missing fields
        [[ -z "$status" ]] && status="unknown"
        [[ -z "$severity" ]] && severity="-"
        [[ -z "$owner" ]] && owner="unassigned"

        # Skip non-loop scope files (e.g. status: authoritative)
        case "$status" in
            active|draft|open|closed|planned) ;;
            *) continue ;;
        esac

        # Only show title if it differs from loop_id
        [[ "$title" != "$loop_id" ]] && display_title="$title"

        [[ "$execution_mode" == "background" ]] && state_tags="${state_tags} [background]"
        if [[ -n "$blocked_by" && "$blocked_by" != "none" ]]; then
            state_tags="${state_tags} [blocked]"
        fi
        # Show horizon tag for non-now items
        if [[ -n "$horizon" && "$horizon" != "now" ]]; then
            state_tags="${state_tags} [${horizon}]"
        fi
        if [[ -n "$execution_readiness" && "$execution_readiness" == "blocked" ]]; then
            state_tags="${state_tags} [not-runnable]"
        fi

        case "$filter" in
            --open)
                _is_open_status "$status" || continue
                printf "  [%-8s] %-15s %s%s" "$severity" "$owner" "$loop_id" "$state_tags"
                [[ -n "$display_title" ]] && printf "  %s" "$display_title"
                printf "\n"
                detail=""
                if [[ "$execution_mode" == "background" ]]; then
                    detail="execution=background"
                    [[ -n "$active_terminal" ]] && detail="${detail}; terminal=${active_terminal}"
                fi
                if [[ -n "$blocked_by" && "$blocked_by" != "none" ]]; then
                    [[ -n "$detail" ]] && detail="${detail}; "
                    detail="${detail}blocked_by=${blocked_by}"
                fi
                [[ -n "$detail" ]] && printf "  %-10s %-15s %s\n" "" "" "$detail"
                ;;
            --closed)
                _is_open_status "$status" && continue
                printf "  [%-8s] %-15s %s%s" "$severity" "$owner" "$loop_id" "$state_tags"
                [[ -n "$display_title" ]] && printf "  %s" "$display_title"
                printf "\n"
                ;;
            --all)
                printf "  [%-8s] %-8s %-15s %s%s" "$severity" "$status" "$owner" "$loop_id" "$state_tags"
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
    local loop_id=""
    local disposition=""
    local close_summary=""
    local scope_file=""
    local tmp_file=""
    local pending_blob pending_count
    local dispositions_csv=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --)
                shift
                ;;
            --disposition)
                disposition="${2:-}"
                shift 2
                ;;
            --close-summary)
                close_summary="${2:-}"
                shift 2
                ;;
            -*)
                echo "Unknown flag: $1" >&2
                exit 1
                ;;
            *)
                if [[ -z "$loop_id" ]]; then
                    loop_id="$1"
                else
                    echo "ERROR: Unexpected extra argument: $1" >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done

    [[ -n "$loop_id" ]] || { echo "Usage: ops loops close <loop_id> --disposition <state> [--close-summary \"<text>\"]" >&2; exit 1; }
    dispositions_csv="$(_close_dispositions_csv)"
    _require_close_disposition "$disposition" "$dispositions_csv"

    scope_file="$SCOPES_DIR/${loop_id}.scope.md"

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

    pending_blob="$(_pending_proposals_for_loop "$loop_id")"
    pending_count="$(printf '%s\n' "$pending_blob" | head -n1)"
    if [[ "${pending_count:-0}" -gt 0 ]]; then
        echo "BLOCKED: $loop_id has $pending_count pending linked proposal(s)." >&2
        echo "Resolve or supersede these proposals first:" >&2
        printf '%s\n' "$pending_blob" | tail -n +2 | sed '/^$/d' | sed 's/^/  - /' >&2
        exit 1
    fi

    local LOOPS_BRIDGE="$SPINE_REPO/ops/plugins/core/lifecycle/bin/loops-authority-bridge"
    [[ -x "$LOOPS_BRIDGE" ]] || {
        echo "ERROR: loops-authority-bridge not found: $LOOPS_BRIDGE" >&2
        exit 1
    }

    acquire_git_lock gaps || exit 1
    tmp_file="$(mktemp "${scope_file}.tmp.XXXXXX")"
    trap 'rm -f "$tmp_file" 2>/dev/null || true; release_git_lock' EXIT INT TERM

    local bridge_reason="Closed via ops loops close"
    [[ -n "${close_summary:-}" ]] && bridge_reason="${bridge_reason}: $close_summary"
    bridge_close_args=("close" "--id" "$loop_id" "--status" "closed"
        "--disposition" "$disposition"
        "--actor" "loops.close"
        "--reason" "$bridge_reason"
    )
    if [[ -z "${SPINE_CAP_RUN_KEY:-}" ]]; then
        bridge_close_args+=("--ungoverned-override")
    fi

    if ! python3 "$LOOPS_BRIDGE" "${bridge_close_args[@]}" >/dev/null; then
        echo "ERROR: loops-authority-bridge failed to close $loop_id" >&2
        exit 1
    fi

    if [[ -n "${close_summary:-}" ]]; then
        if ! python3 - "$scope_file" "$tmp_file" "$close_summary" <<'PY'
import sys
from pathlib import Path

scope_path = Path(sys.argv[1])
tmp_path = Path(sys.argv[2])
close_summary = sys.argv[3]

lines = scope_path.read_text(encoding="utf-8").splitlines()
if not lines or lines[0].strip() != "---":
    raise SystemExit(2)

end_idx = None
for idx in range(1, len(lines)):
    if lines[idx].strip() == "---":
        end_idx = idx
        break
if end_idx is None:
    raise SystemExit(2)

frontmatter = lines[1:end_idx]
rest = lines[end_idx + 1 :]
indices = {}
for idx, line in enumerate(frontmatter):
    if ":" not in line:
        continue
    key = line.split(":", 1)[0].strip()
    if key and key not in indices:
        indices[key] = idx

escaped = close_summary.replace("\\", "\\\\").replace('"', '\\"')
line = f'close_summary: "{escaped}"'
if "close_summary" in indices:
    frontmatter[indices["close_summary"]] = line
else:
    frontmatter.append(line)

tmp_path.write_text("\n".join(["---", *frontmatter, "---", *rest]) + "\n", encoding="utf-8")
PY
        then
            echo "ERROR: Failed to write close_summary into $scope_file" >&2
            exit 1
        fi
        mv "$tmp_file" "$scope_file"
    fi

    trap - EXIT INT TERM
    release_git_lock

    echo "CLOSED: $loop_id disposition=$disposition (projected $scope_file)"
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
planned_count = 0
closed_count = 0
total = 0
severity_counts = Counter()
owner_counts = Counter()
background_open = []

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
    if status not in ("active", "draft", "open", "closed", "planned"):
        continue

    total += 1
    severity = fm.get("severity", "unknown")
    owner = fm.get("owner", "unassigned")

    if status in ("active", "draft", "open"):
        open_count += 1
        severity_counts[severity] += 1
        owner_counts[owner] += 1
        if fm.get("execution_mode", "") == "background":
            background_open.append(fm.get("loop_id", f.stem))
    elif status == "planned":
        planned_count += 1
    elif status == "closed":
        closed_count += 1

print("By Status:")
print(f"  Open:    {open_count}")
print(f"  Planned: {planned_count}")
print(f"  Closed:  {closed_count}")
print(f"  Total:   {total}")
print(f"  Background Open: {len(background_open)}")
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
if background_open:
    print()
    print("Background Loops (open):")
    for loop_id in background_open:
        print(f"  {loop_id}")
PY
}

# ── Collect (deprecated — no-op) ──────────────────────────────────────────
collect_loops() {
    echo "=== ops loops collect — DEPRECATED ==="
    echo ""
    echo "Loop state moved from open_loops.jsonl to scope files."
    echo "Canonical tracking: $SCOPES_DIR/*.scope.md"
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
        shift
        close_loop "$@"
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
