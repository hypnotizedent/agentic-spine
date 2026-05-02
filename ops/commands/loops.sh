#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops loops - Advanced loop surgery (expert/internal only)
# ═══════════════════════════════════════════════════════════════════════════
#
# This is an expert/internal surface. The canonical operator path is:
#   ops status                          Unified work status (front door)
#   ops cap run orchestration.loop.close  Governed loop closeout
#
# Use this only for raw SQLite loop inspection, scope-file drilldown,
# or manual closeout surgery when the governed path cannot complete.
# SQLite (loops_sql_authority) is the sole authority for loop state; scope files
# are projections for display only, never read as authority input.
# See: LOOP-MAILROOM-CONSOLIDATION-20260210 for the migration rationale.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SPINE_REPO/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths

STATE_DIR="$SPINE_STATE"
SCOPES_DIR="$STATE_DIR/loop-scopes"
SCOPES_ARCHIVE_DIR="$STATE_DIR/archive/closed-loop-scopes"
source "$SPINE_REPO/ops/lib/git-lock.sh"

RECEIPTS_DIR="$SPINE_RECEIPTS"
LEDGER="$STATE_DIR/ledger.csv"
DISPOSITION_CONTRACT="$SPINE_REPO/ops/bindings/closeout.disposition.contract.yaml"

usage() {
    cat <<'EOF'
ops loops - Advanced loop surgery (expert/internal only)

  Normal operator path: ops status
  Governed closeout:    ops cap run orchestration.loop.close
  Use this only for raw inspection or manual surgery.

Usage:
  ops loops list [--open|--closed|--all]   List loops from SQLite authority (default: open only)
  ops loops close <loop_id> --disposition <state> [--completion-level <level>] [--close-summary "<text>"]
                                           Mark loop as closed
  ops loops show <loop_id>                  Show loop scope file (projection)
  ops loops summary                         Show loop counts by status/severity

Truth sources:
  authority:   SQLite via loops_sql_authority (sole source)
  projection:  .runtime/spine/state/loop-scopes/*.scope.md (display only, never authority input)
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

_completion_levels_csv() {
    local csv=""
    local accum=""
    local level=""

    if command -v yq >/dev/null 2>&1 && [[ -f "$DISPOSITION_CONTRACT" ]]; then
        while IFS= read -r level; do
            [[ -n "$level" && "$level" != "null" ]] || continue
            if [[ -n "$accum" ]]; then
                accum+=",$level"
            else
                accum="$level"
            fi
        done < <(yq e -r '.completion_levels.allowed[]?' "$DISPOSITION_CONTRACT" 2>/dev/null || true)
    fi

    printf '%s\n' "$accum"
}

_require_completion_level_if_needed() {
    local disposition="${1:-}"
    local completion_level="${2:-}"
    local allowed_csv="${3:-$(_completion_levels_csv)}"
    local require_on_landed="false"
    local message="disposition: landed requires completion_level."
    local item=""

    if command -v yq >/dev/null 2>&1 && [[ -f "$DISPOSITION_CONTRACT" ]]; then
        require_on_landed="$(yq e -r '.completion_levels.enforcement.require_on_landed // false' "$DISPOSITION_CONTRACT" 2>/dev/null || echo false)"
        message="$(yq e -r '.completion_levels.enforcement.message // ""' "$DISPOSITION_CONTRACT" 2>/dev/null || echo "$message")"
        [[ -n "$message" && "$message" != "null" ]] || message="disposition: landed requires completion_level."
    fi

    if [[ "$disposition" == "landed" && "$require_on_landed" == "true" && -z "$completion_level" ]]; then
        echo "ERROR: $message" >&2
        exit 1
    fi

    if [[ -n "$completion_level" && -n "$allowed_csv" ]]; then
        IFS=',' read -r -a _allowed_levels <<< "$allowed_csv"
        for item in "${_allowed_levels[@]}"; do
            [[ "$completion_level" == "$item" ]] && return 0
        done
        echo "ERROR: completion_level must be one of: ${allowed_csv//,/|}." >&2
        exit 1
    fi
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
# planned and blocked are live but not "open" for WIP purposes.
_is_open_status() {
    case "$1" in
        active|draft|open|planned|blocked) return 0 ;;
        *) return 1 ;;
    esac
}

_is_closed_status() {
    case "$1" in
        closed|completed|deferred|superseded|abandoned|landed) return 0 ;;
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

# Return the canonical loop status from SQLite authority when available.
# Falls back to an empty string if the authority bridge is missing or unreadable.
_loop_authority_status() {
    local loop_id="$1"
    local LOOPS_BRIDGE="$SPINE_REPO/ops/plugins/core/lifecycle/bin/loops-authority-bridge"
    local row_json=""

    [[ -x "$LOOPS_BRIDGE" ]] || {
        echo ""
        return 0
    }

    row_json="$(python3 "$LOOPS_BRIDGE" query --id "$loop_id" 2>/dev/null || true)"
    [[ -n "$row_json" ]] || {
        echo ""
        return 0
    }

    python3 - "$row_json" <<'PY'
import json
import sys

try:
    payload = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(0)

status = str(payload.get("status", "")).strip().lower()
if status:
    print(status)
PY
}

# ── List loops ────────────────────────────────────────────────────────────
list_loops() {
    local filter="${1:---open}"
    local label="OPEN LOOPS"
    [[ "$filter" == "--closed" ]] && label="CLOSED LOOPS"
    [[ "$filter" == "--all" ]] && label="ALL LOOPS"

    if [[ "$filter" == "--open" && -t 1 ]]; then
        echo "DEPRECATED: operator-facing open-work view is 'ops status'; 'ops loops list --open' is raw loop-scope output." >&2
    fi

    echo "=== $label ==="
    echo ""

    python3 - "$SPINE_REPO" "$SCOPES_DIR" "$SCOPES_ARCHIVE_DIR" "$filter" <<'PY'
import re
import sys
from pathlib import Path

spine_repo = Path(sys.argv[1])
scopes_dir = Path(sys.argv[2])
archive_dir = Path(sys.argv[3])
filter_mode = sys.argv[4]

live_statuses = {"active", "draft", "open", "planned"}
closed_statuses = {"closed", "completed", "deferred", "superseded", "abandoned", "landed"}
valid_statuses = live_statuses | closed_statuses
# For --open filter: active, draft, open (NOT planned — planned is deferred intent)
open_filter_statuses = {"active", "draft", "open"}


def _entries_from_sqlite():
    """Read loop data from SQLite authority. Returns list of entry dicts or None on failure.

    PACKET-586: When db_authority.enabled=true and the local host is not
    the authority host, the lib guard raises DbAuthorityRoutingRequired.
    That is NOT a failure — it's the routing seal firing correctly. Return
    a sentinel "routed" value so the caller can print a routing pointer
    instead of a misleading "authority unavailable" error.
    """
    lib_path = spine_repo / "ops" / "plugins" / "core" / "lifecycle" / "lib"
    sys.path.insert(0, str(lib_path))
    try:
        import loops_sql_authority as lsa

        db_path, _ = lsa.resolve_paths(spine_repo)
        conn = lsa.connect(db_path)
        lsa.ensure_schema(conn)
        all_loops = lsa.list_loops(conn)
        conn.close()
    except Exception as exc:
        if type(exc).__name__ == "DbAuthorityRoutingRequired":
            return "routed"
        return None

    entries = []
    for loop in all_loops:
        loop_id = str(loop.get("loop_id", "")).strip()
        status = str(loop.get("status", "")).strip().lower()
        if not loop_id or status not in valid_statuses:
            continue

        if filter_mode == "--open" and status not in open_filter_statuses:
            continue
        if filter_mode == "--closed" and status not in closed_statuses:
            continue

        # blocked_by may be a list from SQLite
        blocked_by_raw = loop.get("blocked_by") or ""
        if isinstance(blocked_by_raw, list):
            blocked_by_raw = ", ".join(str(b) for b in blocked_by_raw if b)

        entries.append(
            {
                "loop_id": loop_id,
                "status": status,
                "severity": str(loop.get("priority") or "-").strip() or "-",
                "owner": str(loop.get("owner") or "unassigned").strip() or "unassigned",
                "title": str(loop.get("objective") or loop_id).strip() or loop_id,
                "execution_mode": str(loop.get("execution_mode") or "").strip(),
                "active_terminal": str(loop.get("active_terminal") or "").strip(),
                "blocked_by": blocked_by_raw,
                "horizon": str(loop.get("horizon") or "").strip(),
                "execution_readiness": str(loop.get("execution_readiness") or "").strip(),
            }
        )
    return entries


def _entries_from_scope_files():
    """Fallback: read loop data from .scope.md files."""
    fm_re = re.compile(r"^---\s*$")

    def parse_scope(path):
        lines = path.read_text(encoding="utf-8").splitlines()
        fm = {}
        in_fm = False
        for line in lines:
            if fm_re.match(line):
                if in_fm:
                    break
                in_fm = True
                continue
            if in_fm and ":" in line:
                key, _, val = line.partition(":")
                fm[key.strip()] = val.strip().strip('"')
        fm_count = 0
        for line in lines:
            if fm_re.match(line):
                fm_count += 1
                continue
            if fm_count >= 2 and line.startswith("#"):
                fm["_title"] = re.sub(r"^Loop Scope:\s*", "", re.sub(r"^#+\s*", "", line))
                break
        return fm

    if not scopes_dir.is_dir() and not archive_dir.is_dir():
        return []

    roots = [scopes_dir]
    if filter_mode != "--open":
        roots.append(archive_dir)

    entries = []
    seen = set()
    for root in roots:
        if not root.is_dir():
            continue
        for path in sorted(root.glob("*.scope.md")):
            fm = parse_scope(path)
            loop_id = (fm.get("loop_id") or path.stem).strip()
            status = (fm.get("status") or "").strip().lower()
            if not loop_id or status not in valid_statuses or loop_id in seen:
                continue
            seen.add(loop_id)

            if filter_mode == "--open" and status not in open_filter_statuses:
                continue
            if filter_mode == "--closed" and status not in closed_statuses:
                continue

            entries.append(
                {
                    "loop_id": loop_id,
                    "status": status,
                    "severity": (fm.get("severity") or "-").strip() or "-",
                    "owner": (fm.get("owner") or "unassigned").strip() or "unassigned",
                    "title": (fm.get("_title") or path.stem).strip() or path.stem,
                    "execution_mode": (fm.get("execution_mode") or "").strip(),
                    "active_terminal": (fm.get("active_terminal") or "").strip(),
                    "blocked_by": (fm.get("blocked_by") or "").strip(),
                    "horizon": (fm.get("horizon") or "").strip(),
                    "execution_readiness": (fm.get("execution_readiness") or "").strip(),
                }
            )
    return entries


# SQLite is sole loop authority — no scope-file fallback
entries = _entries_from_sqlite()
if entries == "routed":
    # PACKET-586: routed-elsewhere is the correct seal, not a failure.
    print("LOOP AUTHORITY ROUTED: db_authority.enabled=true; canonical DB on authority host (pve).", file=sys.stderr)
    print("Use 'bin/ops cap run loops.status' for routed read.", file=sys.stderr)
    raise SystemExit(0)
if entries is None:
    print("ERROR: SQLite loop authority unavailable — cannot list loops", file=sys.stderr)
    raise SystemExit(1)

if not entries:
    print("(no loops)")
    print()
    if filter_mode == "--open":
        print("Open loops: 0")
    else:
        print("Loops shown: 0")
    raise SystemExit(0)

for entry in entries:
    state_tags = ""
    if entry["execution_mode"] == "background":
        state_tags += " [background]"
    if entry["blocked_by"] and entry["blocked_by"] != "none":
        state_tags += " [blocked]"
    if entry["horizon"] and entry["horizon"] != "now":
        state_tags += f" [{entry['horizon']}]"
    if entry["execution_readiness"] == "blocked":
        state_tags += " [not-runnable]"
    display_title = entry["title"] if entry["title"] != entry["loop_id"] else ""

    if filter_mode == "--open":
        print(f"  [{entry['severity']:<8}] {entry['owner']:<15} {entry['loop_id']}{state_tags}", end="")
        if display_title:
            print(f"  {display_title}", end="")
        print()
        detail = ""
        if entry["execution_mode"] == "background":
            detail = "execution=background"
            if entry["active_terminal"]:
                detail = f"{detail}; terminal={entry['active_terminal']}"
        if entry["blocked_by"] and entry["blocked_by"] != "none":
            detail = f"{detail}; blocked_by={entry['blocked_by']}" if detail else f"blocked_by={entry['blocked_by']}"
        if detail:
            print(f"  {'':<10} {'':<15} {detail}")
    elif filter_mode == "--closed":
        print(f"  [{entry['severity']:<8}] {entry['owner']:<15} {entry['loop_id']}{state_tags}", end="")
        if display_title:
            print(f"  {display_title}", end="")
        print()
    else:
        print(f"  [{entry['severity']:<8}] {entry['status']:<8} {entry['owner']:<15} {entry['loop_id']}{state_tags}", end="")
        if display_title:
            print(f"  {display_title}", end="")
        print()

print()
if filter_mode == "--open":
    print(f"Open loops: {len(entries)}")
else:
    print(f"Loops shown: {len(entries)}")
PY
}

# ── Show loop ─────────────────────────────────────────────────────────────
show_loop() {
    local loop_id="$1"
    local scope_file="$SCOPES_DIR/${loop_id}.scope.md"
    local archived_scope_file="$SCOPES_ARCHIVE_DIR/${loop_id}.scope.md"

    if [[ ! -f "$scope_file" && -f "$archived_scope_file" ]]; then
        scope_file="$archived_scope_file"
    fi

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
    local completion_level=""
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
            --completion-level)
                completion_level="${2:-}"
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

    [[ -n "$loop_id" ]] || { echo "Usage: ops loops close <loop_id> --disposition <state> [--completion-level <level>] [--close-summary \"<text>\"]" >&2; exit 1; }
    dispositions_csv="$(_close_dispositions_csv)"
    _require_close_disposition "$disposition" "$dispositions_csv"
    _require_completion_level_if_needed "$disposition" "$completion_level"

    scope_file="$SCOPES_DIR/${loop_id}.scope.md"
    local archived_scope_file="$SCOPES_ARCHIVE_DIR/${loop_id}.scope.md"

    if [[ ! -f "$scope_file" && -f "$archived_scope_file" ]]; then
        scope_file="$archived_scope_file"
    fi

    if [[ ! -f "$scope_file" ]]; then
        echo "ERROR: Scope file not found: $scope_file" >&2
        exit 1
    fi

    local current_status
    current_status="$(_loop_authority_status "$loop_id")"
    if [[ -z "$current_status" ]]; then
        # SQLite is authority — if bridge is available but returns empty,
        # fail closed.  Do not fall back to scope file; that would let a
        # missing SQLite row resurrect a closed loop from stale file truth.
        local LOOPS_BRIDGE_CHECK="$SPINE_REPO/ops/plugins/core/lifecycle/bin/loops-authority-bridge"
        if [[ -x "$LOOPS_BRIDGE_CHECK" ]]; then
            echo "ERROR: SQLite authority returned empty for $loop_id — bridge available but no row found. Register the loop first." >&2
            exit 1
        fi
        # Bridge binary absent — fall back to scope file (historical/archive path only)
        current_status="$(_fm_field "$scope_file" "status")"
    fi
    if _is_closed_status "$current_status"; then
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
    if [[ -n "$completion_level" ]]; then
        bridge_close_args+=("--completion-level" "$completion_level")
    fi
    if [[ -z "${SPINE_CAP_RUN_KEY:-}" ]]; then
        bridge_close_args+=("--ungoverned-override")
    fi

    if ! python3 "$LOOPS_BRIDGE" "${bridge_close_args[@]}" >/dev/null; then
        echo "ERROR: loops-authority-bridge failed to close $loop_id" >&2
        exit 1
    fi

    if [[ ! -f "$scope_file" && -f "$archived_scope_file" ]]; then
        scope_file="$archived_scope_file"
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

    # Python for reliable counting (associative arrays need bash 4+, macOS ships bash 3)
    python3 - "$SPINE_REPO" "$SCOPES_DIR" "$SCOPES_ARCHIVE_DIR" <<'PY'
import re
import sys
from collections import Counter
from pathlib import Path

spine_repo = Path(sys.argv[1])
scopes_dir = Path(sys.argv[2])
archive_dir = Path(sys.argv[3])

closed_statuses = {"closed", "completed", "deferred", "superseded", "abandoned", "landed"}
open_statuses = {"active", "draft", "open"}
all_live = {"active", "draft", "open", "planned"}
all_valid = all_live | closed_statuses


def _loops_from_sqlite():
    """Return list of loop dicts from SQLite, or None on failure."""
    lib_path = spine_repo / "ops" / "plugins" / "core" / "lifecycle" / "lib"
    sys.path.insert(0, str(lib_path))
    try:
        import loops_sql_authority as lsa

        db_path, _ = lsa.resolve_paths(spine_repo)
        conn = lsa.connect(db_path)
        lsa.ensure_schema(conn)
        loops = lsa.list_loops(conn)
        conn.close()
        return loops
    except Exception:
        return None


def _loops_from_scope_files():
    """Fallback: read from scope files."""
    FM_RE = re.compile(r'^---\s*$')
    loops = []
    seen = set()
    for root in (scopes_dir, archive_dir):
        if not root.is_dir():
            continue
        is_archive = root == archive_dir
        for f in sorted(root.glob("*.scope.md")):
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
            loop_id = fm.get("loop_id", f.stem)
            if status not in all_valid or loop_id in seen:
                continue
            seen.add(loop_id)
            # Archived files with live status are treated as closed
            if is_archive and status in all_live:
                fm["status"] = "closed"
            loops.append(fm)
    return loops


# SQLite is sole loop authority — no scope-file fallback
all_loops = _loops_from_sqlite()
if all_loops is None:
    print("ERROR: SQLite loop authority unavailable — cannot show summary", file=sys.stderr)
    raise SystemExit(1)

open_count = 0
planned_count = 0
closed_count = 0
total = 0
severity_counts = Counter()
owner_counts = Counter()
background_open = []

for loop in all_loops:
    status = str(loop.get("status", "")).strip().lower()
    if status not in all_valid:
        continue
    loop_id = str(loop.get("loop_id", "")).strip()
    total += 1
    severity = str(loop.get("priority") or loop.get("severity") or "unknown").strip() or "unknown"
    owner = str(loop.get("owner") or "unassigned").strip() or "unassigned"

    if status in open_statuses:
        open_count += 1
        severity_counts[severity] += 1
        owner_counts[owner] += 1
        exec_mode = str(loop.get("execution_mode") or "").strip()
        if exec_mode == "background":
            background_open.append(loop_id)
    elif status == "planned":
        planned_count += 1
    else:
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

# ── Main ──────────────────────────────────────────────────────────────────
case "${1:-}" in
    list)
        list_loops "${2:---open}"
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
