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
if [[ "$MODE" == "--context" ]]; then
  JOINED_STATE_BIN="$SPINE_REPO/ops/plugins/core/lifecycle/bin/spine-engine-joined-state"

  TERMINAL_ID="${SPINE_TERMINAL_ID:-${OPS_TERMINAL_ID:-${OPS_TERMINAL_ROLE:-<none>}}}"
  EXECUTION_CLASS="${SPINE_EXECUTION_CLASS:-${SPINE_RUNTIME_ROLE:-<none>}}"
  LOOP_ID="${SPINE_LOOP_ID:-<none>}"
  SESSION_LOOP_DISPLAY="$LOOP_ID"
  SESSION_LOOP_RESIDUE=""

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
  PROJECTION_RESIDUE="$(jq_val '.summary.projection_residue' '0')"
  OPEN_GAPS="$(jq_val '.summary.open_gaps' '?')"
  ACTIVE_WAVES="$(jq_val '.summary.active_waves' '?')"
  ORPHANED_WAVES="$(jq_val '.summary.orphaned_waves' '?')"
  VERIFY_STATUS="$(jq_val '.summary.latest_verify_status' 'unknown')"
  VERIFY_SCOPE="$(jq_val '.summary.latest_verify_scope' '')"
  VERIFY_TEMPORAL_CLASS="$(jq_val '.summary.latest_verify_temporal_class' '')"
  VERIFY_KNOWN_SINCE="$(jq_val '.summary.latest_verify_known_since_utc' '')"
  VERIFY_STANDING_COUNT="$(jq_val '.summary.latest_verify_standing_evidence_count' '0')"
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
    _session_loop_state="$(
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

if session_loop_id in open_loop_ids:
    print("live")
elif session_loop_id:
    print("stale")
PY
    )"
    if [[ "$_session_loop_state" == "stale" ]]; then
      SESSION_LOOP_DISPLAY="<none>"
      SESSION_LOOP_RESIDUE="$LOOP_ID (historical env; not in current open loops)"
    fi
  fi

  echo "─── spine context ───────────────────────────────────"
  printf "  terminal id:    %s\n" "$TERMINAL_ID"
  printf "  execution class: %s\n" "$EXECUTION_CLASS"
  printf "  session loop:   %s\n" "$SESSION_LOOP_DISPLAY"
  if [[ -n "$SESSION_LOOP_RESIDUE" ]]; then
    printf "  loop residue:   %s\n" "$SESSION_LOOP_RESIDUE"
  fi
  printf "  state root:     %s\n" "$STATE_ROOT_VAL"
  printf "  evidence root:  %s\n" "$EVIDENCE_ROOT"
  echo "─── open work ──────────────────────────────────────"
  printf "  open loops:     %s\n" "$OPEN_LOOPS"
  if [[ "$PROJECTION_RESIDUE" != "0" ]]; then
    printf "  projection residue: %s stale scope file(s)\n" "$PROJECTION_RESIDUE"
  fi
  printf "  open gaps:      %s\n" "$OPEN_GAPS"
  printf "  active waves:   %s\n" "$ACTIVE_WAVES"
  printf "  orphaned waves: %s\n" "$ORPHANED_WAVES"
  echo "─── verify / coherence ─────────────────────────────"
  printf "  spine verify:   %s\n" "$VERIFY_STATUS"
  if [[ -n "$VERIFY_TEMPORAL_CLASS" ]]; then
    _verify_temporal_line="$VERIFY_TEMPORAL_CLASS"
    if [[ -n "$VERIFY_KNOWN_SINCE" ]]; then
      _verify_temporal_line+=" since $VERIFY_KNOWN_SINCE"
    fi
    if [[ "$VERIFY_STANDING_COUNT" =~ ^[0-9]+$ ]] && [[ "$VERIFY_STANDING_COUNT" != "0" ]]; then
      _verify_temporal_line+=" (${VERIFY_STANDING_COUNT} corroborating receipt(s))"
    fi
    printf "  verify standing:%s\n" "   $_verify_temporal_line"
  fi
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
  echo "─── execution lane truth ───────────────────────────"
  printf "  mailroom execution:      %s\n" "capability_backed"
  printf "  agent tool bridge:       %s\n" "deferred"
  printf "  interactive delegation:  %s\n" "explicit_worker_pickup_required"
  printf "  autonomous AI agent:     %s\n" "not_delivered"
  echo "─────────────────────────────────────────────────────"
  exit 0
fi

exec python3 - "$SPINE_REPO" "$MODE" "$STRICT" "$SPINE_STATE" "$SPINE_INBOX" "$SPINE_OUTBOX" <<'PYTHON'
import json
import os
import re
import socket
import subprocess
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
terminal_liveness_dir = state_root / "terminals"
terminal_custody_dir = state_root / "terminal-heartbeats"
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

temporal_truth = None
temporal_truth_import_error = None
try:
    import temporal_truth
except Exception as exc:  # pragma: no cover - exercised via degraded status surface
    temporal_truth_import_error = exc

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

def age_minutes_from(dt_value, now_utc):
    if dt_value is None:
        return None
    return max(0.0, (now_utc - dt_value).total_seconds() / 60.0)

telemetry_now_utc = datetime.now(timezone.utc)
terminal_observation_window_minutes = 24 * 60
default_terminal_liveness_ttl_minutes = 45

def collect_terminal_telemetry():
    liveness_by_terminal = {}
    custody_by_terminal = {}

    if terminal_liveness_dir.is_dir():
        for hb_file in sorted(terminal_liveness_dir.glob("*.heartbeat")):
            hb = parse_kv_yaml(hb_file)
            terminal_id = str(hb.get("terminal_id") or hb_file.stem).strip()
            if not terminal_id:
                continue
            liveness_by_terminal[terminal_id] = {
                "last_heartbeat_utc": str(hb.get("last_heartbeat_utc") or "").strip(),
                "last_capability": str(hb.get("last_capability") or "").strip(),
                "last_exit_code": str(hb.get("last_exit_code") or "").strip(),
                "source": str(hb.get("source") or "").strip(),
            }

    if terminal_custody_dir.is_dir():
        for hb_file in sorted(terminal_custody_dir.glob("*.yaml")):
            hb = parse_kv_yaml(hb_file)
            terminal_id = str(hb.get("terminal_id") or hb_file.stem).strip()
            if not terminal_id:
                continue
            custody_by_terminal[terminal_id] = {
                "role": str(hb.get("role") or "").strip(),
                "execution_class": str(hb.get("execution_class") or hb.get("runtime_role") or "").strip(),
                "runtime_role": str(hb.get("runtime_role") or "").strip(),
                "scope": str(hb.get("scope") or "").strip(),
                "normalized_scope": str(hb.get("normalized_scope") or "").strip(),
                "protected_hotspot_scope": str(hb.get("protected_hotspot_scope") or "").strip(),
                "loop_id": str(hb.get("loop_id") or "").strip(),
                "repo_root": str(hb.get("repo_root") or "").strip(),
                "checkout_root": str(hb.get("checkout_root") or "").strip(),
                "branch": str(hb.get("branch") or "").strip(),
                "lane_type": str(hb.get("lane_type") or "").strip(),
                "status": str(hb.get("status") or "").strip(),
                "pid": str(hb.get("pid") or "").strip(),
                "hostname": str(hb.get("hostname") or "").strip(),
                "heartbeat_at": str(hb.get("heartbeat_at") or "").strip(),
                "expires_at": str(hb.get("expires_at") or "").strip(),
            }

    rows = []
    observed_ids = sorted(set(liveness_by_terminal) | set(custody_by_terminal))
    for terminal_id in observed_ids:
        live = liveness_by_terminal.get(terminal_id, {})
        custody = custody_by_terminal.get(terminal_id, {})

        live_dt = parse_iso_utc(live.get("last_heartbeat_utc"))
        live_age = age_minutes_from(live_dt, telemetry_now_utc)
        liveness_fresh = isinstance(live_age, (int, float)) and live_age <= default_terminal_liveness_ttl_minutes

        custody_heartbeat_dt = parse_iso_utc(custody.get("heartbeat_at"))
        custody_expires_dt = parse_iso_utc(custody.get("expires_at"))
        custody_age = age_minutes_from(custody_heartbeat_dt, telemetry_now_utc)
        if custody_expires_dt is not None:
            custody_fresh = custody_expires_dt >= telemetry_now_utc
        else:
            custody_fresh = isinstance(custody_age, (int, float)) and custody_age <= default_terminal_liveness_ttl_minutes

        repo_root = str(custody.get("repo_root") or "").strip()
        checkout_root = str(custody.get("checkout_root") or "").strip()
        repo_root_exists = Path(repo_root).exists() if repo_root else None
        checkout_root_exists = Path(checkout_root).exists() if checkout_root else None
        custody_anomaly = ""
        if custody_fresh:
            if checkout_root and checkout_root_exists is False:
                custody_fresh = False
                custody_anomaly = "missing_checkout_root"
            elif repo_root and repo_root_exists is False:
                custody_fresh = False
                custody_anomaly = "missing_repo_root"

        last_seen_candidates = [dt for dt in (live_dt, custody_heartbeat_dt) if dt is not None]
        last_seen_dt = max(last_seen_candidates) if last_seen_candidates else None
        observed_recently = (
            liveness_fresh
            or custody_fresh
            or (isinstance(live_age, (int, float)) and live_age <= terminal_observation_window_minutes)
            or (isinstance(custody_age, (int, float)) and custody_age <= terminal_observation_window_minutes)
            or terminal_id.startswith("SPINE-")
        )
        if not observed_recently:
            continue

        row = {
            "terminal_id": terminal_id,
            "last_heartbeat_utc": live.get("last_heartbeat_utc", ""),
            "last_capability": live.get("last_capability", ""),
            "last_exit_code": live.get("last_exit_code", ""),
            "liveness_source": live.get("source", ""),
            "liveness_fresh": bool(liveness_fresh),
            "liveness_age_minutes": round(live_age, 1) if isinstance(live_age, (int, float)) else None,
            "liveness_ttl_minutes": default_terminal_liveness_ttl_minutes,
            "custody_heartbeat_at": custody.get("heartbeat_at", ""),
            "custody_expires_at": custody.get("expires_at", ""),
            "custody_fresh": bool(custody_fresh),
            "custody_age_minutes": round(custody_age, 1) if isinstance(custody_age, (int, float)) else None,
            "role": custody.get("role", ""),
            "execution_class": custody.get("execution_class", custody.get("runtime_role", "")),
            "runtime_role": custody.get("runtime_role", ""),
            "scope": custody.get("scope", ""),
            "normalized_scope": custody.get("normalized_scope", ""),
            "protected_hotspot_scope": custody.get("protected_hotspot_scope", ""),
            "loop_id": custody.get("loop_id", ""),
            "repo_root": repo_root,
            "repo_root_exists": repo_root_exists,
            "checkout_root": checkout_root,
            "checkout_root_exists": checkout_root_exists,
            "branch": custody.get("branch", ""),
            "lane_type": custody.get("lane_type", ""),
            "status": custody.get("status", ""),
            "custody_anomaly": custody_anomaly,
            "pid": custody.get("pid", ""),
            "hostname": custody.get("hostname", ""),
            "_sort_utc": last_seen_dt.strftime("%Y-%m-%dT%H:%M:%SZ") if last_seen_dt else "",
        }
        rows.append(row)

    rows.sort(key=lambda item: item.get("_sort_utc", ""), reverse=True)
    for row in rows:
        row.pop("_sort_utc", None)
    return rows

terminal_telemetry = collect_terminal_telemetry()
fresh_terminals = [row for row in terminal_telemetry if row.get("liveness_fresh")]
fresh_custody_terminals = [row for row in terminal_telemetry if row.get("custody_fresh")]
fresh_custody_by_loop = {}
live_open_loop_ids = {
    str(loop.get("loop_id") or "").strip()
    for loop in open_loops
    if str(loop.get("loop_id") or "").strip()
}
fresh_custody_live_claims = 0
for row in fresh_custody_terminals:
    loop_id = str(row.get("loop_id") or "").strip()
    if not loop_id:
        continue
    if loop_id in live_open_loop_ids:
        fresh_custody_live_claims += 1
    existing = fresh_custody_by_loop.get(loop_id)
    existing_ts = str(existing.get("custody_heartbeat_at") or "") if existing else ""
    current_ts = str(row.get("custody_heartbeat_at") or "")
    if existing is None or current_ts > existing_ts:
        fresh_custody_by_loop[loop_id] = row

for loop in open_loops:
    loop_id = loop.get("loop_id", "")
    if not loop_id:
        continue
    loop["loop_custody_fresh"] = False
    loop["active_terminal_source"] = ""
    safe_loop_id = re.sub(r"[^A-Za-z0-9._-]", "_", loop_id)
    hb_file = loop_heartbeat_dir / f"{safe_loop_id}.yaml"
    hb = parse_kv_yaml(hb_file) if hb_file.exists() else {}
    heartbeat_raw = str(hb.get("last_heartbeat_utc") or "").strip()
    ttl_raw = str(hb.get("heartbeat_ttl_minutes") or "").strip()
    heartbeat_dt = parse_iso_utc(heartbeat_raw)
    try:
        ttl_minutes = int(ttl_raw) if ttl_raw else 45
    except ValueError:
        ttl_minutes = 45
    heartbeat_age = age_minutes_from(heartbeat_dt, telemetry_now_utc)
    heartbeat_fresh = isinstance(heartbeat_age, (int, float)) and heartbeat_age <= ttl_minutes
    if heartbeat_raw:
        loop["last_heartbeat_utc"] = heartbeat_raw
        loop["heartbeat_source"] = "runtime"
    if ttl_raw:
        loop["heartbeat_ttl_minutes"] = ttl_raw
        loop["heartbeat_source"] = "runtime"
    if hb.get("terminal_id"):
        loop["active_terminal"] = str(hb["terminal_id"]).strip()
        loop["active_terminal_source"] = "loop_heartbeat"
    if heartbeat_fresh and loop.get("active_terminal"):
        loop["loop_custody_fresh"] = True

    if not loop.get("loop_custody_fresh"):
        terminal_row = fresh_custody_by_loop.get(loop_id)
        if terminal_row:
            loop["active_terminal"] = str(terminal_row.get("terminal_id") or "").strip()
            loop["active_terminal_source"] = "terminal_custody"
            loop["loop_custody_fresh"] = bool(loop.get("active_terminal"))

mapped_open_loops = sum(1 for loop in open_loops if loop.get("loop_custody_fresh"))
unmapped_open_loops = sum(1 for loop in open_loops if not loop.get("loop_custody_fresh"))
terminal_telemetry_status = "ok"
if open_loops and mapped_open_loops == 0 and fresh_custody_live_claims == 0:
    terminal_telemetry_status = "unattended"
elif open_loops and fresh_terminals and mapped_open_loops == 0:
    terminal_telemetry_status = "degraded"
elif open_loops and fresh_custody_terminals and mapped_open_loops == 0:
    terminal_telemetry_status = "stale"
elif open_loops and not terminal_telemetry:
    terminal_telemetry_status = "unavailable"

terminal_telemetry_summary = {
    "status": terminal_telemetry_status,
    "observation_window_hours": terminal_observation_window_minutes // 60,
    "fresh_terminals": len(fresh_terminals),
    "fresh_custody_terminals": len(fresh_custody_terminals),
    "observed_terminals": len(terminal_telemetry),
    "fresh_custody_live_claims": fresh_custody_live_claims,
    "mapped_open_loops": mapped_open_loops,
    "unmapped_open_loops": unmapped_open_loops,
    "terminals": terminal_telemetry,
}

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


def run_json_command(cmd: list[str], *, timeout: int = 20) -> dict:
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
            env=os.environ.copy(),
        )
    except Exception as exc:
        return {"status": "error", "error": str(exc)}

    if proc.returncode != 0:
        return {
            "status": "error",
            "error": (proc.stderr or proc.stdout or f"exit {proc.returncode}").strip(),
        }

    try:
        payload = json.loads(proc.stdout or "{}")
    except Exception as exc:
        return {"status": "error", "error": f"invalid json: {exc}"}

    return payload if isinstance(payload, dict) else {"status": "error", "error": "non-object json payload"}


def collect_standing_program_health():
    result = {
        "status": "unavailable",
        "evaluated_at_utc": "",
        "summary": {
            "total": 0,
            "healthy": 0,
            "stale": 0,
            "failed": 0,
            "unreachable": 0,
            "never_run": 0,
            "unknown": 0,
        },
        "programs": [],
        "active_interventions": 0,
        "intervention_labels": [],
    }

    drift_bin = spine / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "standing-program-drift-check"
    if not drift_bin.exists():
        result["error"] = f"missing proof evaluator: {drift_bin}"
        return result

    data = run_json_command([sys.executable, str(drift_bin), "--json"])
    if data.get("status") == "error":
        result["error"] = data.get("error", "standing-program-drift-check failed")
        return result

    summary = data.get("summary") if isinstance(data.get("summary"), dict) else {}
    programs = data.get("programs") if isinstance(data.get("programs"), list) else []
    normalized_summary = {
        "total": int(summary.get("total", 0) or 0),
        "healthy": int(summary.get("healthy", 0) or 0),
        "stale": int(summary.get("stale", 0) or 0),
        "failed": int(summary.get("failed", 0) or 0),
        "unreachable": int(summary.get("unreachable", 0) or 0),
        "never_run": int(summary.get("never_run", 0) or 0),
        "unknown": int(summary.get("unknown", 0) or 0),
    }
    degraded = sum(
        normalized_summary[key]
        for key in ("stale", "failed", "unreachable", "never_run", "unknown")
    )
    result.update({
        "status": "ok" if normalized_summary["total"] > 0 and degraded == 0 else "degraded",
        "evaluated_at_utc": str(data.get("evaluated_at_utc") or "").strip(),
        "summary": normalized_summary,
        "programs": programs,
    })

    interventions_dir = state_root / "interventions"
    if interventions_dir.is_dir():
        try:
            import yaml as _yaml_sp  # type: ignore
            bounded_labels = {
                str(item.get("label") or "").strip()
                for item in programs
                if isinstance(item, dict) and str(item.get("label") or "").strip()
            }
            terminal_dispositions = {"cancelled", "dismissed", "landed", "resolved", "superseded"}
            for yf in sorted(interventions_dir.glob("*.yaml")) + sorted(interventions_dir.glob("*.yml")):
                try:
                    doc = _yaml_sp.safe_load(yf.read_text(encoding="utf-8")) or {}
                except Exception:
                    continue
                if not isinstance(doc, dict):
                    continue
                disposition = str(doc.get("disposition", "")).strip().lower()
                if not disposition or disposition in terminal_dispositions:
                    continue
                label = str(doc.get("source_label") or doc.get("label") or yf.stem).strip()
                if bounded_labels and label and label not in bounded_labels:
                    continue
                result["active_interventions"] += 1
                if label:
                    result["intervention_labels"].append(label)
        except Exception:
            pass

    return result


def collect_delegation_summary():
    result = {
        "status": "unavailable",
        "count": 0,
        "active": 0,
        "stale": 0,
        "by_state": {},
        "delegations": [],
    }
    delegation_bin = spine / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "delegation-status"
    if not delegation_bin.exists():
        result["error"] = f"missing delegation status surface: {delegation_bin}"
        return result

    data = run_json_command([sys.executable, str(delegation_bin), "--json"])
    if data.get("status") == "error":
        result["error"] = data.get("error", "delegation-status failed")
        return result

    delegations = data.get("delegations") if isinstance(data.get("delegations"), list) else []
    by_state = Counter(
        str(item.get("delegation_state") or "").strip() or "unknown"
        for item in delegations
        if isinstance(item, dict)
    )
    active = 0
    stale = 0
    for item in delegations:
        if not isinstance(item, dict):
            continue
        raw_state = str(item.get("delegation_state") or "").strip()
        if raw_state not in ("delegated", "picked_up", "executing"):
            continue
        if bool(item.get("continuity_live", True)):
            active += 1
        else:
            stale += 1
    result.update({
        "status": "ok",
        "count": int(data.get("count", len(delegations)) or 0),
        "active": active,
        "stale": stale,
        "by_state": dict(by_state),
        "delegations": delegations,
    })
    return result


gap_state = collect_gap_state()
gaps_available = gap_state.get("status") == "ok"
open_gaps = gap_state.get("open_gaps", []) if gaps_available else []
linked_gaps = gap_state.get("linked_gaps", []) if gaps_available else []
unlinked_gaps = gap_state.get("unlinked_gaps", []) if gaps_available else []
open_gap_count = len(open_gaps) if gaps_available else None
linked_gap_count = len(linked_gaps) if gaps_available else None
unlinked_gap_count = len(unlinked_gaps) if gaps_available else None
standing_program_health = collect_standing_program_health()
delegation_summary = collect_delegation_summary()

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
            capture_output=True, text=True, timeout=25,
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
    "projection_residue": 0,
    "open_gaps": open_gap_count,
    "active_waves": 0,
    "orphaned_waves": 0,
    "verify_status": "unknown",
    "engine_verify_status": "unknown",
    "spine_verify_status": "unknown",
    "secondary_verify_status": "unknown",
    "coherence_attention": False,
}
joined_state_verify_temporal = {}
joined_state_verify_payload = {}
joined_state_projection_residue = []

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
            _verify_payload = ((_jdata.get("verify") or {}).get("latest_fast")) or {}
            _verify_temporal = ((_jdata.get("temporal_truth") or {}).get("verify")) or {}
            _projection_residue = ((_jdata.get("loops") or {}).get("projection_residue")) or []
            if isinstance(_verify_payload, dict):
                joined_state_verify_payload = _verify_payload
            if isinstance(_verify_temporal, dict):
                joined_state_verify_temporal = _verify_temporal
            if isinstance(_projection_residue, list):
                joined_state_projection_residue = [row for row in _projection_residue if isinstance(row, dict)]
            if isinstance(_summary, dict):
                _aw = _summary.get("active_waves")
                _ow = _summary.get("orphaned_waves")
                _cs = _summary.get("completion_state")
                joined_state_summary = {
                    "source": "joined_state",
                    "open_loops": _summary.get("open_loops", len(open_loops)),
                    "projection_residue": _summary.get("projection_residue", 0),
                    "open_gaps": _summary.get("open_gaps", open_gap_count),
                    "active_waves": int(_aw) if isinstance(_aw, (int, float)) else 0,
                    "orphaned_waves": int(_ow) if isinstance(_ow, (int, float)) else 0,
                    "verify_status": _summary.get("latest_verify_status", _summary.get("latest_fast_verify_status", "unknown")),
                    "engine_verify_status": _summary.get("engine_verify_status", "unknown"),
                    "spine_verify_status": _summary.get("spine_verify_status", "unknown"),
                    "secondary_verify_status": _summary.get("secondary_verify_status", "unknown"),
                    "verify_temporal_class": _summary.get("latest_verify_temporal_class", ""),
                    "verify_known_since_utc": _summary.get("latest_verify_known_since_utc", ""),
                    "verify_standing_evidence_count": _summary.get("latest_verify_standing_evidence_count", 0),
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
                    if not _merged:
                        # SQLite-backed open loops are authoritative. Joined-state
                        # may enrich those rows, but it must not introduce extra
                        # open loops on its own.
                        continue
                    _priority = str(_row.get("priority") or _row.get("severity") or "").strip()
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
#
# Anomaly promotion policy (277d941c+):
#   FOUNDATIONAL (promote to anomalies[]): authority failures that break
#     loop routing, session attach, wave dispatch, or verify — i.e. the
#     agent cannot operate correctly.
#   SCOPED (render in own section only): secondary/domain/estate debt
#     that has its own rendering section and does not block agent operation.
#
# Scoped surfaces (already rendered in dedicated sections, NOT promoted):
#   - Unlinked gaps → OPEN GAPS section shows "(UNLINKED)" per gap
#   - Gap authority degraded → OPEN GAPS section shows authority/reason
#   - Inbox active/failed → INBOX ACTIONABLE section shows lane breakdown
#   - Comms queue incident/warn → COMMS QUEUE (SIDE SURFACE) section

# Communications queue health is rendered in its own scoped section
# ("COMMS QUEUE (SIDE SURFACE)") with temporal classification and operator
# treatment notes.  It does NOT promote to the anomalies list because comms
# queue debt is ambient background, not foundational engine/spine health.
# Only escalation-bearing incidents (where a human must act NOW to prevent
# data loss) would warrant anomaly promotion — and that case does not exist
# in the current contract.

if joined_state_summary.get("coherence_attention"):
    anomalies.append(
        "ENGINE COHERENCE: attention required"
        f" (active_waves={joined_state_summary.get('active_waves', '?')},"
        f" orphaned_waves={joined_state_summary.get('orphaned_waves', '?')},"
        f" verify={joined_state_summary.get('verify_status', 'unknown')})"
    )

if terminal_telemetry_status == "degraded":
    anomalies.append(
        "LOOP CUSTODY TELEMETRY DEGRADED:"
        f" {len(fresh_terminals)} fresh terminal heartbeat(s),"
        f" {len(fresh_custody_terminals)} fresh custody record(s),"
        f" 0/{len(open_loops)} open loops mapped"
    )
elif terminal_telemetry_status == "unattended":
    anomalies.append(
        "LOOP CUSTODY UNATTENDED:"
        f" {len(open_loops)} open loop(s),"
        f" {len(fresh_terminals)} fresh terminal heartbeat(s),"
        " no fresh custody claim for a live open loop"
    )

# Check background loop heartbeat freshness
now_utc = telemetry_now_utc
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
    "node_roles": {},
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
        # Derive node-role inventory from the scheduler registry, then separate
        # active delivered runtime from intended/parked inventory for operator
        # readback honesty.
        purpose_by_label = {}
        labels_by_role = {}
        active_labels_by_role = {}
        parked_labels_by_role = {}
        observed_hosts_by_role = {}
        for _entry in (_reg.get("labels") or []):
            _lbl = str((_entry or {}).get("label", "")).strip()
            _purpose = str((_entry or {}).get("purpose", "")).strip()
            _role = str((_entry or {}).get("intended_node_role", "")).strip()
            _state = str((_entry or {}).get("state", "")).strip().lower()
            _proof = (_entry or {}).get("proof_channel") if isinstance((_entry or {}).get("proof_channel"), dict) else {}
            _host = str((_entry or {}).get("active_runtime_host") or _proof.get("host") or "").strip()
            if _lbl and _purpose:
                purpose_by_label[_lbl] = _purpose
            if _lbl and _role:
                labels_by_role.setdefault(_role, []).append(_lbl)
                if _state == "active":
                    active_labels_by_role.setdefault(_role, []).append(_lbl)
                    if _host:
                        observed_hosts_by_role.setdefault(_role, []).append(_host)
                elif _state == "parked":
                    parked_labels_by_role.setdefault(_role, []).append(_lbl)

        _node_contract = spine / "ops" / "bindings" / "node.role.contract.yaml"
        _node_types = {}
        if _node_contract.is_file():
            try:
                _node_data = _yaml_daemons.safe_load(_node_contract.read_text(encoding="utf-8")) or {}
                _node_types = _node_data.get("node_types") or {}
                if not isinstance(_node_types, dict):
                    _node_types = {}
            except Exception:
                _node_types = {}

        def _role_inventory(_role_name):
            _intended = sorted(labels_by_role.get(_role_name, []))
            _active = sorted(active_labels_by_role.get(_role_name, []))
            _parked = sorted(parked_labels_by_role.get(_role_name, []))
            _hosts = sorted(set(observed_hosts_by_role.get(_role_name, [])))
            return {
                "intended_workload_count": len(_intended),
                "intended_workload_labels": _intended,
                "intended_workload_purposes": {lbl: purpose_by_label.get(lbl, "") for lbl in _intended},
                "active_workload_count": len(_active),
                "active_workload_labels": _active,
                "active_workload_purposes": {lbl: purpose_by_label.get(lbl, "") for lbl in _active},
                "parked_workload_count": len(_parked),
                "parked_workload_labels": _parked,
                "parked_workload_purposes": {lbl: purpose_by_label.get(lbl, "") for lbl in _parked},
                "observed_active_hosts": _hosts,
            }

        exec_host_inventory = _role_inventory("execution_host")
        verification_inventory = _role_inventory("verification_node")
        storage_inventory = _role_inventory("storage_evidence_node")
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

        def _node_role_posture(_role_name, _inventory, *, _posture, _delivered, _note, _target="", _target_access="", _promoted=True, _counter_semantics="delivered_runtime"):
            return {
                "role": _role_name,
                "defined_in_binding": _role_name in _node_types,
                "promoted": bool(_promoted),
                "posture": _posture,
                "delivered": bool(_delivered),
                "workload_counter_semantics": _counter_semantics,
                "target": _target,
                "target_access": _target_access,
                "note": _note,
                **_inventory,
            }

        exec_host_role = _node_role_posture(
            "execution_host",
            exec_host_inventory,
            _posture="live" if exec_host_target else "defined_not_delivered",
            _delivered=bool(exec_host_target),
            _note=(
                "Active delivered runtime is counted separately from intended inventory; parked labels remain inventory, not live delivery."
            ),
            _target=exec_host_target,
            _target_access=exec_host_target_access,
            _counter_semantics="delivered_runtime",
        )
        verification_role = _node_role_posture(
            "verification_node",
            verification_inventory,
            _posture="defined_not_delivered",
            _delivered=False,
            _note=(
                "Defined in node.role.contract.yaml; mapped inventory may exist, but no delivered verification_node target is attested yet."
            ),
            _counter_semantics="mapped_inventory",
        )
        storage_role = _node_role_posture(
            "storage_evidence_node",
            storage_inventory,
            _posture="defined_not_delivered",
            _delivered=False,
            _note=(
                "Mapped inventory is shown for planned storage_evidence_node placement, but no separate delivered storage_evidence_node target is attested yet."
            ),
            _counter_semantics="mapped_inventory",
        )
        control_role = {
            "role": "control_node",
            "defined_in_binding": False,
            "promoted": False,
            "posture": "taxonomy_only",
            "delivered": False,
            "target": "",
            "target_access": "",
            "note": (
                "Named in doctrine as future taxonomy only; absent from node.role.contract.yaml and not promoted."
            ),
            "intended_workload_count": 0,
            "intended_workload_labels": [],
            "intended_workload_purposes": {},
            "active_workload_count": 0,
            "active_workload_labels": [],
            "active_workload_purposes": {},
            "parked_workload_count": 0,
            "parked_workload_labels": [],
            "parked_workload_purposes": {},
            "observed_active_hosts": [],
        }

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
                "delivery_posture": exec_host_role.get("posture", "defined_not_delivered"),
                "workload_count": exec_host_inventory["active_workload_count"],
                "workload_labels": exec_host_inventory["active_workload_labels"],
                "workload_purposes": exec_host_inventory["active_workload_purposes"],
                "active_workload_count": exec_host_inventory["active_workload_count"],
                "active_workload_labels": exec_host_inventory["active_workload_labels"],
                "active_workload_purposes": exec_host_inventory["active_workload_purposes"],
                "intended_workload_count": exec_host_inventory["intended_workload_count"],
                "intended_workload_labels": exec_host_inventory["intended_workload_labels"],
                "intended_workload_purposes": exec_host_inventory["intended_workload_purposes"],
                "parked_workload_count": exec_host_inventory["parked_workload_count"],
                "parked_workload_labels": exec_host_inventory["parked_workload_labels"],
                "parked_workload_purposes": exec_host_inventory["parked_workload_purposes"],
                "observed_active_hosts": exec_host_inventory["observed_active_hosts"],
                "note": exec_host_role.get("note", ""),
            },
            "node_roles": {
                "operator_console": {
                    "role": "operator_console",
                    "defined_in_binding": "operator_console" in _node_types,
                    "promoted": True,
                    "posture": "live" if local_role == "operator_console" else "defined_not_local",
                    "delivered": local_role == "operator_console",
                    "target": str(socket.gethostname() or "").strip(),
                    "target_access": "",
                    "note": "Interactive admitting client surface for this current checkout.",
                },
                "execution_host": exec_host_role,
                "verification_node": verification_role,
                "storage_evidence_node": storage_role,
                "control_node": control_role,
            },
        }
        # Missing launchd labels are rendered in the DAEMON LOAD section,
        # not promoted to anomalies. All current required_labels are domain
        # workloads (alerting, finance, media, comms) — none block loop
        # routing, session attach, wave dispatch, verify, or authority
        # coherence.  If a spine-critical daemon is ever added to the
        # required_labels contract, add a "spine_critical: true" field in
        # the scheduler registry and promote only those.
except Exception:
    pass

temporal_truth_payload = {
    "verify": joined_state_verify_temporal,
    "comms_queue": {},
    "daemons": {},
}

if temporal_truth is not None:
    try:
        if not temporal_truth_payload["verify"] and isinstance(joined_state_verify_payload, dict):
            temporal_truth_payload["verify"] = temporal_truth.classify_spine_verify(
                spine,
                Path(os.environ.get("SPINE_RECEIPTS") or (Path.home() / "code/.evidence/spine/sessions")),
                joined_state_verify_payload,
            )
    except Exception:
        temporal_truth_payload["verify"] = {}
    try:
        temporal_truth_payload["comms_queue"] = temporal_truth.classify_comms_queue(
            spine,
            {
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
        )
    except Exception:
        temporal_truth_payload["comms_queue"] = {}
    try:
        temporal_truth_payload["daemons"] = temporal_truth.classify_daemons(spine, daemons_summary)
    except Exception:
        temporal_truth_payload["daemons"] = {}

# ── Output ────────────────────────────────────────────────────────────────

if mode == "--json":
    print(json.dumps({
        "mode": "json",
        "strict": strict_mode,
        "open_loops": open_loops,
        "planned_loops": planned_loops,
        "terminal_telemetry": terminal_telemetry_summary,
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
        "projection_residue": {
            "stale_scope_files": int(joined_state_summary.get("projection_residue", 0) or 0),
            "loops": joined_state_projection_residue,
        },
        "coherence_summary": joined_state_summary,
        "daemons": daemons_summary,
        "temporal_truth": temporal_truth_payload,
        "standing_program_health": standing_program_health,
        "delegations": delegation_summary,
        "execution_lane_truth": {
            "mailroom_execution": "capability_backed",
            "agent_tool_bridge": "deferred",
            "interactive_delegation": "explicit_worker_pickup_required",
            "autonomous_ai_agent_lane": "not_delivered",
        },
        "counts": {
            # Direct SQLite-backed open loops are authoritative for loop count.
            # Joined-state may enrich the rows, but it must not widen the set.
            "open_loops": len(open_loops),
            "projection_residue": int(joined_state_summary.get("projection_residue", 0) or 0),
            "mapped_open_loops": mapped_open_loops,
            "standing_programs_total": int((standing_program_health.get("summary") or {}).get("total", 0) or 0),
            "standing_programs_healthy": int((standing_program_health.get("summary") or {}).get("healthy", 0) or 0),
            "standing_programs_degraded": sum(
                int((standing_program_health.get("summary") or {}).get(key, 0) or 0)
                for key in ("stale", "failed", "unreachable", "never_run", "unknown")
            ),
            "fresh_terminals": len(fresh_terminals),
            "fresh_custody_terminals": len(fresh_custody_terminals),
            "active_delegations": int(delegation_summary.get("active", 0) or 0),
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
    projection_residue = int(joined_state_summary.get("projection_residue", 0) or 0)
    if projection_residue:
        parts.append(f"Residue: {projection_residue} stale scope file(s)")
    if gaps_available:
        parts.append(f"Gaps: {open_gap_count} open ({unlinked_gap_count} unlinked)")
    else:
        parts.append("Gaps: unknown (authority degraded)")
    if joined_state_summary.get("active_waves") is not None:
        parts.append(
            f"Waves: {joined_state_summary.get('active_waves', 0)} active / {joined_state_summary.get('orphaned_waves', 0)} orphaned"
        )
    _engine_vs = joined_state_summary.get("engine_verify_status", "unknown")
    _spine_vs = joined_state_summary.get("spine_verify_status", "unknown")
    _secondary_vs = joined_state_summary.get("secondary_verify_status", "unknown")
    parts.append(f"Engine: {_engine_vs} | Spine: {_spine_vs} | Secondary: {_secondary_vs}")
    if joined_state_summary.get("coherence_attention"):
        parts.append("Coherence: attention")
    if inbox_actionable:
        parts.append(f"Inbox: {inbox_actionable} actionable")
    if terminal_telemetry:
        parts.append(
            "Terminals:"
            f" {len(fresh_terminals)} fresh / {len(fresh_custody_terminals)} custody"
        )
        if terminal_telemetry_status != "ok":
            parts.append(f"Custody: {terminal_telemetry_status}")
    _sp_summary = standing_program_health.get("summary") if isinstance(standing_program_health.get("summary"), dict) else {}
    _sp_total = int(_sp_summary.get("total", 0) or 0)
    if _sp_total:
        _sp_healthy = int(_sp_summary.get("healthy", 0) or 0)
        _sp_degraded = sum(int(_sp_summary.get(key, 0) or 0) for key in ("stale", "failed", "unreachable", "never_run", "unknown"))
        parts.append(f"Standing: {_sp_healthy} healthy / {_sp_degraded} drift")
    _delegation_active = int(delegation_summary.get("active", 0) or 0)
    _delegation_stale = int(delegation_summary.get("stale", 0) or 0)
    if _delegation_active or _delegation_stale:
        if _delegation_active and _delegation_stale:
            parts.append(f"Delegations: {_delegation_active} active / {_delegation_stale} stale")
        elif _delegation_active:
            parts.append(f"Delegations: {_delegation_active} active")
        else:
            parts.append(f"Delegations: {_delegation_stale} stale")
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
print(f"  engine verify:      {joined_state_summary.get('engine_verify_status', 'unknown')}")
print(f"  spine verify:       {joined_state_summary.get('spine_verify_status', 'unknown')}")
print(f"  secondary verify:   {joined_state_summary.get('secondary_verify_status', 'unknown')}")
_verify_temporal = temporal_truth_payload.get("verify") or {}
if _verify_temporal.get("temporal_class"):
    _verify_line = str(_verify_temporal.get("temporal_class") or "")
    if _verify_temporal.get("known_since_utc"):
        _verify_line += f" since {_verify_temporal['known_since_utc']}"
    _standing_count = int(_verify_temporal.get("standing_evidence_count", 0) or 0)
    if _standing_count:
        _verify_line += f" ({_standing_count} corroborating receipt(s))"
    print(f"  verify standing:    {_verify_line}")
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

if terminal_telemetry:
    print("TERMINAL TELEMETRY")
    print("-" * 72)
    print(f"  status:             {terminal_telemetry_status}")
    print(f"  fresh terminals:    {len(fresh_terminals)}")
    print(f"  fresh custody:      {len(fresh_custody_terminals)}")
    print(f"  mapped open loops:  {mapped_open_loops}/{len(open_loops)}")
    print(f"  observed terminals: {len(terminal_telemetry)} (last {terminal_observation_window_minutes // 60}h)")
    for term in terminal_telemetry[:6]:
        term_bits = []
        if term.get("liveness_fresh"):
            term_bits.append("live")
        elif term.get("last_heartbeat_utc"):
            term_bits.append("stale-live")
        if term.get("last_capability"):
            term_bits.append(f"cap={term['last_capability']}")
        if term.get("custody_fresh"):
            term_bits.append("custody")
        elif term.get("custody_heartbeat_at") or term.get("custody_expires_at"):
            term_bits.append("stale-custody")
        if term.get("loop_id"):
            term_bits.append(f"loop={term['loop_id']}")
        if term.get("branch"):
            term_bits.append(f"branch={term['branch']}")
        print(f"  {term['terminal_id']:18s} {' | '.join(term_bits) if term_bits else 'observed'}")
    print()

_sp_summary = standing_program_health.get("summary") if isinstance(standing_program_health.get("summary"), dict) else {}
_sp_total = int(_sp_summary.get("total", 0) or 0)
if _sp_total:
    print("STANDING PROGRAMS")
    print("-" * 72)
    print(f"  status:             {standing_program_health.get('status', 'unknown')}")
    print(f"  total:              {_sp_total}")
    print(f"  healthy:            {int(_sp_summary.get('healthy', 0) or 0)}")
    print(f"  stale:              {int(_sp_summary.get('stale', 0) or 0)}")
    print(f"  failed:             {int(_sp_summary.get('failed', 0) or 0)}")
    print(f"  unreachable:        {int(_sp_summary.get('unreachable', 0) or 0)}")
    print(f"  never run:          {int(_sp_summary.get('never_run', 0) or 0)}")
    print(f"  unknown:            {int(_sp_summary.get('unknown', 0) or 0)}")
    print(f"  interventions:      {int(standing_program_health.get('active_interventions', 0) or 0)} active")
    _problem_programs = [
        item for item in standing_program_health.get("programs", [])
        if isinstance(item, dict) and str(item.get("health") or "") not in ("healthy", "")
    ]
    for item in _problem_programs[:6]:
        label = str(item.get("label") or "?").strip()
        health = str(item.get("health") or "unknown").strip()
        detail = str(item.get("detail") or "").strip()
        print(f"  {label:30s} {health:12s} {detail}")
    print()

if int(delegation_summary.get("count", 0) or 0):
    print("DELEGATIONS")
    print("-" * 72)
    print(f"  total:              {int(delegation_summary.get('count', 0) or 0)}")
    print(f"  active:             {int(delegation_summary.get('active', 0) or 0)}")
    print(f"  stale:              {int(delegation_summary.get('stale', 0) or 0)}")
    for state_name in ("delegated", "picked_up", "executing", "needs_review", "landed", "cancelled"):
        state_count = int((delegation_summary.get('by_state') or {}).get(state_name, 0) or 0)
        if state_count:
            print(f"  {state_name:18s} {state_count}")
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

# ── Daemon load truth ──
_daemon_temporal = temporal_truth_payload.get("daemons") or {}
if daemons_summary.get("missing") or daemons_summary.get("non_local_deferred"):
    print("DAEMON LOAD (ESTATE-WIDE)")
    print("-" * 72)
    print(f"  local role:        {daemons_summary.get('local_role', 'unknown')}")
    _missing_count = daemons_summary.get('missing', 0)
    print(f"  local missing:     {_missing_count}")
    _missing_labels = daemons_summary.get('missing_labels', [])
    if _missing_labels:
        for _ml in _missing_labels:
            print(f"    - {_ml}")
    print(f"  non-local deferred:{len(daemons_summary.get('non_local_deferred', []))}")
    if _daemon_temporal.get("temporal_class"):
        print(f"  temporal class:    {_daemon_temporal.get('temporal_class', '')}")
    _breakdown = daemons_summary.get("non_local_breakdown", {}) if isinstance(daemons_summary.get("non_local_breakdown"), dict) else {}
    print(
        "  breakdown:         "
        f"elsewhere={len(_breakdown.get('active_elsewhere', []))} "
        f"parked={len(_breakdown.get('parked_required', []))} "
        f"locality_exempt={len(_breakdown.get('locality_exempt', []))}"
    )
    if _daemon_temporal.get("operator_treatment"):
        print(f"  read:              {_daemon_temporal.get('operator_treatment', '')}")
    print()

_node_roles = daemons_summary.get("node_roles", {}) if isinstance(daemons_summary.get("node_roles"), dict) else {}
if _node_roles:
    print("NODE DELIVERY")
    print("-" * 72)
    _exec = _node_roles.get("execution_host", {}) if isinstance(_node_roles.get("execution_host"), dict) else {}
    _ver = _node_roles.get("verification_node", {}) if isinstance(_node_roles.get("verification_node"), dict) else {}
    _store = _node_roles.get("storage_evidence_node", {}) if isinstance(_node_roles.get("storage_evidence_node"), dict) else {}
    _control = _node_roles.get("control_node", {}) if isinstance(_node_roles.get("control_node"), dict) else {}
    _ver_prefix = "mapped_" if _ver.get("workload_counter_semantics") == "mapped_inventory" else ""
    _store_prefix = "mapped_" if _store.get("workload_counter_semantics") == "mapped_inventory" else ""
    print(
        "  execution_host:    "
        f"{_exec.get('posture', 'unknown')} · "
        f"active={int(_exec.get('active_workload_count', 0) or 0)} "
        f"intended={int(_exec.get('intended_workload_count', 0) or 0)} "
        f"parked={int(_exec.get('parked_workload_count', 0) or 0)}"
    )
    if _exec.get("target"):
        print(f"    target:           {_exec.get('target', '')}")
    print(
        "  verification_node: "
        f"{_ver.get('posture', 'unknown')} · "
        f"{_ver_prefix}intended={int(_ver.get('intended_workload_count', 0) or 0)}"
    )
    print(
        "  storage_evidence:  "
        f"{_store.get('posture', 'unknown')} · "
        f"{_store_prefix}active={int(_store.get('active_workload_count', 0) or 0)} "
        f"{_store_prefix}intended={int(_store.get('intended_workload_count', 0) or 0)}"
    )
    print(
        "  control_node:      "
        f"{_control.get('posture', 'unknown')} · "
        f"{'promoted' if _control.get('promoted') else 'not promoted'}"
    )
    print()

# ── Communications Queue ──
if comms_oneliner:
    print("COMMS QUEUE (SIDE SURFACE)")
    print("-" * 72)
    print("  not controller todo; communications drain state only")
    _comms_temporal = temporal_truth_payload.get("comms_queue") or {}
    if _comms_temporal.get("temporal_class"):
        print(f"  temporal class: {str(_comms_temporal.get('temporal_class') or '')}")
    if _comms_temporal.get("operator_treatment"):
        print(f"  read:           {str(_comms_temporal.get('operator_treatment') or '')}")
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
