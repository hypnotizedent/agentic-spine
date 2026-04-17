#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops status - Unified work tracker for the agentic spine
# ═══════════════════════════════════════════════════════════════════════════
#
# Shows current spine work first, with inbox/comms side surfaces rendered
# separately so historical residue does not read as controller todo.
# This is the canonical agent entry point — replaces `ops loops list --open`.
#
# Usage:
#   ops status              Full status view
#   ops status --json       Machine-readable JSON output
#   ops status --brief      Counts only (for hooks/banners)
#   ops status --strict     Exit nonzero when anomalies exist
#
# See: LOOP-MAILROOM-CONSOLIDATION-20260210
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SPINE_REPO/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths

usage() {
  cat <<'EOF'
ops status

Canonical cold-start read surface for current spine work.

Usage:
  ops status [--brief|--json|--context|--control-loop] [--strict]

Flags:
  --brief        Counts-only output for hooks/banners
  --json         Machine-readable output
  --context      L1 visibility view (terminal identity, runtime paths, coherence)
  --control-loop Bounded local-only probe for agent control-loop polling
  --strict       Exit nonzero when anomalies exist
  -h, --help     Show this help

Default behavior:
  Human-facing output succeeds even when anomalies exist.
  Use --strict when you explicitly want anomaly-sensitive exit codes.
EOF
}

MODE=""
STRICT="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --brief|--json|--context|--control-loop)
      MODE="$1"
      shift
      ;;
    --strict)
      STRICT="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ops status: unknown argument '$1'" >&2
      echo >&2
      usage >&2
      exit 2
      ;;
  esac
done

# ── Control-loop mode (bounded local probe) ──────────────────────────────
# Distinct from --json (full status), --brief (counts), --context (L1 view),
# and per-wave cmd_status in wave.sh. Local-only, bounded, sub-second.
# Contract: ops/plugins/core/lifecycle/lib/control_loop_status.py
if [[ "$MODE" == "--control-loop" ]]; then
  exec python3 - "$SPINE_REPO" "${SPINE_RUNTIME_ROOT:-}" "${SPINE_STATE:-}" <<'PYTHON'
import json
import os
import sys

spine_repo = sys.argv[1]
runtime_root = sys.argv[2]
state_root = sys.argv[3]

lib_dir = os.path.join(spine_repo, "ops", "plugins", "core", "lifecycle", "lib")
if lib_dir not in sys.path:
    sys.path.insert(0, lib_dir)

from control_loop_status import collect_control_loop_status

result = collect_control_loop_status(runtime_root, state_root)
print(json.dumps(result, separators=(",", ":"), sort_keys=True))
sys.exit(0)
PYTHON
fi

# ── Context mode (L1 visibility surface) ─────────────────────────────────
# Replaces the former standalone `ops context` command.
if [[ "$MODE" == "--context" ]]; then
  JOINED_STATE_BIN="$SPINE_REPO/ops/plugins/core/lifecycle/bin/spine-engine-joined-state"

  TERMINAL_ROLE="${OPS_TERMINAL_ROLE:-<none>}"
  RUNTIME_ROLE="${SPINE_RUNTIME_ROLE:-<none>}"
  LOOP_ID="${SPINE_LOOP_ID:-<none>}"
  SESSION_LOOP_DISPLAY="$LOOP_ID"

  JOINED_JSON=""
  JOINED_ERR=""
  if [[ -x "$JOINED_STATE_BIN" ]] || [[ -f "$JOINED_STATE_BIN" ]]; then
    JOINED_JSON="$(python3 "$JOINED_STATE_BIN" --json --no-write 2>/dev/null)" || {
      JOINED_ERR="joined-state failed (exit $?)"
      JOINED_JSON=""
    }
  else
    JOINED_ERR="joined-state binary not found"
  fi

  jq_val() {
    local expr="$1"
    local default="${2:-}"
    if [[ -n "$JOINED_JSON" ]] && command -v jq >/dev/null 2>&1; then
      local val
      val="$(printf '%s' "$JOINED_JSON" | jq -r "if $expr == null then \"__null__\" else ($expr | tostring) end" 2>/dev/null || true)"
      if [[ -n "$val" && "$val" != "__null__" ]]; then
        printf '%s' "$val"
        return
      fi
    fi
    printf '%s' "$default"
  }

  STATE_ROOT_VAL="$(jq_val '.paths.state_root' 'unknown')"
  EVIDENCE_ROOT="$(jq_val '.paths.receipts_root' 'unknown')"
  OPEN_LOOPS="$(jq_val '.summary.open_loops' '?')"
  OPEN_GAPS="$(jq_val '.summary.open_gaps' '?')"
  ACTIVE_WAVES="$(jq_val '.summary.active_waves' '?')"
  ORPHANED_WAVES="$(jq_val '.summary.orphaned_waves' '?')"
  VERIFY_STATUS="$(jq_val '.summary.latest_verify_status' 'unknown')"
  VERIFY_SCOPE="$(jq_val '.summary.latest_verify_scope' '')"
  GAP_AUTHORITY="$(jq_val '.summary.gap_authority_status' 'unknown')"
  GAP_MATCH="$(jq_val '.summary.gap_projection_match' 'null')"
  COHERENCE="$(jq_val '.summary.engine_coherence_needs_attention' 'unknown')"
  FORCE_CLOSES="$(jq_val '.summary.recent_force_closes' '?')"
  DOD_OVERRIDES="$(jq_val '.summary.recent_dod_overrides' '?')"
  HISTORICAL_OVERRIDE_ONLY="$(jq_val '.engine_coherence.historical_override_only' 'false')"

  WARNINGS=""
  HISTORY_NOTE=""
  if [[ -n "$JOINED_ERR" ]]; then
    WARNINGS="$JOINED_ERR"
  elif [[ "$COHERENCE" == "true" ]]; then
    W_PARTS=()
    [[ "$ACTIVE_WAVES" == "0" || "$ACTIVE_WAVES" == "?" ]] || W_PARTS+=("${ACTIVE_WAVES} active waves")
    [[ "$ORPHANED_WAVES" == "0" || "$ORPHANED_WAVES" == "?" ]] || W_PARTS+=("${ORPHANED_WAVES} orphaned waves")
    [[ "$GAP_MATCH" == "true" || "$GAP_MATCH" == "unknown" || "$GAP_MATCH" == "null" ]] || W_PARTS+=("gap projection mismatch")
    [[ "$FORCE_CLOSES" == "0" || "$FORCE_CLOSES" == "?" ]] || W_PARTS+=("${FORCE_CLOSES} recent force-closes")
    [[ "$DOD_OVERRIDES" == "0" || "$DOD_OVERRIDES" == "?" ]] || W_PARTS+=("${DOD_OVERRIDES} recent DoD overrides")
    if [[ ${#W_PARTS[@]} -gt 0 ]]; then
      WARNINGS="$(printf '%s' "${W_PARTS[0]}"; for w in "${W_PARTS[@]:1}"; do printf ', %s' "$w"; done)"
    else
      WARNINGS="engine coherence needs attention"
    fi
  elif [[ "$HISTORICAL_OVERRIDE_ONLY" == "true" ]]; then
    H_PARTS=()
    [[ "$FORCE_CLOSES" == "0" || "$FORCE_CLOSES" == "?" ]] || H_PARTS+=("${FORCE_CLOSES} recent force-closes")
    [[ "$DOD_OVERRIDES" == "0" || "$DOD_OVERRIDES" == "?" ]] || H_PARTS+=("${DOD_OVERRIDES} recent DoD overrides")
    if [[ ${#H_PARTS[@]} -gt 0 ]]; then
      HISTORY_NOTE="$(printf '%s' "${H_PARTS[0]}"; for h in "${H_PARTS[@]:1}"; do printf ', %s' "$h"; done)"
    fi
  fi

  if [[ -n "$JOINED_JSON" && "$LOOP_ID" != "<none>" ]]; then
    _session_loop_suffix="$(
      SESSION_LOOP_ID="$LOOP_ID" JOINED_JSON_INPUT="$JOINED_JSON" python3 - <<'PY' 2>/dev/null || true
import json
import os

session_loop_id = (os.environ.get("SESSION_LOOP_ID") or "").strip()
if not session_loop_id:
    raise SystemExit(0)

try:
    data = json.loads(os.environ.get("JOINED_JSON_INPUT") or "")
except Exception:
    raise SystemExit(0)

open_rows = ((data.get("loops") or {}).get("open")) or []
open_loop_ids = {
    str(row.get("loop_id") or "").strip()
    for row in open_rows
    if isinstance(row, dict) and str(row.get("loop_id") or "").strip()
}

if open_loop_ids and session_loop_id not in open_loop_ids:
    print(" (historical env; not in current open loops)")
PY
    )"
    if [[ -n "$_session_loop_suffix" ]]; then
      SESSION_LOOP_DISPLAY="${LOOP_ID}${_session_loop_suffix}"
    fi
  fi

  echo "─── spine context ───────────────────────────────────"
  printf "  terminal:       %s\n" "$TERMINAL_ROLE"
  printf "  runtime role:   %s\n" "$RUNTIME_ROLE"
  printf "  session loop:   %s\n" "$SESSION_LOOP_DISPLAY"
  printf "  state root:     %s\n" "$STATE_ROOT_VAL"
  printf "  evidence root:  %s\n" "$EVIDENCE_ROOT"
  echo "─── open work ──────────────────────────────────────"
  printf "  open loops:     %s\n" "$OPEN_LOOPS"
  printf "  open gaps:      %s\n" "$OPEN_GAPS"
  printf "  active waves:   %s\n" "$ACTIVE_WAVES"
  printf "  orphaned waves: %s\n" "$ORPHANED_WAVES"
  echo "─── verify / coherence ─────────────────────────────"
  printf "  spine verify:   %s\n" "$VERIFY_STATUS"
  printf "  gap authority:  %s\n" "$GAP_AUTHORITY"
  _gap_parity=""
  case "$GAP_MATCH" in
    true)  _gap_parity="match" ;;
    false) _gap_parity="MISMATCH" ;;
    null)  _gap_parity="n/a (db only)" ;;
    *)     _gap_parity="unknown" ;;
  esac
  printf "  gap parity:     %s\n" "$_gap_parity"
  printf "  coherence:      %s\n" "$([ "$COHERENCE" == "true" ] && echo "NEEDS ATTENTION" || echo "ok")"
  if [[ -n "$WARNINGS" ]]; then
    echo "─── warning ────────────────────────────────────────"
    printf "  %s\n" "$WARNINGS"
  elif [[ -n "$HISTORY_NOTE" ]]; then
    echo "─── history ────────────────────────────────────────"
    printf "  %s\n" "$HISTORY_NOTE"
  fi
  echo "─────────────────────────────────────────────────────"
  exit 0
fi

exec python3 - "$SPINE_REPO" "$MODE" "$STRICT" "$SPINE_STATE" "$SPINE_INBOX" "$SPINE_OUTBOX" <<'PYTHON'
import json
import os
import re
import sys
from datetime import datetime, timezone
from collections import Counter
from pathlib import Path

spine = Path(sys.argv[1])
mode = sys.argv[2] if len(sys.argv) > 2 else ""
strict_mode = (sys.argv[3] if len(sys.argv) > 3 else "0") == "1"
state_root = Path(sys.argv[4])
inbox_dir = Path(sys.argv[5])
outbox_dir = Path(sys.argv[6])

shared_db_path = state_root / "shared_authority.db"
loop_heartbeat_dir = state_root / "loop-heartbeats"
gaps_lib_dir = spine / "ops" / "plugins" / "core" / "lifecycle" / "lib"

if str(gaps_lib_dir) not in sys.path:
    sys.path.insert(0, str(gaps_lib_dir))

gaps_authority = None
gaps_authority_import_error = None
try:
    import gaps_sql_authority as gaps_authority
except Exception as exc:  # pragma: no cover - exercised via degraded status surface
    gaps_authority_import_error = exc

loops_authority = None
loops_authority_import_error = None
try:
    import loops_sql_authority as loops_authority
except Exception as exc:  # pragma: no cover - exercised via degraded status surface
    loops_authority_import_error = exc

def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(spine))
    except ValueError:
        return str(path)

# ── Collect loops from SQLite authority ───────────────────────────────────

open_loops = []
closed_loops = []
planned_loops = []
all_scopes = []
anomalies = []

if loops_authority is not None:
    _prior_spine_state = os.environ.get("SPINE_STATE")
    _loops_conn = None
    try:
        os.environ["SPINE_STATE"] = str(state_root)
        _db_path, _ = loops_authority.resolve_paths(spine)
        _loops_conn = loops_authority.connect(_db_path)
        loops_authority.ensure_schema(_loops_conn)
        _all_db_loops = loops_authority.list_loops(_loops_conn, status="all")
    except Exception as _exc:
        _all_db_loops = []
        anomalies.append(f"LOOP AUTHORITY DEGRADED: {_exc}")
    finally:
        if _loops_conn is not None:
            _loops_conn.close()
        if _prior_spine_state is None:
            os.environ.pop("SPINE_STATE", None)
        else:
            os.environ["SPINE_STATE"] = _prior_spine_state

    for _loop in _all_db_loops:
        _st = str(_loop.get("status") or "").lower()
        if _st not in ("active", "draft", "open", "closed", "planned",
                        "completed", "deferred", "superseded", "abandoned", "landed"):
            continue

        _blocked_raw = _loop.get("blocked_by")
        if isinstance(_blocked_raw, list):
            _blocked_text = ", ".join(str(b) for b in _blocked_raw if b)
        else:
            _blocked_text = str(_blocked_raw or "")

        entry = {
            "loop_id": str(_loop.get("loop_id") or ""),
            "status": _st,
            "severity": str(_loop.get("priority") or "-"),
            "owner": str(_loop.get("owner") or "unassigned"),
            "execution_mode": str(_loop.get("execution_mode") or ""),
            "active_terminal": "",
            "blocked_by": _blocked_text,
            "operator_note": "",
            "last_heartbeat_utc": "",
            "heartbeat_ttl_minutes": "",
            "heartbeat_source": "",
            "horizon": str(_loop.get("horizon") or "now"),
            "execution_readiness": str(_loop.get("execution_readiness") or "runnable"),
            "title": str(_loop.get("objective") or _loop.get("loop_id") or ""),
            "file": "sqlite",
        }
        all_scopes.append(entry)
        if _st == "planned":
            planned_loops.append(entry)
        elif _st in ("active", "draft", "open"):
            open_loops.append(entry)
        elif _st in ("closed", "completed", "deferred", "superseded", "abandoned", "landed"):
            closed_loops.append(entry)
else:
    anomalies.append(f"LOOP AUTHORITY DEGRADED: loops_sql_authority import failed: {loops_authority_import_error or 'unknown'}")

# ── Overlay runtime loop heartbeat state ──────────────────────────────────

def parse_kv_yaml(path):
    data = {}
    try:
        for raw in path.read_text().splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or ":" not in line:
                continue
            key, val = line.split(":", 1)
            data[key.strip()] = val.strip().strip('"').strip("'")
    except OSError:
        return {}
    return data

def parse_iso_utc(value):
    if not value:
        return None
    normalized = value.strip()
    if normalized.endswith("Z"):
        normalized = normalized[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(normalized)
    except ValueError:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)

for loop in open_loops:
    loop_id = loop.get("loop_id", "")
    if not loop_id:
        continue
    safe_loop_id = re.sub(r"[^A-Za-z0-9._-]", "_", loop_id)
    hb_file = loop_heartbeat_dir / f"{safe_loop_id}.yaml"
    if not hb_file.exists():
        continue
    hb = parse_kv_yaml(hb_file)
    if hb.get("last_heartbeat_utc"):
        loop["last_heartbeat_utc"] = hb["last_heartbeat_utc"]
        loop["heartbeat_source"] = "runtime"
    if hb.get("heartbeat_ttl_minutes"):
        loop["heartbeat_ttl_minutes"] = hb["heartbeat_ttl_minutes"]
        loop["heartbeat_source"] = "runtime"
    if hb.get("terminal_id"):
        loop["active_terminal"] = hb["terminal_id"]

# ── Parse gaps via shared authority ───────────────────────────────────────

def normalize_gap_entry(gap):
    parent_loop = str(gap.get("parent_loop") or "").strip()
    return {
        "id": str(gap.get("id") or "?"),
        "severity": str(gap.get("severity") or "?"),
        "parent_loop": parent_loop,
        "description": str(gap.get("description") or "").strip(),
    }


def collect_gap_state():
    state = {
        "status": "degraded",
        "source": "sqlite",
        "message": "",
        "db_path": "",
        "open_gaps": [],
        "linked_gaps": [],
        "unlinked_gaps": [],
    }

    if gaps_authority is None:
        state["message"] = f"shared gaps authority import failed: {gaps_authority_import_error or 'unknown error'}"
        return state

    prior_spine_state = os.environ.get("SPINE_STATE")
    conn = None
    try:
        os.environ["SPINE_STATE"] = str(state_root)
        db_path = shared_db_path
        state["db_path"] = str(db_path)

        conn = gaps_authority.connect(db_path)
        gaps_authority.ensure_schema(conn)
        gap_rows = gaps_authority.fetch_gaps(conn, status="open")
    except Exception as exc:
        state["message"] = str(exc)
        return state
    finally:
        if conn is not None:
            conn.close()
        if prior_spine_state is None:
            os.environ.pop("SPINE_STATE", None)
        else:
            os.environ["SPINE_STATE"] = prior_spine_state

    linked = []
    unlinked = []
    for gap in gap_rows:
        entry = normalize_gap_entry(gap)
        if entry["parent_loop"] and entry["parent_loop"] != "null":
            linked.append(entry)
        else:
            unlinked.append(entry)

    state["status"] = "ok"
    state["message"] = ""
    state["linked_gaps"] = linked
    state["unlinked_gaps"] = unlinked
    state["open_gaps"] = linked + unlinked
    return state


gap_state = collect_gap_state()
gaps_available = gap_state.get("status") == "ok"
open_gaps = gap_state.get("open_gaps", []) if gaps_available else []
linked_gaps = gap_state.get("linked_gaps", []) if gaps_available else []
unlinked_gaps = gap_state.get("unlinked_gaps", []) if gaps_available else []
open_gap_count = len(open_gaps) if gaps_available else None
linked_gap_count = len(linked_gaps) if gaps_available else None
unlinked_gap_count = len(unlinked_gaps) if gaps_available else None

# ── Parse inbox lanes ─────────────────────────────────────────────────────

def count_lane_files(base_dir):
    """Count .md files per lane subdirectory, excluding .keep files."""
    lanes = {}
    if base_dir.is_dir():
        for lane_dir in sorted(base_dir.iterdir()):
            if lane_dir.is_dir() and not lane_dir.name.startswith('.'):
                files = [f for f in lane_dir.glob("*.md") if f.name != ".keep"]
                if files:
                    lanes[lane_dir.name] = len(files)
    return lanes

inbox_lanes = count_lane_files(inbox_dir)
inbox_active = inbox_lanes.get("queued", 0) + inbox_lanes.get("running", 0)
inbox_total = sum(inbox_lanes.values())
inbox_failed = inbox_lanes.get("failed", 0)
inbox_actionable = inbox_active + inbox_failed
inbox_history_total = max(0, inbox_total - inbox_actionable)

proposal_counts = Counter()
proposal_total = 0

# ── Communications queue health ──────────────────────────────────────────
import subprocess as _sp

comms_status_bin = spine / "ops" / "plugins" / "domains" / "communications" / "bin" / "communications-alerts-runtime-status"
comms_oneliner = ""
comms_slo_status = "unknown"
comms_pending = 0
comms_oldest = 0
comms_escalations = 0
comms_delivery_recent = 0
comms_delivery_recent_failed = 0
comms_sent_total = 0
comms_drain_state = "unknown"

if comms_status_bin.exists() and os.access(str(comms_status_bin), os.X_OK):
    try:
        _proc = _sp.run(
            [str(comms_status_bin), "--json"],
            capture_output=True, text=True, timeout=15,
            cwd=str(spine),
        )
        if _proc.returncode == 0 and _proc.stdout.strip():
            _cdata = json.loads(_proc.stdout)
            _cd = _cdata.get("data", {})
            comms_oneliner = _cd.get("oneliner", "")
            comms_slo_status = _cd.get("slo_status", "unknown")
            comms_pending = int(_cd.get("queue_pending_count", 0))
            comms_oldest = int(_cd.get("queue_oldest_age_seconds", 0))
            comms_escalations = int(_cd.get("pending_escalation_task_count", 0))
            comms_delivery_recent = int(_cd.get("delivery_recent_count", 0))
            comms_delivery_recent_failed = int(_cd.get("delivery_recent_failed", 0))
            comms_sent_total = int(_cd.get("queue_sent_count", 0))
    except Exception:
        pass

# Derive drain_state from existing evidence
if comms_pending > 0:
    if comms_delivery_recent > 0 and comms_delivery_recent_failed < comms_delivery_recent:
        comms_drain_state = "draining"
    elif comms_delivery_recent == 0:
        comms_drain_state = "blocked"
    elif comms_delivery_recent_failed >= comms_delivery_recent:
        comms_drain_state = "blocked"
    else:
        comms_drain_state = "unknown"
elif comms_slo_status == "ok":
    comms_drain_state = "idle"

# ── Joined-state coherence summary ───────────────────────────────────────

joined_state_summary = {
    "source": "local_fallback",
    "open_loops": len(open_loops),
    "open_gaps": open_gap_count,
    "active_waves": 0,
    "orphaned_waves": 0,
    "verify_status": "unknown",
    "coherence_attention": False,
}

joined_state_bin = spine / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "spine-engine-joined-state"
if joined_state_bin.exists() and os.access(str(joined_state_bin), os.X_OK):
    try:
        _proc = _sp.run(
            [str(joined_state_bin), "--json"],
            capture_output=True, text=True, timeout=20,
            cwd=str(spine),
        )
        if _proc.returncode == 0 and _proc.stdout.strip():
            _jdata = json.loads(_proc.stdout)
            _summary = _jdata.get("summary", {})
            if isinstance(_summary, dict):
                _aw = _summary.get("active_waves")
                _ow = _summary.get("orphaned_waves")
                _cs = _summary.get("completion_state")
                joined_state_summary = {
                    "source": "joined_state",
                    "open_loops": _summary.get("open_loops", len(open_loops)),
                    "open_gaps": _summary.get("open_gaps", open_gap_count),
                    "active_waves": int(_aw) if isinstance(_aw, (int, float)) else 0,
                    "orphaned_waves": int(_ow) if isinstance(_ow, (int, float)) else 0,
                    "verify_status": _summary.get("latest_verify_status", _summary.get("latest_fast_verify_status", "unknown")),
                    "coherence_attention": bool(_summary.get("engine_coherence_needs_attention", False)),
                    "completion_state": _cs if isinstance(_cs, dict) else None,
                }
            _joined_open_rows = ((_jdata.get("loops") or {}).get("open")) or []
            if isinstance(_joined_open_rows, list) and _joined_open_rows:
                _current_loops_by_id = {
                    str(_loop.get("loop_id") or "").strip(): dict(_loop)
                    for _loop in open_loops
                    if str(_loop.get("loop_id") or "").strip()
                }
                _merged_open_loops = []
                for _row in _joined_open_rows:
                    if not isinstance(_row, dict):
                        continue
                    _loop_id = str(_row.get("loop_id") or "").strip()
                    if not _loop_id:
                        continue
                    _merged = dict(_current_loops_by_id.get(_loop_id) or {})
                    _priority = str(_row.get("priority") or _row.get("severity") or "").strip()
                    if not _merged:
                        _merged = {
                            "loop_id": _loop_id,
                            "status": str(_row.get("status") or "active").strip().lower(),
                            "severity": _priority or "-",
                            "owner": str(_row.get("owner") or "unassigned").strip() or "unassigned",
                            "execution_mode": str(_row.get("execution_mode") or "").strip(),
                            "active_terminal": "",
                            "blocked_by": str(_row.get("blocked_by") or "").strip(),
                            "operator_note": "",
                            "last_heartbeat_utc": "",
                            "heartbeat_ttl_minutes": "",
                            "heartbeat_source": "",
                            "horizon": str(_row.get("horizon") or "now").strip() or "now",
                            "execution_readiness": str(_row.get("execution_readiness") or "runnable").strip() or "runnable",
                            "title": str(_row.get("objective") or _row.get("title") or _loop_id).strip(),
                            "file": str(_row.get("path") or "joined_state").strip() or "joined_state",
                        }
                    else:
                        if _priority:
                            _merged["severity"] = _priority
                        _owner = str(_row.get("owner") or "").strip()
                        if _owner:
                            _merged["owner"] = _owner
                        _horizon = str(_row.get("horizon") or "").strip()
                        if _horizon:
                            _merged["horizon"] = _horizon
                        _readiness = str(_row.get("execution_readiness") or "").strip()
                        if _readiness:
                            _merged["execution_readiness"] = _readiness
                        _objective = str(_row.get("objective") or _row.get("title") or "").strip()
                        if _objective:
                            _merged["title"] = _objective
                        _path = str(_row.get("path") or "").strip()
                        if _path:
                            _merged["file"] = _path
                    _merged_open_loops.append(_merged)
                if _merged_open_loops:
                    open_loops = _merged_open_loops
    except Exception:
        pass

# ── Anomaly detection ─────────────────────────────────────────────────────

# Check for unlinked gaps
if gaps_available:
    for gap in unlinked_gaps:
        anomalies.append(f"UNLINKED GAP: {gap['id']} ({gap['severity']}) has no parent_loop")
else:
    anomalies.append(f"GAP STATE DEGRADED: {gap_state.get('message') or 'shared gaps authority unavailable'}")

# Check for active inbox items (queued or running)
if inbox_active > 0:
    anomalies.append(f"INBOX: {inbox_active} active item(s) in queue — {inbox_lanes.get('queued', 0)} queued, {inbox_lanes.get('running', 0)} running")

if inbox_failed > 0:
    anomalies.append(f"INBOX: {inbox_failed} failed item(s) — investigate or archive")

# Check communications queue health
if comms_slo_status == "incident":
    anomalies.append(f"COMMS QUEUE SIDE-SURFACE INCIDENT ({comms_drain_state}): pending={comms_pending} oldest={comms_oldest}s escalations={comms_escalations}")
elif comms_slo_status == "warn":
    anomalies.append(f"COMMS QUEUE SIDE-SURFACE WARN: pending={comms_pending} oldest={comms_oldest}s")

if joined_state_summary.get("coherence_attention"):
    anomalies.append(
        "ENGINE COHERENCE: attention required"
        f" (active_waves={joined_state_summary.get('active_waves', '?')},"
        f" orphaned_waves={joined_state_summary.get('orphaned_waves', '?')},"
        f" verify={joined_state_summary.get('verify_status', 'unknown')})"
    )

# Check background loop heartbeat freshness
now_utc = datetime.now(timezone.utc)
stale_background_count = 0
for loop in open_loops:
    if loop.get("execution_mode") != "background":
        continue

    loop_id = loop.get("loop_id", "?")
    track_enabled = bool(str(loop.get("heartbeat_ttl_minutes", "")).strip() or str(loop.get("last_heartbeat_utc", "")).strip())
    if not track_enabled:
        continue

    ttl_raw = str(loop.get("heartbeat_ttl_minutes", "")).strip()
    try:
        ttl_minutes = int(ttl_raw) if ttl_raw else 45
    except ValueError:
        ttl_minutes = 45

    heartbeat_raw = str(loop.get("last_heartbeat_utc", "")).strip()
    if not heartbeat_raw:
        loop["background_heartbeat_stale"] = True
        loop["heartbeat_age_minutes"] = None
        stale_background_count += 1
        anomalies.append(f"LOOP BACKGROUND STALE: {loop_id} missing heartbeat (ttl={ttl_minutes}m)")
        continue

    heartbeat_dt = parse_iso_utc(heartbeat_raw)
    if heartbeat_dt is None:
        loop["background_heartbeat_stale"] = True
        loop["heartbeat_age_minutes"] = None
        stale_background_count += 1
        anomalies.append(f"LOOP BACKGROUND STALE: {loop_id} invalid heartbeat '{heartbeat_raw}'")
        continue

    age_minutes = max(0.0, (now_utc - heartbeat_dt).total_seconds() / 60.0)
    loop["heartbeat_age_minutes"] = age_minutes
    loop["background_heartbeat_stale"] = age_minutes > ttl_minutes
    if loop["background_heartbeat_stale"]:
        stale_background_count += 1
        anomalies.append(
            f"LOOP BACKGROUND STALE: {loop_id} heartbeat age={age_minutes:.1f}m ttl={ttl_minutes}m"
        )

# ── Daemon load truth ─────────────────────────────────────────────────────
#
# required_labels in launchd.runtime.contract.yaml is ESTATE-WIDE scheduler
# truth — labels that must be scheduled somewhere, not labels that must be
# loaded on THIS host. Each label's actual host comes from intended_node_role
# in the scheduler registry. This code role-filters accordingly and reports
# non-local labels as non_local_deferred, not missing.

daemons_summary = {
    "required_total": 0,
    "loaded": 0,
    "missing": 0,
    "missing_labels": [],
    "non_local_deferred": [],
    "non_local_breakdown": {
        "active_elsewhere": [],
        "parked_required": [],
        "locality_exempt": [],
        "other": [],
    },
    "local_role": "",
}

try:
    launchd_contract = spine / "ops" / "bindings" / "launchd.runtime.contract.yaml"
    if launchd_contract.is_file():
        import yaml as _yaml_daemons  # type: ignore
        _ld = _yaml_daemons.safe_load(launchd_contract.read_text(encoding="utf-8")) or {}
        # required_labels may be a dict with .labels list (annotated form)
        # or a plain list (legacy). Handle both.
        _rl_raw = _ld.get("required_labels") or []
        if isinstance(_rl_raw, dict):
            _rl_raw = _rl_raw.get("labels") or []
        _required = [str(x) for x in _rl_raw if x]

        # Role-aware filter: labels whose intended_node_role (from the
        # scheduler registry) does not match the local host's role are
        # deferred, not missing. Matches verify-engine E10 exactly so
        # status and E10 agree on required-label truth per host.
        local_role = (os.environ.get("SPINE_LOCAL_ROLE", "").strip() or "operator_console")
        role_by_label = {}
        state_by_label = {}
        _registry = spine / "ops" / "bindings" / "launchd.scheduler.registry.yaml"
        if _registry.is_file():
            _reg = _yaml_daemons.safe_load(_registry.read_text(encoding="utf-8")) or {}
            for _entry in (_reg.get("labels") or []):
                _lbl = str((_entry or {}).get("label", "")).strip()
                _role = str((_entry or {}).get("intended_node_role", "")).strip()
                _state = str((_entry or {}).get("state", "")).strip().lower()
                if _lbl:
                    role_by_label[_lbl] = _role
                    state_by_label[_lbl] = _state
        # Also read operator_console_launchd_loaded flag per label
        _locally_unloaded = set()
        for _entry in (_reg.get("labels") or []):
            _lbl = str((_entry or {}).get("label", "")).strip()
            if _lbl and (_entry or {}).get("operator_console_launchd_loaded") is False:
                _locally_unloaded.add(_lbl)
        local_required = [
            lbl for lbl in _required
            if role_by_label.get(lbl, local_role) == local_role
            and lbl not in _locally_unloaded
        ]
        non_local = [lbl for lbl in _required if lbl not in local_required]
        active_elsewhere = []
        parked_required = []
        locality_exempt = []
        other_non_local = []
        for lbl in non_local:
            _role = role_by_label.get(lbl, "")
            _state = state_by_label.get(lbl, "")
            if lbl in _locally_unloaded and _role == local_role:
                locality_exempt.append(lbl)
            elif _state == "parked":
                parked_required.append(lbl)
            elif _role and _role != local_role:
                active_elsewhere.append(lbl)
            else:
                other_non_local.append(lbl)

        loaded_labels = set()
        try:
            _lp = _sp.run(["launchctl", "list"], capture_output=True, text=True, timeout=10)
            if _lp.returncode == 0:
                for _line in _lp.stdout.splitlines():
                    parts = _line.split()
                    if len(parts) >= 3:
                        loaded_labels.add(parts[2])
        except Exception:
            pass
        missing = [lbl for lbl in local_required if lbl not in loaded_labels]
        # Derive execution_host target and workload labels from full scheduler registry
        # Include purpose text for cockpit rendering
        purpose_by_label = {}
        for _entry in (_reg.get("labels") or []):
            _lbl = str((_entry or {}).get("label", "")).strip()
            _purpose = str((_entry or {}).get("purpose", "")).strip()
            if _lbl and _purpose:
                purpose_by_label[_lbl] = _purpose
        exec_host_labels = [lbl for lbl, role in role_by_label.items() if role == "execution_host"]
        exec_host_target = ""
        exec_host_target_access = ""
        # Read activation receipt for canonical execution_host target
        _domain_state = Path(str(state_root)) / "domain-state"
        if _domain_state.is_dir():
            for _receipt_path in sorted(_domain_state.glob("EXEC_RECEIPT-SPINE-EXECUTION-HOST-ACTIVATION-*.yaml"), reverse=True):
                try:
                    _receipt = _yaml_daemons.safe_load(_receipt_path.read_text(encoding="utf-8")) or {}
                    _target = str(_receipt.get("final_live_execution_host") or _receipt.get("target_host") or "").strip()
                    if _target:
                        exec_host_target = _target
                        exec_host_target_access = str(_receipt.get("target_access_path") or "").strip()
                        break
                except Exception:
                    pass

        daemons_summary = {
            "required_total": len(local_required),
            "loaded": len(local_required) - len(missing),
            "missing": len(missing),
            "missing_labels": missing,
            "non_local_deferred": non_local,
            "non_local_breakdown": {
                "active_elsewhere": active_elsewhere,
                "parked_required": parked_required,
                "locality_exempt": locality_exempt,
                "other": other_non_local,
            },
            "local_role": local_role,
            "execution_host": {
                "target": exec_host_target,
                "target_access": exec_host_target_access,
                "workload_count": len(exec_host_labels),
                "workload_labels": exec_host_labels,
                "workload_purposes": {lbl: purpose_by_label.get(lbl, "") for lbl in exec_host_labels},
            },
        }
        if missing:
            anomalies.append(
                f"LAUNCHD REQUIRED LABEL(S) NOT LOADED ({local_role}): {', '.join(missing)}"
            )
except Exception:
    pass

# ── Output ────────────────────────────────────────────────────────────────

if mode == "--json":
    print(json.dumps({
        "mode": "json",
        "strict": strict_mode,
        "open_loops": open_loops,
        "planned_loops": planned_loops,
        "open_gaps": open_gaps,
        "gap_state": {
            "status": gap_state.get("status", "degraded"),
            "source": gap_state.get("source", "unknown"),
            "message": gap_state.get("message", ""),
            "db_path": gap_state.get("db_path", ""),
            "open_count": open_gap_count,
            "linked_count": linked_gap_count,
            "unlinked_count": unlinked_gap_count,
        },
        "inbox_lanes": inbox_lanes,
        "inbox_active": inbox_active,
        "inbox_total": inbox_total,
        "inbox_actionable": inbox_actionable,
        "inbox_history_total": inbox_history_total,
        "anomalies": anomalies,
        "comms_queue": {
            "controller_todo": False,
            "slo_status": comms_slo_status,
            "drain_state": comms_drain_state,
            "pending": comms_pending,
            "oldest_age_seconds": comms_oldest,
            "escalations": comms_escalations,
            "delivery_recent": comms_delivery_recent,
            "delivery_recent_failed": comms_delivery_recent_failed,
            "sent_total": comms_sent_total,
            "oneliner": comms_oneliner,
        },
        "coherence_summary": joined_state_summary,
        "daemons": daemons_summary,
        "counts": {
            # Use joined-state as authoritative source so status --json and
            # status --context agree on the same open-loop count (H6 coherence).
            "open_loops": int(joined_state_summary.get("open_loops", len(open_loops))),
            "background_loops": sum(1 for loop in open_loops if loop.get("execution_mode") == "background"),
            "stale_background_loops": stale_background_count,
            "planned_loops": len(planned_loops),
            "closed_loops": len(closed_loops),
            "horizon_now": sum(1 for loop in open_loops if loop.get("horizon", "now") == "now"),
            "horizon_later": sum(1 for loop in open_loops if loop.get("horizon", "now") == "later"),
            "horizon_future": sum(1 for loop in open_loops if loop.get("horizon", "now") == "future"),
            "open_gaps": open_gap_count,
            "linked_gaps": linked_gap_count,
            "unlinked_gaps": unlinked_gap_count,
            "active_waves": int(joined_state_summary.get("active_waves") or 0),
            "orphaned_waves": int(joined_state_summary.get("orphaned_waves") or 0),
            "verify_status": joined_state_summary.get("verify_status", "unknown"),
            "coherence_attention": bool(joined_state_summary.get("coherence_attention", False)),
            "inbox_active": inbox_active,
            "inbox_total": inbox_total,
            "inbox_actionable": inbox_actionable,
            "inbox_history_total": inbox_history_total,
            "anomalies": len(anomalies),
            "completion_state": joined_state_summary.get("completion_state"),
        }
    }, indent=2))
    sys.exit(1 if strict_mode and len(anomalies) > 0 else 0)

if mode == "--brief":
    background_open = sum(1 for loop in open_loops if loop.get("execution_mode") == "background")
    now_runnable = sum(1 for loop in open_loops if loop.get("horizon", "now") == "now" and loop.get("execution_readiness", "runnable") == "runnable")
    later_count = sum(1 for loop in open_loops if loop.get("horizon", "now") == "later")
    future_count = sum(1 for loop in open_loops if loop.get("horizon", "now") == "future")
    joined_open_loops = int(joined_state_summary.get("open_loops", len(open_loops)) or len(open_loops))
    loop_part = f"Loops: {joined_open_loops} open"
    if background_open:
        loop_part += f" ({background_open} background"
        if stale_background_count:
            loop_part += f", {stale_background_count} stale"
        loop_part += ")"
    # Show horizon breakdown if any non-now loops exist
    if later_count or future_count:
        loop_part += f" [now={now_runnable}"
        if later_count:
            loop_part += f" later={later_count}"
        if future_count:
            loop_part += f" future={future_count}"
        loop_part += "]"
    parts = [loop_part]
    if planned_loops:
        parts[0] += f" + {len(planned_loops)} planned"
    if gaps_available:
        parts.append(f"Gaps: {open_gap_count} open ({unlinked_gap_count} unlinked)")
    else:
        parts.append("Gaps: unknown (authority degraded)")
    if joined_state_summary.get("active_waves") is not None:
        parts.append(
            f"Waves: {joined_state_summary.get('active_waves', 0)} active / {joined_state_summary.get('orphaned_waves', 0)} orphaned"
        )
    parts.append(f"Verify: {joined_state_summary.get('verify_status', 'unknown')}")
    if joined_state_summary.get("coherence_attention"):
        parts.append("Coherence: attention")
    if inbox_actionable:
        parts.append(f"Inbox: {inbox_actionable} actionable")
    parts.append(f"Anomalies: {len(anomalies)}")
    print(" | ".join(parts))
    sys.exit(1 if strict_mode and len(anomalies) > 0 else 0)

# Full output
print("=" * 72)
print("  SPINE STATUS")
print("=" * 72)
print()

print("COHERENCE SUMMARY")
print("-" * 72)
print(f"  open loops:         {joined_state_summary.get('open_loops', len(open_loops))}")
print(f"  open gaps:          {joined_state_summary.get('open_gaps', open_gap_count)}")
print(f"  active waves:       {joined_state_summary.get('active_waves', '?')}")
print(f"  orphaned waves:     {joined_state_summary.get('orphaned_waves', '?')}")
print(f"  spine verify:       {joined_state_summary.get('verify_status', 'unknown')}")
print(f"  coherence attention:{' yes' if joined_state_summary.get('coherence_attention') else ' no'}")
_cs = joined_state_summary.get("completion_state")
if isinstance(_cs, dict):
    _cs_parts = []
    for _sn in ("open", "parked", "landed_local", "owned_elsewhere", "orphaned", "ambiguous"):
        _sv = _cs.get(_sn, 0)
        if _sv:
            _cs_parts.append(f"{_sn}={_sv}")
    _cs_live = _cs.get("live_specimens", 0)
    print(f"  completion state:   {_cs_live} live ({', '.join(_cs_parts) if _cs_parts else 'all clear'})")
print()

# ── Open Loops ──
sev_order = {"critical": 0, "high": 1, "medium": 2, "low": 3, "-": 4, "unknown": 5}
sorted_loops = sorted(open_loops, key=lambda x: sev_order.get(x["severity"], 9))

# Partition into eligible (now+runnable) vs deferred
eligible_loops = [l for l in sorted_loops if l.get("horizon", "now") == "now" and l.get("execution_readiness", "runnable") == "runnable"]
deferred_loops = [l for l in sorted_loops if l not in eligible_loops]

print(f"OPEN LOOPS ({len(open_loops)})")
print("-" * 72)
if not open_loops:
    print("  (none)")
else:
    if deferred_loops:
        print(f"  Eligible (now+runnable): {len(eligible_loops)}  |  Deferred (later/future/blocked): {len(deferred_loops)}")
        print()
    for loop in sorted_loops:
        tags = ""
        if loop.get("execution_mode") == "background":
            tags += " [background]"
        horizon = loop.get("horizon", "now")
        if horizon != "now":
            tags += f" [{horizon}]"
        if loop.get("execution_readiness", "runnable") == "blocked":
            tags += " [not-runnable]"
        print(f"  [{loop['severity']:8s}] {loop['owner']:15s} {loop['loop_id']}{tags}")
        if loop["title"] != loop["loop_id"]:
            print(f"  {'':8s}  {'':15s} {loop['title']}")
        if loop.get("execution_mode") == "background":
            line = "background lane"
            if loop.get("active_terminal"):
                line += f", terminal={loop['active_terminal']}"
            print(f"  {'':8s}  {'':15s} {line}")
            heartbeat_at = loop.get("last_heartbeat_utc", "")
            ttl_raw = str(loop.get("heartbeat_ttl_minutes", "")).strip()
            ttl_minutes = ttl_raw if ttl_raw else "45"
            track_enabled = bool(ttl_raw or heartbeat_at)
            if track_enabled:
                if heartbeat_at:
                    hb_line = f"heartbeat: {heartbeat_at} (ttl={ttl_minutes}m"
                    if loop.get("heartbeat_source"):
                        hb_line += f", source={loop['heartbeat_source']}"
                    age = loop.get("heartbeat_age_minutes")
                    if isinstance(age, (int, float)):
                        hb_line += f", age={age:.1f}m"
                    hb_line += ")"
                    if loop.get("background_heartbeat_stale"):
                        hb_line += " [STALE]"
                    print(f"  {'':8s}  {'':15s} {hb_line}")
                else:
                    print(f"  {'':8s}  {'':15s} heartbeat: missing (ttl={ttl_minutes}m) [STALE]")
            else:
                print(f"  {'':8s}  {'':15s} heartbeat tracking: not initialized")
        if loop.get("blocked_by") and loop["blocked_by"] != "none":
            print(f"  {'':8s}  {'':15s} blocked_by: {loop['blocked_by']}")
        if loop.get("operator_note"):
            print(f"  {'':8s}  {'':15s} note: {loop['operator_note']}")
print()

# ── Planned Loops ──
if planned_loops:
    print(f"PLANNED LOOPS ({len(planned_loops)})")
    print("-" * 72)
    for loop in planned_loops:
        print(f"  [{loop['severity']:8s}] {loop['owner']:15s} {loop['loop_id']}")
        if loop["title"] != loop["loop_id"]:
            print(f"  {'':8s}  {'':15s} {loop['title']}")
    print()

# ── Open Gaps ──
gap_heading = str(open_gap_count) if gaps_available else "unknown"
print(f"OPEN GAPS ({gap_heading})")
print("-" * 72)
if not gaps_available:
    print(f"  authority: {gap_state.get('status', 'degraded')}")
    print(f"  source: {gap_state.get('source', 'unknown')}")
    if gap_state.get("message"):
        print(f"  reason: {gap_state['message']}")
elif not open_gaps:
    print("  (none)")
else:
    for gap in open_gaps:
        parent = f" -> {gap['parent_loop']}" if gap["parent_loop"] and gap["parent_loop"] != "null" else " (UNLINKED)"
        desc = gap["description"][:60] if gap["description"] else ""
        print(f"  [{gap['severity']:8s}] {gap['id']:12s}{parent}")
print()

# ── Inbox actionable state ──
if inbox_actionable > 0:
    print(f"INBOX ACTIONABLE ({inbox_actionable})")
    print("-" * 72)
    for lane_name in ["queued", "running", "failed"]:
        count = inbox_lanes.get(lane_name, 0)
        if count > 0:
            marker = " !"
            print(f"  {lane_name:12s} {count}{marker}")
    print()

# ── Inbox history ──
if inbox_history_total > 0:
    print(f"INBOX HISTORY ({inbox_history_total})")
    print("-" * 72)
    for lane_name in ["parked", "done", "archived"]:
        count = inbox_lanes.get(lane_name, 0)
        if count > 0:
            print(f"  {lane_name:12s} {count}")
    print()

# ── Communications Queue ──
if comms_oneliner:
    print("COMMS QUEUE (SIDE SURFACE)")
    print("-" * 72)
    print("  not controller todo; communications drain state only")
    print(f"  {comms_oneliner}")
    print()

# ── Anomalies ──
if anomalies:
    print(f"ANOMALIES ({len(anomalies)})")
    print("-" * 72)
    for a in anomalies:
        print(f"  ! {a}")
    print()

# ── Summary line ──
print("=" * 72)
parts = [f"{len(open_loops)} loops"]
if planned_loops:
    parts.append(f"{len(planned_loops)} planned")
if gaps_available and open_gap_count:
    parts.append(f"{open_gap_count} gaps")
elif not gaps_available:
    parts.append("gaps unknown")
if stale_background_count:
    parts.append(f"{stale_background_count} stale background")
if inbox_actionable:
    parts.append(f"{inbox_actionable} inbox actionable")
if anomalies:
    parts.append(f"{len(anomalies)} anomalies")
print(f"  {' | '.join(parts)}")
print("=" * 72)

# Default human-facing status succeeds even when anomalies exist.
# Use --strict when anomaly-sensitive exit codes are required.
sys.exit(1 if strict_mode and len(anomalies) > 0 else 0)
PYTHON
