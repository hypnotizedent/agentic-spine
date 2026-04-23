#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops wave - Manual wave lifecycle (surgery / explicit low-level control)
# ═══════════════════════════════════════════════════════════════════════════
#
# Low-level manual wave lifecycle for surgery, inspection, and explicit
# multi-terminal orchestration. Not the default operator work-start path.
#
# For bounded local work, use the canonical work-start surface:
#   ops dispatch local --loop-id <LOOP_ID> --objective "<text>" --lane "<name>:<cmd>"
#
# Usage:
#   ops wave start <WAVE_ID> --objective "<text>" [--loop-id <LOOP_ID>] [--deadline-utc <ISO8601>] [--horizon now|later|future] [--execution-readiness runnable|blocked] [--claimed-paths "a,b"] [--worktree auto|off] [--repo <path>]
#   ops wave dispatch <WAVE_ID> --lane <lane> --task "<text>" [--from-role <role>] [--to-role <role>] [--input-refs "k=v,..."] [--output-refs "k=v,..."]
#   ops wave collect <WAVE_ID>
#   ops wave status [WAVE_ID]
#   ops wave close <WAVE_ID> --disposition <state> [--completion-level <level>]
#   ops wave preflight <domain>
#   ops wave receipt-validate <path>
#
# Receipt artifacts: $RUNTIME_ROOT/waves/<WAVE_ID>/evidence/<task_id>.json
# State: $RUNTIME_ROOT/waves/<WAVE_ID>/state.json (runtime-only)
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

# Always resolve from script location — ignore ambient SPINE_REPO to prevent
# poisoned env vars from redirecting worktree execution to the primary checkout.
SPINE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPINE_PATHS_LIB="$SPINE_REPO/ops/lib/spine-paths.sh"
[[ -f "$SPINE_PATHS_LIB" ]] || { echo "FATAL: spine-paths.sh not found at $SPINE_PATHS_LIB" >&2; exit 1; }
source "$SPINE_PATHS_LIB"
spine_paths_init
RUNTIME_ROOT="$SPINE_RUNTIME_ROOT"
SPINE_STATE="$SPINE_STATE"
SPINE_OUTBOX="$SPINE_OUTBOX"
WAVES_DIR="$RUNTIME_ROOT/waves"
LANES_STATE="$RUNTIME_ROOT/lanes/state.json"
ROLE_RUNTIME_CONTRACT="$SPINE_REPO/ops/bindings/role.runtime.control.contract.yaml"
DISPOSITION_CONTRACT="$SPINE_REPO/ops/bindings/closeout.disposition.contract.yaml"
source "$SPINE_REPO/ops/lib/git-lock.sh" 2>/dev/null || true

mkdir -p "$WAVES_DIR"

# ── Helpers ──────────────────────────────────────────────────────────────

RUNTIME_ROLE_CONTROL_LOADED=0
PATH_CLAIMS_FILE="$SPINE_STATE/path.claims.yaml"
PATH_CLAIMS_TTL_MINUTES="180"
PATH_CLAIMS_NON_OVERLAP="true"
TRAFFIC_INDEX_FILE="$SPINE_STATE/traffic.index.yaml"
WAVE_START_CREATED_BRANCH=""
WAVE_START_CREATED_WORKTREE=""
WAVE_START_CREATED_REPO=""
WAVE_START_CREATED_STATEDIR=""
WAVE_START_CURRENT_WAVE_ID=""

_repo_abs_path() {
  local p="${1:-}"
  if [[ -z "$p" || "$p" == "null" ]]; then
    echo ""
    return
  fi
  # Resolve $SPINE_STATE references from contracts
  case "$p" in
    '$SPINE_STATE'/*) echo "${SPINE_STATE}/${p#\$SPINE_STATE/}"; return ;;
    '$SPINE_STATE')   echo "${SPINE_STATE}"; return ;;
  esac
  case "$p" in
    runtime/*|mailroom/*|evidence/*)
      if declare -F spine_resolve_mailroom_path >/dev/null 2>&1; then
        spine_resolve_mailroom_path "$p"
        return
      fi
      ;;
  esac
  if [[ "$p" = /* ]]; then
    echo "$p"
  else
    echo "$SPINE_REPO/$p"
  fi
}

resolve_wave_owner_terminal() {
  printf '%s\n' "${OPS_TERMINAL_ROLE:-${SPINE_TERMINAL_ROLE:-${SPINE_TERMINAL_NAME:-${SPINE_TERMINAL_ID:-${USER:-unknown}}}}}"
}

resolve_wave_terminal_identity() {
  printf '%s\n' "${OPS_TERMINAL_ROLE:-${SPINE_TERMINAL_ROLE:-${SPINE_TERMINAL_NAME:-${SPINE_TERMINAL_ID:-unknown}}}}"
}

resolve_wave_worktree_prefix() {
  local repo_path="${1:-$SPINE_REPO}"
  local lifecycle_contract="$SPINE_REPO/ops/bindings/worktree.lifecycle.contract.yaml"
  spine_canonical_worktree_prefix "$repo_path" "$lifecycle_contract"
}

wave_allowed_lanes_csv() {
  local csv="control,execution,audit,watcher"
  local parsed=""

  if command -v yq >/dev/null 2>&1 && [[ -f "$ROLE_RUNTIME_CONTRACT" ]]; then
    parsed="$(yq e -r '.lane_role_compatibility.allowed_runtime_roles_by_lane | keys | .[]' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null | paste -sd, -)"
    [[ -n "$parsed" ]] && csv="$parsed"
  fi

  printf '%s\n' "$csv"
}

wave_allowed_lanes_display() {
  wave_allowed_lanes_csv | tr ',' '|'
}

wave_require_valid_lane() {
  local lane="${1:-}"
  local allowed_csv=""
  local allowed_lane=""

  allowed_csv="$(wave_allowed_lanes_csv)"
  IFS=',' read -r -a allowed_lanes <<< "$allowed_csv"
  for allowed_lane in "${allowed_lanes[@]:-}"; do
    [[ "$lane" == "$allowed_lane" ]] && return 0
  done

  echo "FAIL: invalid wave lane '$lane' (allowed: $(wave_allowed_lanes_display))" >&2
  echo "" >&2
  echo "  'ops wave dispatch' uses fixed governance lanes ($(wave_allowed_lanes_display))." >&2
  echo "  For arbitrary named lanes like '$lane', use:" >&2
  echo "    ops dispatch local --lane \"$lane:<shell_command>\" ..." >&2
  exit 1
}

resolve_wave_claimed_paths() {
  local terminal_id="${1:-}"
  [[ -n "$terminal_id" ]] || return 0
  # Known controller terminals get a sensible default claimed path so wave start
  # does not require explicit --claimed-paths for single-terminal local dispatch.
  case "$terminal_id" in
    SPINE-CONTROL-*) printf 'ops\n'; return 0 ;;
  esac
  return 0
}

wave_start_reset_cleanup_state() {
  WAVE_START_CREATED_BRANCH=""
  WAVE_START_CREATED_WORKTREE=""
  WAVE_START_CREATED_REPO=""
  WAVE_START_CREATED_STATEDIR=""
  WAVE_START_CURRENT_WAVE_ID=""
}

wave_atomic_write_text_file() {
  local target="${1:?target path required}"
  local dir base tmp=""
  dir="$(dirname "$target")"
  base="$(basename "$target")"
  mkdir -p "$dir"
  tmp="$(mktemp "${dir}/.${base}.XXXXXX.tmp")"
  if ! cat > "$tmp"; then
    rm -f "$tmp" 2>/dev/null || true
    return 1
  fi
  if ! mv "$tmp" "$target"; then
    rm -f "$tmp" 2>/dev/null || true
    return 1
  fi
  tmp=""
  if [[ -n "$tmp" ]]; then
    rm -f "$tmp" 2>/dev/null || true
  fi
}

wave_start_cleanup_path_claims() {
  local wave_id="${WAVE_START_CURRENT_WAVE_ID:-}"
  [[ -n "$wave_id" ]] || return 0
  [[ -n "${PATH_CLAIMS_FILE:-}" && -f "${PATH_CLAIMS_FILE:-}" ]] || return 0

  python3 - "$PATH_CLAIMS_FILE" "$wave_id" <<'PYCLEANCLAIMS' 2>/dev/null || true
import json
import os
import sys
import tempfile

try:
    import yaml
except Exception:
    yaml = None

claims_path = sys.argv[1]
target_wave = sys.argv[2]
lock_path = claims_path + ".lock"

def _load_doc(path: str):
    if not path or not os.path.exists(path):
        return {}
    raw = open(path, "r", encoding="utf-8").read().strip()
    if not raw:
        return {}
    try:
        loaded = json.loads(raw)
        return loaded if isinstance(loaded, dict) else {}
    except Exception:
        if yaml is None:
            return {}
        try:
            loaded = yaml.safe_load(raw) or {}
            return loaded if isinstance(loaded, dict) else {}
        except Exception:
            return {}

def _atomic_write_json(path: str, payload: dict) -> None:
    dirpath = os.path.dirname(path) or "."
    os.makedirs(dirpath, exist_ok=True)
    fd_tmp = None
    tmp_path = None
    try:
        fd_tmp, tmp_path = tempfile.mkstemp(prefix=".state-", suffix=".tmp", dir=dirpath)
        with os.fdopen(fd_tmp, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
            fh.flush()
            os.fsync(fh.fileno())
        fd_tmp = None
        os.replace(tmp_path, path)
        tmp_path = None
    finally:
        if fd_tmp is not None:
            try:
                os.close(fd_tmp)
            except OSError:
                pass
        if tmp_path is not None:
            try:
                os.unlink(tmp_path)
            except FileNotFoundError:
                pass

fd = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o644)
try:
    import fcntl
    fcntl.flock(fd, fcntl.LOCK_EX)
    doc = _load_doc(claims_path)
    claims = doc.get("claims") if isinstance(doc.get("claims"), list) else []
    filtered = [
        claim for claim in claims
        if not (isinstance(claim, dict) and str(claim.get("wave_id", "")).strip() == target_wave)
    ]
    if len(filtered) != len(claims):
        doc["claims"] = filtered
        _atomic_write_json(claims_path, doc)
finally:
    try:
        fcntl.flock(fd, fcntl.LOCK_UN)
    except Exception:
        pass
    os.close(fd)
PYCLEANCLAIMS
}

wave_start_cleanup_on_exit() {
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    if [[ -n "${WAVE_START_CREATED_WORKTREE:-}" && -d "${WAVE_START_CREATED_WORKTREE:-}" && -n "${WAVE_START_CREATED_REPO:-}" ]]; then
      git -C "${WAVE_START_CREATED_REPO:-}" worktree remove --force "${WAVE_START_CREATED_WORKTREE:-}" 2>/dev/null || true
    fi
    if [[ -n "${WAVE_START_CREATED_BRANCH:-}" && -n "${WAVE_START_CREATED_REPO:-}" ]]; then
      git -C "${WAVE_START_CREATED_REPO:-}" branch -D "${WAVE_START_CREATED_BRANCH:-}" 2>/dev/null || true
    fi
    if [[ -n "${WAVE_START_CREATED_STATEDIR:-}" && -d "${WAVE_START_CREATED_STATEDIR:-}" ]]; then
      rm -rf "${WAVE_START_CREATED_STATEDIR:-}" 2>/dev/null || true
    fi
    wave_start_cleanup_path_claims
  fi
}

load_runtime_role_control() {
  if [[ "$RUNTIME_ROLE_CONTROL_LOADED" -eq 1 ]]; then
    return
  fi
  local path_claims_file="$SPINE_STATE/path.claims.yaml"
  local traffic_index_file="$SPINE_STATE/traffic.index.yaml"

  if command -v yq >/dev/null 2>&1 && [[ -f "$ROLE_RUNTIME_CONTRACT" ]]; then
    local raw_pc raw_ti
    raw_pc="$(yq e -r '.path_claims.state_file // ""' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || true)"
    PATH_CLAIMS_TTL_MINUTES="$(yq e -r '.path_claims.default_ttl_minutes // 180' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || echo 180)"
    PATH_CLAIMS_NON_OVERLAP="$(yq e -r '.path_claims.require_non_overlapping_active_claims // true' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || echo true)"
    raw_ti="$(yq e -r '.traffic_index.state_file // ""' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || true)"
    # Resolve contract paths: $SPINE_STATE refs, mailroom/state compat, or fallback
    [[ -n "$raw_pc" && "$raw_pc" != "null" ]] && path_claims_file="$(_repo_abs_path "$raw_pc")"
    [[ -n "$raw_ti" && "$raw_ti" != "null" ]] && traffic_index_file="$(_repo_abs_path "$raw_ti")"
  fi

  [[ "$PATH_CLAIMS_TTL_MINUTES" =~ ^[0-9]+$ ]] || PATH_CLAIMS_TTL_MINUTES="180"
  PATH_CLAIMS_FILE="${path_claims_file:-$SPINE_STATE/path.claims.yaml}"
  TRAFFIC_INDEX_FILE="${traffic_index_file:-$SPINE_STATE/traffic.index.yaml}"
  RUNTIME_ROLE_CONTROL_LOADED=1
}

close_dispositions_csv() {
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

require_close_disposition() {
  local disposition="${1:-}"
  local csv="${2:-$(close_dispositions_csv)}"
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

close_completion_levels_csv() {
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

require_close_completion_level() {
  local disposition="${1:-}"
  local completion_level="${2:-}"
  local allowed_csv="${3:-$(close_completion_levels_csv)}"
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

sync_runtime_traffic_index() {
  local sf="${1:-}"
  local mode="${2:-sync}"
  [[ -n "$sf" && -f "$sf" ]] || return 0
  load_runtime_role_control
  python3 - "$sf" "$TRAFFIC_INDEX_FILE" "$mode" <<'PYTRAFFIC'
import json
import os
import sys
import fcntl
import tempfile
from datetime import datetime, timezone

state_file = sys.argv[1]
index_file = sys.argv[2]
mode = sys.argv[3] if len(sys.argv) > 3 else "sync"
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

with open(state_file, "r", encoding="utf-8") as f:
    state = json.load(f)

packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
role_flow = state.get("role_flow") if isinstance(state.get("role_flow"), dict) else {}
if isinstance(role_flow, dict) and "next_role" in role_flow:
    next_role = str(role_flow.get("next_role") or "").strip()
else:
    next_role = str(packet.get("next_role") or "").strip()

entry = {
    "wave_id": str(state.get("wave_id", "")).strip(),
    "owner_terminal": str(packet.get("owner_terminal", "")).strip(),
    "current_role": str(role_flow.get("current_role") or packet.get("current_role") or "").strip(),
    "next_role": next_role,
    "deadline": str(packet.get("deadline_utc", "")).strip(),
    "status": str(state.get("status", "active")).strip() or "active",
    "claimed_paths": packet.get("claimed_paths") if isinstance(packet.get("claimed_paths"), list) else [],
    "blockers": [],
    "lifecycle_state": str(state.get("lifecycle_state", "")).strip(),
    "updated_at": now,
}

for dispatch in state.get("dispatches", []) if isinstance(state.get("dispatches"), list) else []:
    if not isinstance(dispatch, dict):
        continue
    status = str(dispatch.get("status", "")).strip()
    if status in {"blocked", "failed"}:
        entry["blockers"].append(
            {
                "dispatch_id": str(dispatch.get("task_id", "")).strip(),
                "status": status,
            }
        )

pf = state.get("preflight") if isinstance(state.get("preflight"), dict) else {}
if str(pf.get("verdict", "")).strip() == "no-go":
    for b in pf.get("blockers", []) if isinstance(pf.get("blockers"), list) else []:
        entry["blockers"].append({"source": "preflight", "status": "no-go", "detail": str(b)})

lock_file = f"{index_file}.lock"
os.makedirs(os.path.dirname(lock_file), exist_ok=True)
fd = os.open(lock_file, os.O_CREAT | os.O_RDWR, 0o644)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)

    index = {"schema_version": "1.0", "updated_at": now, "items": []}
    if os.path.exists(index_file):
        raw = open(index_file, "r", encoding="utf-8").read().strip()
        if raw:
            try:
                loaded = json.loads(raw)
                if isinstance(loaded, dict):
                    index.update(loaded)
            except Exception:
                try:
                    import yaml
                    loaded = yaml.safe_load(raw) or {}
                    if isinstance(loaded, dict):
                        index.update(loaded)
                except Exception:
                    pass

    items = index.get("items")
    if not isinstance(items, list):
        items = []

    wave_id = entry["wave_id"]
    items = [i for i in items if not (isinstance(i, dict) and str(i.get("wave_id", "")).strip() == wave_id)]
    items.append(entry)
    items.sort(key=lambda i: str(i.get("wave_id", "")))

    index["schema_version"] = "1.0"
    index["updated_at"] = now
    index["last_mode"] = mode
    index["items"] = items

    os.makedirs(os.path.dirname(index_file), exist_ok=True)
    with open(index_file, "w", encoding="utf-8") as f:
        json.dump(index, f, indent=2)
        f.write("\n")
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)
PYTRAFFIC
}

release_wave_path_claims() {
  local wave_id="${1:-}"
  local claim_status="${2:-released}"
  [[ -n "$wave_id" ]] || return 0
  load_runtime_role_control
  python3 - "$PATH_CLAIMS_FILE" "$wave_id" "$claim_status" <<'PYPATHRELEASE'
import json
import os
import sys
import fcntl
import tempfile
from datetime import datetime, timezone

claims_file = sys.argv[1]
wave_id = sys.argv[2]
claim_status = sys.argv[3]
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

lock_file = f"{claims_file}.lock"
os.makedirs(os.path.dirname(lock_file), exist_ok=True)
fd = os.open(lock_file, os.O_CREAT | os.O_RDWR, 0o644)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)

    doc = {"schema_version": "1.0", "updated_at": now, "claims": []}
    if os.path.exists(claims_file):
        raw = open(claims_file, "r", encoding="utf-8").read().strip()
        if raw:
            try:
                loaded = json.loads(raw)
                if isinstance(loaded, dict):
                    doc.update(loaded)
            except Exception:
                try:
                    import yaml
                    loaded = yaml.safe_load(raw) or {}
                    if isinstance(loaded, dict):
                        doc.update(loaded)
                except Exception:
                    pass

    claims = doc.get("claims")
    if not isinstance(claims, list):
        claims = []

    for claim in claims:
        if not isinstance(claim, dict):
            continue
        if str(claim.get("wave_id", "")).strip() != wave_id:
            continue
        if str(claim.get("status", "")).strip() != "active":
            continue
        claim["status"] = claim_status
        claim["released_at"] = now

    doc["schema_version"] = "1.0"
    doc["updated_at"] = now
    doc["claims"] = claims
    os.makedirs(os.path.dirname(claims_file), exist_ok=True)
    with open(claims_file, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)
PYPATHRELEASE
}

reconcile_wave_path_claims() {
  local wave_id_filter="${1:-}"
  local output_mode="${2:-text}"
  load_runtime_role_control
  python3 - "$PATH_CLAIMS_FILE" "$WAVES_DIR" "$wave_id_filter" "$output_mode" <<'PYPATHRECONCILE'
import json
import os
import sys
import fcntl
import tempfile
from datetime import datetime, timezone

claims_file = sys.argv[1]
waves_dir = sys.argv[2]
wave_id_filter = sys.argv[3] if len(sys.argv) > 3 else ""
output_mode = sys.argv[4] if len(sys.argv) > 4 else "text"
now_dt = datetime.now(timezone.utc)
now = now_dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def _load_doc(path: str) -> dict:
    payload = {"schema_version": "1.0", "updated_at": now, "claims": []}
    if not path or not os.path.exists(path):
        return payload
    raw = open(path, "r", encoding="utf-8").read().strip()
    if not raw:
        return payload
    try:
        loaded = json.loads(raw)
        if isinstance(loaded, dict):
            payload.update(loaded)
            return payload
    except Exception:
        pass
    try:
        import yaml

        loaded = yaml.safe_load(raw) or {}
        if isinstance(loaded, dict):
            payload.update(loaded)
    except Exception:
        pass
    return payload


def _save_doc(path: str, payload: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    _atomic_write_json(path, payload)


def _atomic_write_json(path: str, payload: dict) -> None:
    dirpath = os.path.dirname(path) or "."
    os.makedirs(dirpath, exist_ok=True)
    fd_tmp = None
    tmp_path = None
    try:
        fd_tmp, tmp_path = tempfile.mkstemp(prefix=".state-", suffix=".tmp", dir=dirpath)
        with os.fdopen(fd_tmp, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
            fh.flush()
            os.fsync(fh.fileno())
        fd_tmp = None
        os.replace(tmp_path, path)
        tmp_path = None
    finally:
        if fd_tmp is not None:
            try:
                os.close(fd_tmp)
            except OSError:
                pass
        if tmp_path is not None:
            try:
                os.unlink(tmp_path)
            except FileNotFoundError:
                pass


def _parse_iso(raw: str):
    text = str(raw or "").strip()
    if not text:
        return None
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00"))
    except Exception:
        return None


def _normalize_path(raw: str) -> str:
    text = str(raw or "").strip()
    if not text:
        return ""
    if text == ".":
        return "."
    while text.startswith("./"):
        text = text[2:]
    text = text.rstrip("/")
    return text or "."


def _normalize_paths(items):
    out = []
    seen = set()
    for item in items if isinstance(items, list) else []:
        normalized = _normalize_path(str(item))
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        out.append(normalized)
    return out


def _load_wave_state(wave_id: str):
    if not wave_id:
        return None
    state_path = os.path.join(waves_dir, wave_id, "state.json")
    if not os.path.exists(state_path):
        return None
    try:
        return json.load(open(state_path, "r", encoding="utf-8"))
    except Exception:
        return None


def _sync_wave_claim_state(wave_id: str, state: dict, claim: dict, action: str, reason: str) -> None:
    if not isinstance(state, dict):
        return
    state_path = os.path.join(waves_dir, wave_id, "state.json")
    if not state_path or not os.path.exists(state_path):
        return

    packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
    reconciled_paths = claim.get("claimed_paths") if isinstance(claim.get("claimed_paths"), list) else []
    if action == "resynced":
        packet["claimed_paths"] = reconciled_paths
    else:
        packet["claimed_paths"] = []

    state["packet"] = packet

    claim_state = state.get("path_claims") if isinstance(state.get("path_claims"), dict) else {}
    claim_state["status"] = "active" if action == "resynced" else action
    claim_state["claim_id"] = str(claim.get("claim_id", "")).strip()
    claim_state["claimed_paths"] = packet.get("claimed_paths", [])
    claim_state["reconciled_at"] = now
    claim_state["reconciled_reason"] = reason
    if action == "resynced":
        claim_state["expires_at"] = str(claim.get("expires_at", "")).strip()
        claim_state.pop("expired_at", None)
        claim_state.pop("released_at", None)
    elif action == "expired":
        claim_state["expired_at"] = now
        claim_state.pop("released_at", None)
    elif action == "released":
        claim_state["released_at"] = now
        claim_state.pop("expired_at", None)
    state["path_claims"] = claim_state

    wave_lock_file = state_path + ".lock"
    os.makedirs(os.path.dirname(wave_lock_file), exist_ok=True)
    wave_fd = os.open(wave_lock_file, os.O_CREAT | os.O_RDWR, 0o644)
    try:
        fcntl.flock(wave_fd, fcntl.LOCK_EX)
        _atomic_write_json(state_path, state)
    finally:
        fcntl.flock(wave_fd, fcntl.LOCK_UN)
        os.close(wave_fd)


summary = {
    "claims_file": claims_file,
    "target_wave_id": wave_id_filter or None,
    "scanned": 0,
    "updated": 0,
    "expired": 0,
    "released": 0,
    "resynced": 0,
    "unchanged": 0,
}
changes = []

lock_file = f"{claims_file}.lock"
os.makedirs(os.path.dirname(lock_file), exist_ok=True)
fd = os.open(lock_file, os.O_CREAT | os.O_RDWR, 0o644)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)

    doc = _load_doc(claims_file)
    claims = doc.get("claims")
    if not isinstance(claims, list):
        claims = []

    for claim in claims:
        if not isinstance(claim, dict):
            continue
        summary["scanned"] += 1
        wave_id = str(claim.get("wave_id", "")).strip()
        if wave_id_filter and wave_id != wave_id_filter:
            continue

        status = str(claim.get("status", "active")).strip() or "active"
        if status != "active":
            summary["unchanged"] += 1
            continue

        original_paths = _normalize_paths(claim.get("claimed_paths"))
        wave_state = _load_wave_state(wave_id)
        wave_packet = wave_state.get("packet") if isinstance(wave_state, dict) and isinstance(wave_state.get("packet"), dict) else {}
        wave_paths = _normalize_paths(wave_packet.get("claimed_paths"))
        wave_status = str(wave_state.get("status", "")).strip() if isinstance(wave_state, dict) else ""
        lifecycle_state = str(wave_state.get("lifecycle_state", "")).strip() if isinstance(wave_state, dict) else ""
        expires_at = _parse_iso(str(claim.get("expires_at", "")).strip())

        reason = ""
        action = ""
        if expires_at is not None and expires_at <= now_dt:
          reason = "ttl_expired"
          action = "expired"
        elif not original_paths:
          reason = "claim_scope_missing"
          action = "expired"
        elif wave_state is None:
          reason = "wave_state_missing"
          action = "expired"
        elif wave_status and wave_status != "active":
          reason = f"wave_status_{wave_status}"
          action = "released"
        elif lifecycle_state == "closed":
          reason = "wave_lifecycle_closed"
          action = "released"
        elif not wave_paths:
          reason = "wave_scope_missing"
          action = "expired"
        elif original_paths != wave_paths:
          reason = "wave_scope_sync"
          action = "resynced"

        if not action:
            summary["unchanged"] += 1
            continue

        claim["reconciled_at"] = now
        claim["reconciled_reason"] = reason
        if action == "expired":
            claim["status"] = "expired"
            claim["expired_at"] = now
            summary["expired"] += 1
        elif action == "released":
            claim["status"] = "released"
            claim["released_at"] = now
            summary["released"] += 1
        elif action == "resynced":
            claim["claimed_paths"] = wave_paths
            summary["resynced"] += 1

        if isinstance(wave_state, dict):
            _sync_wave_claim_state(wave_id, wave_state, claim, action, reason)

        summary["updated"] += 1
        changes.append(
            {
                "claim_id": str(claim.get("claim_id", "")).strip(),
                "wave_id": wave_id,
                "action": action,
                "reason": reason,
                "claimed_paths": claim.get("claimed_paths") if isinstance(claim.get("claimed_paths"), list) else [],
            }
        )

    doc["schema_version"] = "1.0"
    doc["updated_at"] = now
    doc["claims"] = claims
    _save_doc(claims_file, doc)
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)

payload = {
    "capability": "orchestration.wave.claims.reconcile",
    "status": "done",
    "generated_at": now,
    "summary": summary,
    "changes": changes,
}

if output_mode == "json":
    print(json.dumps(payload, indent=2))
elif output_mode == "quiet":
    pass
else:
    print("wave.claims.reconcile")
    print(f"claims_file: {claims_file}")
    if wave_id_filter:
        print(f"wave_id: {wave_id_filter}")
    print(f"scanned: {summary['scanned']}")
    print(f"updated: {summary['updated']}")
    print(f"expired: {summary['expired']}")
    print(f"released: {summary['released']}")
    print(f"resynced: {summary['resynced']}")
    print(f"unchanged: {summary['unchanged']}")
PYPATHRECONCILE
}

wave_state_dir() {
  echo "$WAVES_DIR/${1:?wave_id required}"
}

wave_state_file() {
  echo "$(wave_state_dir "$1")/state.json"
}

ensure_wave_exists() {
  local wave_id="$1"
  local sf
  sf="$(wave_state_file "$wave_id")"
  if [[ ! -f "$sf" ]]; then
    echo "Wave '$wave_id' does not exist. Create with: ops wave start $wave_id --objective \"...\"" >&2
    exit 1
  fi
}

wave_lock_guard() {
  local wave_id="${1:-}"
  local action="${2:-}"
  local override_reason="${3:-}"
  local lock_file

  [[ -n "$wave_id" && -n "$action" ]] || return 0
  lock_file="$(wave_state_dir "$wave_id")/wave.lock"
  [[ -f "$lock_file" ]] || return 0

  python3 - "$lock_file" "$action" "$override_reason" <<'PYWAVELOCK'
import json
import os
import sys

lock_file = sys.argv[1]
action = (sys.argv[2] or "").strip()
override_reason = (sys.argv[3] or "").strip()

raw = open(lock_file, "r", encoding="utf-8").read().strip()
if not raw:
    raise SystemExit(0)

doc = {}
try:
    doc = json.loads(raw)
except Exception:
    try:
        import yaml
        doc = yaml.safe_load(raw) or {}
    except Exception as exc:
        print(f"FAIL: unable to parse wave lock file {lock_file}: {exc}", file=sys.stderr)
        raise SystemExit(1)

if not isinstance(doc, dict):
    raise SystemExit(0)

enforce = bool(doc.get("enforce", True))
if not enforce:
    raise SystemExit(0)

blocked_actions = doc.get("blocked_actions")
if not isinstance(blocked_actions, list) or not blocked_actions:
    blocked_actions = ["dispatch", "ack", "close"]

blocked_actions = {str(x).strip() for x in blocked_actions if str(x).strip()}
if action not in blocked_actions:
    raise SystemExit(0)

reason = str(doc.get("reason", "")).strip()
if not override_reason:
    detail = f" ({reason})" if reason else ""
    print(
        f"FAIL: wave lock enforcement blocked action '{action}'{detail}. "
        f"Retry with --lock-override \"<reason>\" to bypass explicitly.",
        file=sys.stderr,
    )
    raise SystemExit(1)

print(
    f"WARNING: wave lock override accepted for action '{action}' "
    f"reason='{override_reason}'",
    file=sys.stderr,
)
PYWAVELOCK
}

ts_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

wave_path_policy_block() {
  local detail="${1:-unknown path policy violation}"
  local allowed_prefix=""
  allowed_prefix="$(resolve_wave_worktree_prefix "$SPINE_REPO")"
  cat >&2 <<EOF
WORKTREE PATH POLICY BLOCK: $detail
Allowed wave worktree path: ${allowed_prefix}<WAVE_ID>
Remediation:
  ./bin/ops wave start <WAVE_ID> --objective "<objective>" --repo ${SPINE_REPO}
  ./bin/ops cap run worktree.lifecycle.rehydrate -- --branch codex/<WAVE_ID> --lane <WAVE_ID> --repo ${SPINE_REPO}
EOF
  exit 1
}

# ── Subcommands ──────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
ops wave - Manual wave lifecycle with lane-aware dispatch

Usage:
  ops wave start <WAVE_ID> --objective "<text>" [--loop-id <LOOP_ID>] [--deadline-utc <ISO8601>] [--horizon now|later|future] [--execution-readiness runnable|blocked] [--claimed-paths "a,b"] [--worktree auto|off] [--repo <path>]
                                                    Create a new wave (default auto worktree)
  ops wave dispatch <WAVE_ID> --lane <L> --task "T" [--from-role <R>] [--to-role <R>] [--input-refs "k=v,..."] [--output-refs "k=v,..."] [--lock-override "<reason>"]  Dispatch task to a lane
  ops wave ack <WAVE_ID> --lane <L> --result "text" [--lock-override "<reason>"]  Acknowledge task completion
  ops wave collect <WAVE_ID>                         Collect results from lanes
  ops wave status [WAVE_ID]                          Show wave status (or all)
  ops wave claims-reconcile [--wave-id <WAVE_ID>] [--json]
                                                    Reconcile stale path claims against TTL and live wave state
  ops wave close <WAVE_ID> --disposition <state> [--completion-level <level>] [--force] [--dod-override "<reason>"] [--lock-override "<reason>"]  Close a wave
  ops wave preflight <domain>                        Fast non-blocking preflight
  ops wave receipt-validate <path>                   Validate EXEC_RECEIPT JSON
  ops wave emit-agent-receipt <WAVE_ID> --lane <L>|--dispatch D<N> --result "<text>" [--file-read <p>]... [--run-key <key>]... [--commit-ref <sha>]... [--loop-id <LOOP_ID>] [--completion-level <level>] [--task-id <id>]
                                                    Bridge: emit worker-class EXEC_RECEIPT JSON for an in-band Agent-tool subagent result
  ops wave residue [--sweep] [--json]                Canonical wave-owned residue surface (report-only by default; --sweep is bounded)

Ownership:
  ops wave manages the manual wave lifecycle.
  For the convenience wrapper that creates and runs a local dispatch wave, use:
    ops dispatch local --loop-id <LOOP_ID> --objective "<text>" --lane "<name>:<shell_command>"

Wave IDs: use WAVE-YYYYMMDD-NN format (e.g. WAVE-20260222-01)

EXEC_RECEIPT Artifacts:
  Workers emit JSON receipts to $RUNTIME_ROOT/waves/<WAVE_ID>/evidence/.
  Use receipt-validate to check schema compliance before collect.

Background Watcher:
  The watcher lane auto-enqueues long checks (stability.control.snapshot,
  verify.infra.run, verify.pack.run) and tracks them without blocking.
  Results appear in 'ops wave status' when complete.
EOF
}

wave_start_usage() {
  echo "Usage: ops wave start <WAVE_ID> --objective \"<text>\" [--loop-id <LOOP_ID>] [--prior-wave <WAVE_ID>] [--deadline-utc <ISO8601>] [--horizon now|later|future] [--execution-readiness runnable|blocked] [--claimed-paths \"a,b\"] [--worktree auto|off] [--repo <path>]" >&2
}

wave_start_fail_legacy_loop_flag() {
  local bad_flag="$1"
  echo "Unknown flag: $bad_flag" >&2
  echo "Hint: ops wave start requires a positional <WAVE_ID> and uses canonical --loop-id." >&2
  echo "Example: ops wave start WAVE-20260408-03 --objective \"demo\" --loop-id LOOP-EXAMPLE" >&2
  exit 1
}

cmd_start() {
  local wave_id=""
  local objective=""
  local loop_id=""
  local prior_wave_id=""
  local deadline_utc=""
  local horizon="now"
  local execution_readiness="runnable"
  local owner_terminal
  owner_terminal="$(resolve_wave_owner_terminal)"
  local claimed_paths_raw=""
  local packet_required_fields="wave_id,loop_id,owner_terminal,current_role,next_role,deadline_utc,horizon,execution_readiness,claimed_paths"
  local packet_default_deadline_hours="24"
  local packet_allowed_horizon="now,later,future"
  local packet_allowed_readiness="runnable,blocked"
  local packet_allowed_roles="researcher,worker,qc,close,librarian"
  local worktree_mode="auto"
  local workspace_repo="$SPINE_REPO"
  local workspace_enabled="false"
  local workspace_branch=""
  local workspace_worktree=""
  local workspace_note=""
  local default_role="researcher"
  local default_next_role="worker"
  local current_role_explicit=0
  local next_role_explicit=0
  local wave_kind="production"
  load_runtime_role_control

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --objective) objective="${2:-}"; shift 2 ;;
      --loop-id) loop_id="${2:-}"; shift 2 ;;
      --prior-wave) prior_wave_id="${2:-}"; shift 2 ;;
      --loop) wave_start_fail_legacy_loop_flag "$1" ;;
      --deadline-utc) deadline_utc="${2:-}"; shift 2 ;;
      --horizon) horizon="${2:-}"; shift 2 ;;
      --execution-readiness) execution_readiness="${2:-}"; shift 2 ;;
      --owner-terminal) owner_terminal="${2:-}"; shift 2 ;;
      --claimed-paths) claimed_paths_raw="${2:-}"; shift 2 ;;
      --current-role) default_role="${2:-}"; current_role_explicit=1; shift 2 ;;
      --next-role) default_next_role="${2:-}"; next_role_explicit=1; shift 2 ;;
      --worktree) worktree_mode="${2:-}"; shift 2 ;;
      --repo) workspace_repo="${2:-}"; shift 2 ;;
      --synthetic) wave_kind="synthetic"; shift ;;
      --wave-kind) wave_kind="${2:-}"; shift 2 ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) wave_id="$1"; shift ;;
    esac
  done

  if [[ -z "$wave_id" ]]; then
    wave_start_usage
    exit 1
  fi
  WAVE_START_CURRENT_WAVE_ID="$wave_id"
  if [[ "$worktree_mode" != "auto" && "$worktree_mode" != "off" ]]; then
    echo "Usage: --worktree must be auto or off (got: $worktree_mode)" >&2
    exit 1
  fi
  case "$wave_kind" in
    production|synthetic|engineering) ;;
    *)
      echo "FAIL: invalid wave kind '$wave_kind' (allowed: production|synthetic|engineering)" >&2
      exit 1
      ;;
  esac

  # Track artifacts for rollback on failure (GAP-OP-1491, GAP-OP-1585).
  wave_start_reset_cleanup_state
  trap wave_start_cleanup_on_exit EXIT

  local sd
  sd="$(wave_state_dir "$wave_id")"
  local sf="$sd/state.json"

  if [[ -f "$sf" ]]; then
    echo "Wave '$wave_id' already exists." >&2
    exit 1
  fi

  if command -v yq >/dev/null 2>&1 && [[ -f "$ROLE_RUNTIME_CONTRACT" ]]; then
    packet_default_deadline_hours="$(yq e -r '.wave_packet.default_deadline_hours // 24' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || echo 24)"
    packet_required_fields="$(yq e -r '.wave_packet.required_fields[]?' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null | paste -sd, -)"
    [[ -n "$packet_required_fields" ]] || packet_required_fields="wave_id,loop_id,owner_terminal,current_role,next_role,deadline_utc,horizon,execution_readiness,claimed_paths"
    packet_allowed_horizon="$(yq e -r '.wave_packet.allowed_horizon[]?' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null | paste -sd, -)"
    [[ -n "$packet_allowed_horizon" ]] || packet_allowed_horizon="now,later,future"
    packet_allowed_readiness="$(yq e -r '.wave_packet.allowed_readiness[]?' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null | paste -sd, -)"
    [[ -n "$packet_allowed_readiness" ]] || packet_allowed_readiness="runnable,blocked"
    packet_allowed_roles="$(yq e -r '.runtime_roles.canonical[]?' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null | paste -sd, -)"
    [[ -n "$packet_allowed_roles" ]] || packet_allowed_roles="researcher,worker,qc,close,librarian"
    if [[ "$current_role_explicit" -eq 0 ]]; then
      default_role="$(yq e -r '.runtime_roles.default_role // "researcher"' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || echo researcher)"
    fi
    if [[ -n "$default_role" && "$default_role" != "null" ]]; then
      local resolved_next
      resolved_next="$(yq e -r ".promotion_gates.transitions[]? | select(.from == \"$default_role\") | .to" "$ROLE_RUNTIME_CONTRACT" 2>/dev/null | head -n1 || true)"
      if [[ "$next_role_explicit" -eq 0 && -n "$resolved_next" && "$resolved_next" != "null" ]]; then
        default_next_role="$resolved_next"
      fi
    fi
  fi

  if [[ -z "$loop_id" ]]; then
    if [[ -n "${SPINE_LOOP_ID:-}" ]]; then
      loop_id="$SPINE_LOOP_ID"
    else
      echo "FAIL: no loop_id resolved for wave '$wave_id'." >&2
      echo "  → Pass --loop-id LOOP-ID, or set SPINE_LOOP_ID." >&2
      echo "  → Create a loop first: ./bin/ops cap run loops.create -- --name \"$wave_id\" --objective \"...\"" >&2
      exit 1
    fi
  fi

  # Gate: refuse to attach a wave to a closed loop
  local _loop_scope_file="$SPINE_STATE/loop-scopes/${loop_id}.scope.md"
  local _loop_archive_file="$SPINE_STATE/archive/closed-loop-scopes/${loop_id}.scope.md"
  if [[ ! -f "$_loop_scope_file" && -f "$_loop_archive_file" ]]; then
    echo "FAIL: loop '$loop_id' is closed (archived). Cannot attach a new wave to a closed loop." >&2
    echo "  → Create a new loop: ./bin/ops cap run loops.create -- --name \"...\" --objective \"...\"" >&2
    exit 1
  fi

  [[ -n "$deadline_utc" ]] || deadline_utc="$(python3 - "$packet_default_deadline_hours" <<'PYDEADLINE'
import datetime as dt
import sys

hours = 24
try:
    hours = int(sys.argv[1])
except Exception:
    hours = 24
deadline = dt.datetime.now(dt.timezone.utc) + dt.timedelta(hours=max(1, hours))
print(deadline.strftime("%Y-%m-%dT%H:%M:%SZ"))
PYDEADLINE
)"
  [[ -n "$claimed_paths_raw" ]] || claimed_paths_raw="$(resolve_wave_claimed_paths "$owner_terminal")"
  if [[ -z "$claimed_paths_raw" ]]; then
    echo "FAIL: not in a governed terminal (OPS_TERMINAL_ROLE='$owner_terminal' has no claimed paths)." >&2
    echo "  Run: ops cap run session.v3.attach" >&2
    echo "  Or pass --claimed-paths explicitly." >&2
    exit 1
  fi

  # Synthetic waves use an isolated claim namespace so honesty probes
  # never collide with real active waves on the same terminal.
  if [[ "$wave_kind" == "synthetic" ]]; then
    claimed_paths_raw="__synthetic__/${wave_id}"
  fi

  reconcile_wave_path_claims "" "quiet"

  mkdir -p "$sd"
  WAVE_START_CREATED_STATEDIR="$sd"

  if [[ "$worktree_mode" == "auto" ]]; then
    workspace_repo="$(spine_git_common_root "$workspace_repo")"
    if [[ -z "$workspace_repo" ]]; then
      echo "Wave '$wave_id' start blocked: --repo is not a git worktree path." >&2
      exit 1
    fi

    if command -v acquire_git_lock >/dev/null 2>&1; then
      acquire_git_lock wave || exit 1
    fi

    local default_branch
    local source_ref
    default_branch="$(git -C "$workspace_repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
    default_branch="${default_branch:-main}"
    source_ref="$(git -C "$workspace_repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
    if [[ -z "$source_ref" || "$source_ref" == "HEAD" ]]; then
      source_ref="$(git -C "$workspace_repo" rev-parse HEAD 2>/dev/null || echo "$default_branch")"
    fi

    local lifecycle_contract="$SPINE_REPO/ops/bindings/worktree.lifecycle.contract.yaml"
    local canonical_root="$HOME/.wt"
    local lease_filename=".spine-lane-lease.yaml"
    local lease_ttl_hours="24"
    local lease_owner="$owner_terminal"
    if command -v yq >/dev/null 2>&1 && [[ -f "$lifecycle_contract" ]]; then
      canonical_root="$(yq e -r '.policy.canonical_worktree_root // "~/.wt"' "$lifecycle_contract" 2>/dev/null || echo "$canonical_root")"
      lease_filename="$(yq e -r '.policy.lease_filename // ".spine-lane-lease.yaml"' "$lifecycle_contract" 2>/dev/null || echo "$lease_filename")"
      lease_ttl_hours="$(yq e -r '.policy.lease_ttl_hours_default // 24' "$lifecycle_contract" 2>/dev/null || echo "$lease_ttl_hours")"
    fi
    if [[ "$canonical_root" == "~/"* ]]; then
      canonical_root="$HOME/${canonical_root#~/}"
    fi

    git -C "$workspace_repo" fetch --prune origin "$default_branch" >/dev/null 2>&1 || true
    workspace_branch="codex/${wave_id}"
    local repo_name
    local enforced_worktree_prefix
    repo_name="$(basename "$workspace_repo")"
    enforced_worktree_prefix="$(resolve_wave_worktree_prefix "$workspace_repo")"
    workspace_worktree="$canonical_root/$repo_name/${wave_id}"
    [[ "$workspace_worktree" != *"/.worktrees/"* ]] || wave_path_policy_block "legacy .worktrees target denied: $workspace_worktree"
    [[ "$workspace_worktree" != "$workspace_repo" && "$workspace_worktree" != "$workspace_repo/"* ]] || wave_path_policy_block "main checkout target denied: $workspace_worktree"
    [[ "$workspace_worktree" == "${enforced_worktree_prefix}"* ]] || wave_path_policy_block "target '$workspace_worktree' is outside enforced prefix '$enforced_worktree_prefix'"
    [[ "$(basename "$workspace_worktree")" =~ ^WAVE-[A-Z0-9._-]+$ ]] || wave_path_policy_block "wave id '$wave_id' must match WAVE-... for managed worktree path"

    if ! git -C "$workspace_repo" show-ref --verify --quiet "refs/heads/$workspace_branch"; then
      git -C "$workspace_repo" branch "$workspace_branch" "$source_ref" >/dev/null
      WAVE_START_CREATED_BRANCH="$workspace_branch"
      WAVE_START_CREATED_REPO="$workspace_repo"
    fi

    local occupied_worktree=""
    occupied_worktree="$(python3 - "$workspace_repo" "$workspace_branch" <<'PYOCCUPIED'
import sys
from pathlib import Path
import subprocess

repo = Path(sys.argv[1]).resolve()
branch = sys.argv[2]
proc = subprocess.run(
    ["git", "-C", str(repo), "worktree", "list", "--porcelain"],
    text=True,
    capture_output=True,
    check=True,
)
current_wt = ""
for raw in proc.stdout.splitlines():
    line = raw.strip()
    if not line:
        continue
    if line.startswith("worktree "):
        current_wt = line.split(" ", 1)[1].strip()
        continue
    if line.startswith("branch refs/heads/"):
        b = line.split("refs/heads/", 1)[1].strip()
        if b == branch:
            print(current_wt)
            break
PYOCCUPIED
)"

    if [[ -n "$occupied_worktree" && "$occupied_worktree" != "$workspace_worktree" ]]; then
      workspace_worktree="$occupied_worktree"
      workspace_note="reused existing branch worktree"
    fi

    if ! git -C "$workspace_worktree" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      mkdir -p "$(dirname "$workspace_worktree")"
      git -C "$workspace_repo" worktree add "$workspace_worktree" "$workspace_branch" >/dev/null
      WAVE_START_CREATED_WORKTREE="$workspace_worktree"
      WAVE_START_CREATED_REPO="$workspace_repo"
      if [[ -z "$workspace_note" ]]; then
        workspace_note="created deterministic wave worktree"
      fi
    elif [[ -z "$workspace_note" ]]; then
      workspace_note="existing deterministic wave worktree"
    fi

    workspace_enabled="true"

    # Materialize or refresh lane lease metadata so cleanup can reason about ownership.
    local lease_path="$workspace_worktree/$lease_filename"
    wave_atomic_write_text_file "$lease_path" <<EOF
---
version: 1
status: active
owner: "$lease_owner"
loop_or_wave_id: "$wave_id"
repo: "$workspace_repo"
worktree: "$workspace_worktree"
branch: "$workspace_branch"
created_at: "$(ts_now)"
heartbeat_at: "$(ts_now)"
ttl_hours: $lease_ttl_hours
---
EOF
    spine_ensure_git_exclude "$workspace_worktree" "$lease_filename"
    workspace_note="${workspace_note:-existing deterministic wave worktree} + lease refreshed"

    if command -v release_git_lock >/dev/null 2>&1; then
      release_git_lock
    fi
  else
    workspace_note="worktree auto-provision disabled (--worktree off)"
  fi

  local claimed_paths_json
  claimed_paths_json="$(python3 - "$claimed_paths_raw" <<'PYCLAIMS'
import json, sys
raw = sys.argv[1] if len(sys.argv) > 1 else ""
items = [x.strip() for x in raw.split(",") if x.strip()]
print(json.dumps(items))
PYCLAIMS
)"

  # Capture spine repo HEAD at wave-open time so Packet 1 hidden packet
  # receipt writer has an honest starting_head at close time.
  local wave_starting_head=""
  wave_starting_head="$(git -C "$SPINE_REPO" rev-parse HEAD 2>/dev/null || echo "")"

  WAVE_STARTING_HEAD="$wave_starting_head" \
  python3 - "$sf" "$wave_id" "$objective" "$workspace_enabled" "$workspace_repo" "$workspace_worktree" "$workspace_branch" "$workspace_note" "$default_role" "$default_next_role" "$loop_id" "$prior_wave_id" "$deadline_utc" "$horizon" "$execution_readiness" "$owner_terminal" "$claimed_paths_json" "$packet_required_fields" "$packet_allowed_horizon" "$packet_allowed_readiness" "$packet_allowed_roles" "$PATH_CLAIMS_FILE" "$PATH_CLAIMS_TTL_MINUTES" "$PATH_CLAIMS_NON_OVERLAP" "$wave_kind" <<'PYSTART'
import json, sys
import os
import tempfile
import fcntl
from datetime import datetime, timedelta, timezone

sf = sys.argv[1]
wave_id = sys.argv[2]
objective = sys.argv[3] if len(sys.argv) > 3 else ""
workspace_enabled = (sys.argv[4].lower() == "true") if len(sys.argv) > 4 else False
workspace_repo = sys.argv[5] if len(sys.argv) > 5 else ""
workspace_worktree = sys.argv[6] if len(sys.argv) > 6 else ""
workspace_branch = sys.argv[7] if len(sys.argv) > 7 else ""
workspace_note = sys.argv[8] if len(sys.argv) > 8 else ""
default_role = sys.argv[9] if len(sys.argv) > 9 and sys.argv[9] else "researcher"
default_next_role = sys.argv[10] if len(sys.argv) > 10 and sys.argv[10] else "worker"
loop_id = sys.argv[11] if len(sys.argv) > 11 else ""
prior_wave_id = sys.argv[12] if len(sys.argv) > 12 else ""
deadline_utc = sys.argv[13] if len(sys.argv) > 13 else ""
horizon = sys.argv[14] if len(sys.argv) > 14 else ""
execution_readiness = sys.argv[15] if len(sys.argv) > 15 else ""
owner_terminal = sys.argv[16] if len(sys.argv) > 16 else ""
claimed_paths = json.loads(sys.argv[17]) if len(sys.argv) > 17 and sys.argv[17] else []
required_fields = [x.strip() for x in (sys.argv[18] if len(sys.argv) > 18 else "").split(",") if x.strip()]
allowed_horizon = {x.strip() for x in (sys.argv[19] if len(sys.argv) > 19 else "now,later,future").split(",") if x.strip()}
allowed_readiness = {x.strip() for x in (sys.argv[20] if len(sys.argv) > 20 else "runnable,blocked").split(",") if x.strip()}
allowed_roles = {
    x.strip() for x in (sys.argv[21] if len(sys.argv) > 21 else "researcher,worker,qc,close,librarian").split(",") if x.strip()
}
path_claims_file = sys.argv[22] if len(sys.argv) > 22 else ""
path_claims_ttl_minutes = 180
try:
    path_claims_ttl_minutes = int(sys.argv[23]) if len(sys.argv) > 23 else 180
except Exception:
    path_claims_ttl_minutes = 180
path_claims_non_overlap = (sys.argv[24].lower() == "true") if len(sys.argv) > 24 else True
wave_kind = (sys.argv[25].strip() if len(sys.argv) > 25 and sys.argv[25].strip() else "production")
single_terminal_mode = str(owner_terminal or "").strip().startswith("SPINE-CONTROL-")

packet = {
    "schema_version": "1.0",
    "wave_id": wave_id,
    "wave_kind": wave_kind,
    "loop_id": loop_id,
    "prior_wave_id": prior_wave_id,
    "owner_terminal": owner_terminal,
    "current_role": default_role,
    "next_role": default_next_role,
    "deadline_utc": deadline_utc,
    "horizon": horizon,
    "execution_readiness": execution_readiness,
    "claimed_paths": claimed_paths,
    "single_terminal_mode": single_terminal_mode,
    "lane_outcomes": [],
    "stub_matrix": [],
    "cross_repo_pushability_gate": {
        "status": "PENDING",
        "checked_at_utc": "PENDING_CLOSEOUT",
        "repo": workspace_repo if workspace_enabled else "",
        "branch": workspace_branch if workspace_enabled else "",
        "remote": "origin",
        "failure": "",
    },
}

missing_fields = [field for field in required_fields if packet.get(field) in (None, "", [])]
if missing_fields:
    print(f"FAIL: canonical wave packet missing required fields: {', '.join(missing_fields)}")
    sys.exit(1)

if packet["horizon"] not in allowed_horizon:
    print(f"FAIL: packet.horizon invalid '{packet['horizon']}' (allowed={sorted(allowed_horizon)})")
    sys.exit(1)

if packet["execution_readiness"] not in allowed_readiness:
    print(
        "FAIL: packet.execution_readiness invalid "
        f"'{packet['execution_readiness']}' (allowed={sorted(allowed_readiness)})"
    )
    sys.exit(1)

if packet["current_role"] not in allowed_roles:
    print(f"FAIL: packet.current_role invalid '{packet['current_role']}' (allowed={sorted(allowed_roles)})")
    sys.exit(1)

if packet["next_role"] not in allowed_roles:
    print(f"FAIL: packet.next_role invalid '{packet['next_role']}' (allowed={sorted(allowed_roles)})")
    sys.exit(1)

try:
    datetime.fromisoformat(str(packet["deadline_utc"]).replace("Z", "+00:00"))
except Exception:
    print(f"FAIL: packet.deadline_utc must be ISO-8601 UTC, got '{packet['deadline_utc']}'")
    sys.exit(1)

if not isinstance(packet["claimed_paths"], list) or len(packet["claimed_paths"]) == 0:
    print("FAIL: packet.claimed_paths must include at least one claimed path")
    sys.exit(1)

def _load_doc(path: str) -> dict:
    if not path or not os.path.exists(path):
        return {}
    raw = open(path, "r", encoding="utf-8").read().strip()
    if not raw:
        return {}
    try:
        loaded = json.loads(raw)
        return loaded if isinstance(loaded, dict) else {}
    except Exception:
        try:
            import yaml
            loaded = yaml.safe_load(raw) or {}
            return loaded if isinstance(loaded, dict) else {}
        except Exception:
            return {}

def _save_doc(path: str, payload: dict) -> None:
    if not path:
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")

def _atomic_write_json(path: str, payload: dict) -> None:
    if not path:
        return
    dirpath = os.path.dirname(path) or "."
    os.makedirs(dirpath, exist_ok=True)
    fd_tmp = None
    tmp_path = None
    try:
        fd_tmp, tmp_path = tempfile.mkstemp(prefix=".state-", suffix=".tmp", dir=dirpath)
        with os.fdopen(fd_tmp, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
            fh.flush()
            os.fsync(fh.fileno())
        fd_tmp = None
        os.replace(tmp_path, path)
        tmp_path = None
    finally:
        if fd_tmp is not None:
            try:
                os.close(fd_tmp)
            except OSError:
                pass
        if tmp_path is not None:
            try:
                os.unlink(tmp_path)
            except FileNotFoundError:
                pass

def _normalize_path(p: str) -> str:
    text = str(p or "").strip()
    if not text:
        return ""
    if text == ".":
        return "."
    while text.startswith("./"):
        text = text[2:]
    text = text.rstrip("/")
    return text or "."

def _paths_overlap(a: str, b: str) -> bool:
    p1 = _normalize_path(a)
    p2 = _normalize_path(b)
    if not p1 or not p2:
        return False
    if p1 == "." or p2 == ".":
        return True
    return p1 == p2 or p1.startswith(p2 + "/") or p2.startswith(p1 + "/")

now_dt = datetime.now(timezone.utc)
now = now_dt.strftime("%Y-%m-%dT%H:%M:%SZ")
path_claims_lock_fd = None
if path_claims_file:
    lock_file = f"{path_claims_file}.lock"
    os.makedirs(os.path.dirname(lock_file), exist_ok=True)
    path_claims_lock_fd = os.open(lock_file, os.O_CREAT | os.O_RDWR, 0o644)
    fcntl.flock(path_claims_lock_fd, fcntl.LOCK_EX)
try:
    claims_doc = _load_doc(path_claims_file) if path_claims_file else {}
    claims = claims_doc.get("claims") if isinstance(claims_doc.get("claims"), list) else []
    normalized_claims = []
    conflicts = []

    # Explicit pre-pass: reap any claim whose TTL has elapsed before running the
    # collision check, so expired claims can never block a new wave start. This is
    # defensive duplication of reconcile_wave_path_claims (called earlier in the
    # shell wrapper) -- no new subsystem, just an in-place status flip.
    for claim in claims:
        if not isinstance(claim, dict):
            continue
        if str(claim.get("status", "active")).strip() != "active":
            continue
        expires_at_raw = str(claim.get("expires_at", "")).strip()
        if not expires_at_raw:
            continue
        try:
            if datetime.fromisoformat(expires_at_raw.replace("Z", "+00:00")) <= now_dt:
                claim["status"] = "expired"
                claim["expired_at"] = now
                claim["reconciled_at"] = now
                claim["reconciled_reason"] = "ttl_expired_at_wave_start"
        except Exception:
            pass

    for claim in claims:
        if not isinstance(claim, dict):
            continue
        status = str(claim.get("status", "active")).strip() or "active"
        if status == "active" and path_claims_non_overlap and str(claim.get("wave_id", "")).strip() != wave_id:
            # Waves sharing the same loop_id are co-located lanes of the same
            # orchestrated work -- allow path overlap within the same loop
            # (GAP-OP-1486).
            other_loop_id = str(claim.get("loop_id", "")).strip()
            if other_loop_id and other_loop_id == loop_id:
                pass  # same-loop sibling wave; skip overlap check
            else:
                other_paths = claim.get("claimed_paths") if isinstance(claim.get("claimed_paths"), list) else []
                for mine in packet["claimed_paths"]:
                    for other in other_paths:
                        if _paths_overlap(str(mine), str(other)):
                            conflicts.append(
                                {
                                    "wave_id": str(claim.get("wave_id", "")).strip(),
                                    "owner_terminal": str(claim.get("owner_terminal", "")).strip(),
                                    "path_a": str(mine),
                                    "path_b": str(other),
                                }
                            )
        normalized_claims.append(claim)

    if conflicts:
        print("FAIL: path claim collision detected (active overlapping claims)")
        for c in conflicts:
            print(
                "  - "
                f"wave={c['wave_id']} owner={c['owner_terminal']} "
                f"path={c['path_a']} overlaps={c['path_b']}"
            )
        sys.exit(1)

    expires_at = (now_dt + timedelta(minutes=max(1, path_claims_ttl_minutes))).strftime("%Y-%m-%dT%H:%M:%SZ")
    new_claim = {
        "claim_id": f"CLM-{wave_id}-{now_dt.strftime('%Y%m%dT%H%M%SZ')}",
        "wave_id": wave_id,
        "loop_id": loop_id,
        "owner_terminal": owner_terminal,
        "current_role": default_role,
        "next_role": default_next_role,
        "status": "active",
        "claimed_paths": packet["claimed_paths"],
        "created_at": now,
        "expires_at": expires_at,
        "deadline_utc": packet["deadline_utc"],
    }
    normalized_claims.append(new_claim)
    claims_payload = {
        "schema_version": "1.0",
        "updated_at": now,
        "claims": normalized_claims,
    }
    if path_claims_file:
        _save_doc(path_claims_file, claims_payload)
finally:
    if path_claims_lock_fd is not None:
        fcntl.flock(path_claims_lock_fd, fcntl.LOCK_UN)
        os.close(path_claims_lock_fd)
        path_claims_lock_fd = None

state = {
    "wave_id": wave_id,
    "wave_kind": wave_kind,
    "status": "active",
    "lifecycle_state": "active",
    "objective": objective,
    "created_at": now,
    "starting_head": os.environ.get("WAVE_STARTING_HEAD", ""),
    "closed_at": None,
    "dispatches": [],
    "watcher_checks": [],
    "preflight": None,
    "results": [],
    "workspace": {
        "enabled": workspace_enabled,
        "repo": workspace_repo if workspace_enabled else None,
        "worktree": workspace_worktree if workspace_enabled else None,
        "branch": workspace_branch if workspace_enabled else None,
        "lifecycle_state": "active" if workspace_enabled else "disabled",
        "note": workspace_note,
    },
    "role_flow": {
        "current_role": default_role,
        "next_role": default_next_role,
        "last_transition": None,
    },
    "path_claims": {
        "status": "active",
        "claim_id": new_claim["claim_id"],
        "claimed_paths": packet["claimed_paths"],
        "created_at": now,
        "expires_at": expires_at,
    },
    "packet": packet,
}

_atomic_write_json(sf, state)

print(f"Wave '{wave_id}' created.")
if objective:
    print(f"  Objective: {objective}")
print(f"  Status: active")
if wave_kind != "production":
    print(f"  Kind: {wave_kind}")
print(f"  Packet loop_id: {packet['loop_id']}")
print(f"  Packet role: {packet['current_role']} -> {packet['next_role']}")
print(f"  Packet deadline: {packet['deadline_utc']}")
if workspace_enabled:
    print(f"  Worktree: {workspace_worktree}")
    print(f"  Branch:   {workspace_branch}")
    if workspace_note:
        print(f"  Note:     {workspace_note}")
elif workspace_note:
    print(f"  Note: {workspace_note}")
print(f"  Next: ops wave preflight <domain>")
print(f"         ops wave dispatch {wave_id} --lane <lane> --task \"...\"")
PYSTART

  sync_runtime_traffic_index "$sf" "start"

  # Success -- disarm the cleanup trap so artifacts are preserved.
  wave_start_reset_cleanup_state
  trap - EXIT
}

cmd_claims_reconcile() {
  local wave_id=""
  local output_mode="text"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --wave-id) wave_id="${2:-}"; shift 2 ;;
      --json) output_mode="json"; shift ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  reconcile_wave_path_claims "$wave_id" "$output_mode"
}

dispatch_pushability_preflight() {
  local sf="${1:?state file required}"
  local lane="${2:?lane required}"

  python3 - "$sf" "$SPINE_REPO" "$lane" <<'PYPUSHGATE'
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

sf = sys.argv[1]
spine_repo = sys.argv[2]
lane = sys.argv[3]
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def run(cmd):
    proc = subprocess.run(cmd, text=True, capture_output=True)
    return proc.returncode, (proc.stdout or "").strip(), (proc.stderr or "").strip()

def _atomic_write_json(path, payload):
    if not path:
        return
    dirpath = os.path.dirname(path) or "."
    os.makedirs(dirpath, exist_ok=True)
    fd_tmp = None
    tmp_path = None
    try:
        fd_tmp, tmp_path = tempfile.mkstemp(prefix=".state-", suffix=".tmp", dir=dirpath)
        with os.fdopen(fd_tmp, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
            fh.flush()
            os.fsync(fh.fileno())
        fd_tmp = None
        os.replace(tmp_path, path)
        tmp_path = None
    finally:
        if fd_tmp is not None:
            try:
                os.close(fd_tmp)
            except OSError:
                pass
        if tmp_path is not None:
            try:
                os.unlink(tmp_path)
            except FileNotFoundError:
                pass

state = json.load(open(sf, "r", encoding="utf-8"))
workspace = state.get("workspace") if isinstance(state.get("workspace"), dict) else {}
packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
repo = str(workspace.get("repo") or "").strip()
branch = str(workspace.get("branch") or "").strip()
wave_id = str(state.get("wave_id") or "").strip()
loop_id = str(packet.get("loop_id") or "").strip()
owner_terminal = str(packet.get("owner_terminal") or "SPINE-CONTROL-01").strip()
remote = "origin"
remote_url = ""
errors = []
execution_mode = str(packet.get("execution_mode") or state.get("execution_mode") or "").strip().lower()
transport = str(packet.get("transport") or state.get("transport") or "").strip().lower()

workspace_enabled = workspace.get("enabled")
if isinstance(workspace_enabled, str):
    workspace_enabled = workspace_enabled.lower() == "true"
workspace_disabled = not workspace_enabled

if workspace_disabled or execution_mode == "operational" or transport == "mailroom":
    resolved_execution_mode = execution_mode or ("local" if workspace_disabled else "code")
    resolved_transport = transport or ("local" if workspace_disabled else ("mailroom" if resolved_execution_mode == "operational" else "git"))
    push_gate = {
        "status": "PASS",
        "checked_at_utc": now,
        "repo": repo,
        "branch": branch,
        "remote": remote,
        "remote_url": "",
        "failure": "",
        "execution_mode": resolved_execution_mode,
        "transport": resolved_transport,
        "reason": "operational_or_mailroom_transport_skips_git_pushability",
    }
    packet["cross_repo_pushability_gate"] = push_gate
    state["preflight"] = {
        "domain": "dispatch-pushability",
        "started_at": now,
        "finished_at": now,
        "duration_s": 0,
        "verdict": "go",
        "blockers": [],
        "next_action": "Proceed with dispatch.",
    }
    state["packet"] = packet
    _atomic_write_json(sf, state)

    skip_reason = "workspace_disabled" if workspace_disabled else "operational_or_mailroom_transport"
    print(
        "dispatch pushability preflight: PASS "
        f"lane={lane} execution_mode={resolved_execution_mode} transport={resolved_transport} "
        f"(git pushability skipped: {skip_reason})"
    )
    raise SystemExit(0)

if not repo:
    errors.append("workspace.repo missing")
elif not os.path.isdir(repo):
    errors.append(f"workspace.repo not found: {repo}")

if not branch:
    errors.append("workspace.branch missing")

if not errors:
    rc, out, err = run(["git", "-C", repo, "remote", "get-url", remote])
    if rc != 0 or not out:
        errors.append(f"remote '{remote}' is not configured for repo '{repo}'")
    else:
        remote_url = out

if not errors:
    rc, out, err = run(["git", "-C", repo, "push", "--dry-run", remote, f"{branch}:{branch}"])
    if rc != 0:
        detail = err or out or "dry-run push failed"
        errors.append(f"push dry-run failed for {remote}/{branch}: {detail}")

push_gate = {
    "status": "PASS" if not errors else "FAIL",
    "checked_at_utc": now,
    "repo": repo,
    "branch": branch,
    "remote": remote,
    "remote_url": remote_url,
    "failure": " | ".join(errors) if errors else "",
}
packet["cross_repo_pushability_gate"] = push_gate

if errors:
    stub_rel = ""
    stub_id = f"STUB-cross-repo-pushability-{wave_id.lower()}-{lane.lower()}"
    if loop_id:
        stub_dir = os.path.join(os.environ.get("SPINE_STATE", os.path.join(os.environ.get("HOME", ""), "code", ".runtime", "spine", "state")), "orchestration", loop_id, "stubs")
        os.makedirs(stub_dir, exist_ok=True)
        stub_path = os.path.join(stub_dir, f"{stub_id}.md")
        unblock_cmd = f"git -C {repo} push --dry-run {remote} {branch}:{branch}" if repo and branch else "git remote -v"
        with open(stub_path, "w", encoding="utf-8") as f:
            f.write("---\n")
            f.write(f"stub_id: {stub_id}\n")
            f.write("status: open\n")
            f.write(f"owner_terminal: {owner_terminal or 'SPINE-CONTROL-01'}\n")
            f.write("blocker_class: pushability_gate\n")
            f.write(f"created_at_utc: {now}\n")
            f.write("---\n\n")
            f.write("# Pushability Blocker Stub\n\n")
            f.write(f"- wave_id: `{wave_id}`\n")
            f.write(f"- lane: `{lane}`\n")
            f.write(f"- repo: `{repo}`\n")
            f.write(f"- branch: `{branch}`\n")
            f.write(f"- remote: `{remote}`\n")
            f.write(f"- failures: {'; '.join(errors)}\n\n")
            f.write("## Unblock Command\n\n")
            f.write("```bash\n")
            f.write(f"{unblock_cmd}\n")
            f.write("```\n")
        stub_rel = os.path.relpath(stub_path, spine_repo)

    stub_matrix = packet.get("stub_matrix") if isinstance(packet.get("stub_matrix"), list) else []
    stub_matrix = [row for row in stub_matrix if not (isinstance(row, dict) and str(row.get("id", "")).strip() == stub_id)]
    stub_matrix.append(
        {
            "id": stub_id,
            "path": stub_rel,
            "blocker_class": "pushability_gate",
            "state": "open",
        }
    )
    packet["stub_matrix"] = stub_matrix

    lane_outcomes = packet.get("lane_outcomes") if isinstance(packet.get("lane_outcomes"), list) else []
    updated = False
    for row in lane_outcomes:
        if not isinstance(row, dict):
            continue
        if str(row.get("lane_id", "")).strip() != lane:
            continue
        row["lane_status"] = "BLOCKED"
        row["owner_terminal"] = owner_terminal
        row["blocker"] = "cross_repo_pushability_gate_failed"
        row["stub_evidence_ref"] = stub_rel
        row["updated_at_utc"] = now
        updated = True
        break
    if not updated:
        lane_outcomes.append(
            {
                "lane_id": lane,
                "owner_terminal": owner_terminal,
                "lane_status": "BLOCKED",
                "blocker": "cross_repo_pushability_gate_failed",
                "stub_evidence_ref": stub_rel,
                "updated_at_utc": now,
            }
        )
    packet["lane_outcomes"] = lane_outcomes

    blockers = []
    preflight = state.get("preflight")
    if isinstance(preflight, dict):
        existing = preflight.get("blockers")
        if isinstance(existing, list):
            blockers.extend(str(x) for x in existing if str(x).strip())
    blockers.append(f"cross_repo_pushability_gate failed for lane={lane}: {'; '.join(errors)}")
    state["preflight"] = {
        "domain": "dispatch-pushability",
        "started_at": now,
        "finished_at": now,
        "duration_s": 0,
        "verdict": "no-go",
        "blockers": blockers,
        "next_action": "Configure remote + pushability, then retry dispatch.",
    }

    state["packet"] = packet
    _atomic_write_json(sf, state)

    print("BLOCKED: dispatch pushability preflight failed")
    for msg in errors:
        print(f"  - {msg}")
    if stub_rel:
        print(f"  blocker_stub: {stub_rel}")
    raise SystemExit(1)

state["packet"] = packet
state["preflight"] = {
    "domain": "dispatch-pushability",
    "started_at": now,
    "finished_at": now,
    "duration_s": 0,
    "verdict": "go",
    "blockers": [],
    "next_action": "Proceed with dispatch.",
}
_atomic_write_json(sf, state)

print(f"dispatch pushability preflight: PASS repo={repo} branch={branch} remote={remote}")
PYPUSHGATE
}

_dispatch_operational_mailroom() {
  local sf="${1:?state file required}"
  local lane="${2:?lane required}"
  local task="${3:?task required}"
  local from_role="${4:-}"
  local to_role="${5:-}"
  local transition_gate="${6:-}"
  local input_refs_json="${7:-}"
  local output_refs_json="${8:-}"
  local enqueue_script
  enqueue_script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/plugins/infra/mailroom-bridge/bin/mailroom-task-enqueue"

  [[ -n "$input_refs_json" ]] || input_refs_json='{}'
  [[ -n "$output_refs_json" ]] || output_refs_json='{}'

  [[ -x "$enqueue_script" ]] || {
    echo "FAIL: operational dispatch requires mailroom-task-enqueue at $enqueue_script" >&2
    exit 1
  }

  local dispatch_ctx_json=""
  dispatch_ctx_json="$(python3 - "$sf" "$lane" "$task" "$from_role" "$to_role" "$transition_gate" "$input_refs_json" "$output_refs_json" <<'PYMAILROOMCTX'
import hashlib
import json
import re
import sys
from datetime import datetime, timezone

sf = sys.argv[1]
lane = sys.argv[2]
task = sys.argv[3]
from_role = sys.argv[4] if len(sys.argv) > 4 else ""
to_role = sys.argv[5] if len(sys.argv) > 5 else ""
transition_gate = sys.argv[6] if len(sys.argv) > 6 else ""
input_refs = json.loads(sys.argv[7]) if len(sys.argv) > 7 and sys.argv[7] else {}
expected_output_refs = json.loads(sys.argv[8]) if len(sys.argv) > 8 and sys.argv[8] else {}

with open(sf, "r", encoding="utf-8") as f:
    state = json.load(f)

packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
wave_id = str(state.get("wave_id") or packet.get("wave_id") or "").strip()
loop_id = str(packet.get("loop_id") or "").strip()
owner_terminal = str(packet.get("owner_terminal") or "").strip()
execution_mode = str(packet.get("execution_mode") or "code").strip() or "code"
transport = str(packet.get("transport") or "git").strip() or "git"
horizon = str(packet.get("horizon") or "").strip()
execution_readiness = str(packet.get("execution_readiness") or "").strip()

def derive_route_input(*parts: str) -> str:
    corpus = " ".join(str(x or "") for x in parts).lower()
    matchers = [
        ("finance", r"\bfinance|firefly|paperless|tax|budget|transaction\b"),
        ("identity", r"\bidentity|email|calendar|graph|outlook|office 365|microsoft\b"),
        ("automation", r"\bautomation|workflow|n8n|webhook|cron\b"),
        ("home-automation", r"\bhome assistant|hass|zigbee|z-wave|smart-home\b"),
        ("photos", r"\bimmich|photo|asset|album\b"),
        ("mint", r"\bmint|artwork|quote|intake|pricing|shipping|suppliers\b"),
        ("media", r"\bmedia|jellyfin|radarr|sonarr|sabnzbd|navidrome\b"),
    ]
    for route_input, pattern in matchers:
        if re.search(pattern, corpus):
            return route_input
    return "automation"

route_input = derive_route_input(
    lane,
    task,
    loop_id,
    from_role,
    to_role,
    " ".join(str(v) for v in input_refs.values()),
    " ".join(str(v) for v in expected_output_refs.values()),
)

payload = {
    "wave_id": wave_id,
    "loop_id": loop_id,
    "lane": lane,
    "task": task,
    "owner_terminal": owner_terminal,
    "from_role": from_role,
    "to_role": to_role,
    "transition_gate": transition_gate,
    "input_refs": input_refs,
    "expected_output_refs": expected_output_refs,
    "execution_mode": execution_mode,
    "transport": transport,
    "horizon": horizon,
    "execution_readiness": execution_readiness,
    "dispatch_transport": "mailroom",
    "route_target": {"type": "agent_tool", "tool": "route_resolve", "input": route_input},
    "routing_status": "pending_resolution",
}

# ── Dispatch Envelope (dispatch.envelope.contract.yaml) ──
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
_route_to_domain = {
    "finance": "finance", "mint": "mint", "media": "media",
    "home-automation": "ha", "photos": "media",
    "identity": "core", "automation": "core",
}
_work_type_by_lane = {
    "execution": "capability_execution", "audit": "verification",
    "watcher": "observation", "control": "wave_orchestration",
}
_ts_compact = now[:10].replace("-", "") + "-" + now[11:19].replace(":", "")
_envelope_hash = hashlib.sha256(f"{wave_id}-{lane}-{now}".encode()).hexdigest()[:8]
envelope_id = f"ENV-{_ts_compact}-{_envelope_hash}"

payload["dispatch_envelope"] = {
    "envelope_id": envelope_id,
    "sender_node": "control",
    "target_node": lane if lane in ("execution", "audit", "watcher") else "execution",
    "work_scope": {
        "work_type": _work_type_by_lane.get(lane, "capability_execution"),
        "domain": _route_to_domain.get(route_input, "core"),
        "loop_id": loop_id,
        "wave_id": wave_id,
        "safety_level": "mutating" if to_role == "worker" else "read-only",
        "execution_mode": "operational",
    },
    "transport_mode": "mailroom",
    "receipt_expectation": {
        "expected_receipt_type": "run_key",
        "completion_criteria": "single_receipt",
    },
    "created_at_utc": now,
}

summary = " ".join(f"{wave_id} [{lane}] {task}".split())
if len(summary) > 180:
    summary = summary[:177] + "..."

print(
    json.dumps(
        {
            "wave_id": wave_id,
            "loop_id": loop_id,
            "owner_terminal": owner_terminal,
            "execution_mode": execution_mode,
            "transport": transport,
            "horizon": horizon,
            "execution_readiness": execution_readiness,
            "route_input": route_input,
            "summary": summary,
            "payload": payload,
        },
        separators=(",", ":"),
    )
)
PYMAILROOMCTX
)"

  local summary=""
  summary="$(jq -r '.summary' <<<"$dispatch_ctx_json")"
  local payload_json=""
  payload_json="$(jq -c '.payload' <<<"$dispatch_ctx_json")"

  local enqueue_json=""
  enqueue_json="$("$enqueue_script" \
    --summary "$summary" \
    --route-target agent_tool \
    --payload "$payload_json" \
    --json)"

  local dispatch_result_json=""
  dispatch_result_json="$(python3 - "$sf" "$lane" "$task" "$from_role" "$to_role" "$transition_gate" "$input_refs_json" "$output_refs_json" "$dispatch_ctx_json" "$enqueue_json" <<'PYMAILROOMDISP'
import fcntl
import json
import os
import sys
from datetime import datetime, timezone

sf = sys.argv[1]
lane = sys.argv[2]
task = sys.argv[3]
from_role = sys.argv[4] if len(sys.argv) > 4 else ""
to_role = sys.argv[5] if len(sys.argv) > 5 else ""
transition_gate = sys.argv[6] if len(sys.argv) > 6 else ""
input_refs = json.loads(sys.argv[7]) if len(sys.argv) > 7 and sys.argv[7] else {}
expected_output_refs = json.loads(sys.argv[8]) if len(sys.argv) > 8 and sys.argv[8] else {}
ctx = json.loads(sys.argv[9]) if len(sys.argv) > 9 and sys.argv[9] else {}
enqueue = json.loads(sys.argv[10]) if len(sys.argv) > 10 and sys.argv[10] else {}
queue_data = enqueue.get("data") if isinstance(enqueue.get("data"), dict) else {}
ctx_payload = ctx.get("payload") if isinstance(ctx.get("payload"), dict) else {}
ctx_envelope = ctx_payload.get("dispatch_envelope") if isinstance(ctx_payload.get("dispatch_envelope"), dict) else {}
lock_file = sf + ".lock"
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf, "r", encoding="utf-8") as f:
        state = json.load(f)
    packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}

    dispatches = state.get("dispatches")
    if not isinstance(dispatches, list):
        dispatches = []
        state["dispatches"] = dispatches

    idx = len(dispatches) + 1
    task_id = f"D{idx}"
    dispatch = {
        "task_id": task_id,
        "lane": lane,
        "task": task,
        "from_role": from_role,
        "to_role": to_role,
        "transition_gate": transition_gate,
        "input_refs": input_refs,
        "expected_output_refs": expected_output_refs,
        "status": "dispatched",
        "dispatched_at": now,
        "completed_at": None,
        "result": "mailroom task queued",
        "run_key": None,
        "receipt_validated": False,
        "dispatch_transport": "mailroom",
        "envelope_id": str(ctx_envelope.get("envelope_id") or ""),
        "wave_execution_mode": str(ctx.get("execution_mode") or ""),
        "wave_transport": str(ctx.get("transport") or ""),
        "mailroom_task_id": str(queue_data.get("task_id") or ""),
        "mailroom_task_file": str(queue_data.get("file") or ""),
        "mailroom_task_state": str(queue_data.get("state") or "queued"),
        "mailroom_route_target": str(queue_data.get("route_target") or "agent_tool"),
        "mailroom_required_agents": queue_data.get("required_agents") if isinstance(queue_data.get("required_agents"), list) else [],
        "mailroom_summary": str(queue_data.get("summary") or ""),
        "mailroom_route_input": str(ctx.get("route_input") or ""),
    }
    dispatches.append(dispatch)

    lane_outcomes = packet.get("lane_outcomes") if isinstance(packet.get("lane_outcomes"), list) else []
    lane_updated = False
    for row in lane_outcomes:
        if not isinstance(row, dict):
            continue
        if str(row.get("lane_id", "")).strip() != lane:
            continue
        row["lane_status"] = "DISPATCHED"
        row["owner_terminal"] = str(row.get("owner_terminal") or packet.get("owner_terminal") or "").strip()
        row["dispatch_transport"] = "mailroom"
        row["dispatch_task_id"] = task_id
        row["mailroom_task_id"] = dispatch["mailroom_task_id"]
        row["stub_evidence_ref"] = ""
        row.pop("blocker", None)
        row["updated_at_utc"] = now
        lane_updated = True
        break
    if not lane_updated:
        lane_outcomes.append(
            {
                "lane_id": lane,
                "lane_status": "DISPATCHED",
                "owner_terminal": str(packet.get("owner_terminal") or "").strip(),
                "dispatch_transport": "mailroom",
                "dispatch_task_id": task_id,
                "mailroom_task_id": dispatch["mailroom_task_id"],
                "stub_evidence_ref": "",
                "updated_at_utc": now,
            }
        )
    packet["lane_outcomes"] = lane_outcomes
    state["packet"] = packet

    role_flow = state.get("role_flow") if isinstance(state.get("role_flow"), dict) else {}
    if from_role and not role_flow.get("current_role"):
        role_flow["current_role"] = from_role
    if to_role:
        role_flow["next_role"] = to_role
    role_flow["pending_transition"] = {
        "task_id": task_id,
        "from_role": from_role,
        "to_role": to_role,
        "gate": transition_gate,
        "dispatched_at": now,
        "dispatch_transport": "mailroom",
        "mailroom_task_id": dispatch["mailroom_task_id"],
    }
    state["role_flow"] = role_flow

    _atomic_write_json(sf, state)
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)

print(
    json.dumps(
        {
            "dispatch_index": idx,
            "dispatch_id": task_id,
            "mailroom_task_id": str(queue_data.get("task_id") or ""),
            "mailroom_task_file": str(queue_data.get("file") or ""),
            "route_input": str(ctx.get("route_input") or ""),
        },
        separators=(",", ":"),
    )
)
PYMAILROOMDISP
)"

  local dispatch_index=""
  dispatch_index="$(jq -r '.dispatch_index' <<<"$dispatch_result_json")"
  local dispatch_id=""
  dispatch_id="$(jq -r '.dispatch_id' <<<"$dispatch_result_json")"
  local mailroom_task_id=""
  mailroom_task_id="$(jq -r '.mailroom_task_id' <<<"$dispatch_result_json")"
  local mailroom_task_file=""
  mailroom_task_file="$(jq -r '.mailroom_task_file' <<<"$dispatch_result_json")"
  local route_input=""
  route_input="$(jq -r '.route_input' <<<"$dispatch_result_json")"

  echo "Dispatched task #${dispatch_index} to lane '${lane}':"
  echo "  Task: ${task}"
  echo "  Dispatch ID: ${dispatch_id}"
  echo "  Transport: mailroom"
  echo "  Mailroom Task: ${mailroom_task_id}"
  echo "  Queue File: ${mailroom_task_file}"
  echo "  Status: dispatched"
  if [[ -n "$route_input" ]]; then
    echo "  Route: agent_tool/route_resolve input=${route_input}"
  fi
  if [[ -n "$from_role" || -n "$to_role" ]]; then
    echo "  Role transition: ${from_role:-?} -> ${to_role:-?} (gate=${transition_gate:-none})"
  fi
}

cmd_dispatch() {
  local wave_id=""
  local lane=""
  local task=""
  local from_role=""
  local to_role=""
  local input_refs_raw=""
  local output_refs_raw=""
  local transition_gate=""
  # control_lane_override compatibility marker: controller-owned lane overrides
  # now flow through --lock-override / lock_override_reason.
  local lock_override_reason=""
  local input_refs_json='{}'
  local output_refs_json='{}'

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --lane) lane="${2:-}"; shift 2 ;;
      --task) task="${2:-}"; shift 2 ;;
      --from-role) from_role="${2:-}"; shift 2 ;;
      --to-role) to_role="${2:-}"; shift 2 ;;
      --input-refs) input_refs_raw="${2:-}"; shift 2 ;;
      --output-refs) output_refs_raw="${2:-}"; shift 2 ;;
      --transition-gate) transition_gate="${2:-}"; shift 2 ;;
      --lock-override)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          echo "ERROR: --lock-override requires a non-empty reason" >&2
          exit 1
        fi
        lock_override_reason="${2:-}"
        shift 2
        ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) wave_id="$1"; shift ;;
    esac
  done

  if [[ -z "$wave_id" || -z "$lane" || -z "$task" ]]; then
    echo "Usage: ops wave dispatch <WAVE_ID> --lane <lane> --task \"<text>\" [OPTIONS]" >&2
    echo "" >&2
    echo "  Lanes must be one of: $(wave_allowed_lanes_display)" >&2
    echo "  For arbitrary named lanes, use: ops dispatch local --lane \"name:command\" ..." >&2
    echo "" >&2
    echo "  Options: --from-role, --to-role, --input-refs, --output-refs, --lock-override" >&2
    exit 1
  fi

  wave_require_valid_lane "$lane"

  ensure_wave_exists "$wave_id"
  wave_lock_guard "$wave_id" "dispatch" "$lock_override_reason"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local sd
  sd="$(wave_state_dir "$wave_id")"
  dispatch_pushability_preflight "$sf" "$lane"
  local dispatch_terminal_identity
  dispatch_terminal_identity="$(resolve_wave_terminal_identity)"

  if [[ -f "$ROLE_RUNTIME_CONTRACT" ]]; then
    python3 - "$sf" "$ROLE_RUNTIME_CONTRACT" <<'PYPACKETDISPATCH'
import json, sys
from datetime import datetime

state_file = sys.argv[1]
contract_file = sys.argv[2]

state = json.load(open(state_file, "r", encoding="utf-8"))
packet = state.get("packet")
if not isinstance(packet, dict):
    print("FAIL: wave packet missing from state (start contract not satisfied)")
    raise SystemExit(1)

required = []
allowed_horizon = {"now", "later", "future"}
allowed_readiness = {"runnable", "blocked"}
allowed_roles = {"researcher", "worker", "qc", "close", "librarian"}

try:
    import yaml
    contract = yaml.safe_load(open(contract_file, "r", encoding="utf-8")) or {}
    wave_packet = contract.get("wave_packet") if isinstance(contract, dict) else {}
    if isinstance(wave_packet, dict):
        required = [str(x).strip() for x in (wave_packet.get("required_fields") or []) if str(x).strip()]
        allowed_horizon = {str(x).strip() for x in (wave_packet.get("allowed_horizon") or []) if str(x).strip()} or allowed_horizon
        allowed_readiness = {
            str(x).strip() for x in (wave_packet.get("allowed_readiness") or []) if str(x).strip()
        } or allowed_readiness
    runtime_roles = contract.get("runtime_roles") if isinstance(contract, dict) else {}
    if isinstance(runtime_roles, dict):
        canonical = {
            str(x).strip()
            for x in (runtime_roles.get("canonical") or [])
            if str(x).strip()
        }
        if canonical:
            allowed_roles = canonical
except Exception:
    pass

if not required:
    required = [
        "wave_id",
        "loop_id",
        "owner_terminal",
        "current_role",
        "next_role",
        "deadline_utc",
        "horizon",
        "execution_readiness",
        "claimed_paths",
    ]

missing = [field for field in required if packet.get(field) in (None, "", [])]
if missing:
    print(f"FAIL: wave packet missing required fields at dispatch: {', '.join(missing)}")
    raise SystemExit(1)

if packet.get("horizon") not in allowed_horizon:
    print(f"FAIL: wave packet horizon invalid at dispatch: {packet.get('horizon')}")
    raise SystemExit(1)

if packet.get("execution_readiness") not in allowed_readiness:
    print(f"FAIL: wave packet execution_readiness invalid at dispatch: {packet.get('execution_readiness')}")
    raise SystemExit(1)

for field in ("current_role", "next_role"):
    value = str(packet.get(field) or "").strip()
    if value not in allowed_roles:
        print(f"FAIL: wave packet {field} invalid at dispatch: {value!r} (allowed={sorted(allowed_roles)})")
        raise SystemExit(1)

try:
    datetime.fromisoformat(str(packet.get("deadline_utc", "")).replace("Z", "+00:00"))
except Exception:
    print(f"FAIL: wave packet deadline_utc invalid at dispatch: {packet.get('deadline_utc')}")
    raise SystemExit(1)

claimed_paths = packet.get("claimed_paths")
if not isinstance(claimed_paths, list) or len(claimed_paths) == 0:
    print("FAIL: wave packet claimed_paths must be a non-empty list at dispatch")
    raise SystemExit(1)
PYPACKETDISPATCH
  fi

  # If dispatching to watcher, auto-enqueue background checks
  if [[ "$lane" == "watcher" ]]; then
    _dispatch_watcher "$wave_id" "$sf" "$sd" "$task"
    return
  fi

  input_refs_json="$(python3 - "$input_refs_raw" <<'PYREFS'
import json, sys
raw = sys.argv[1] if len(sys.argv) > 1 else ""
out = {}
for part in raw.split(","):
    item = part.strip()
    if not item or "=" not in item:
        continue
    k, v = item.split("=", 1)
    key = k.strip()
    val = v.strip()
    if key:
        out[key] = val
print(json.dumps(out))
PYREFS
)"
  output_refs_json="$(python3 - "$output_refs_raw" <<'PYREFS'
import json, sys
raw = sys.argv[1] if len(sys.argv) > 1 else ""
out = {}
for part in raw.split(","):
    item = part.strip()
    if not item or "=" not in item:
        continue
    k, v = item.split("=", 1)
    key = k.strip()
    val = v.strip()
    if key:
        out[key] = val
print(json.dumps(out))
PYREFS
)"

  if [[ -f "$ROLE_RUNTIME_CONTRACT" ]] && command -v yq >/dev/null 2>&1; then
    if [[ -z "$from_role" ]]; then
      from_role="$(python3 - "$sf" <<'PYROLE'
import json, sys
state = json.load(open(sys.argv[1], "r", encoding="utf-8"))
role_flow = state.get("role_flow") if isinstance(state.get("role_flow"), dict) else {}
print(str(role_flow.get("current_role") or "researcher"))
PYROLE
)"
    fi

    if [[ -z "$to_role" ]]; then
      case "$lane" in
        execution) to_role="worker" ;;
        audit) to_role="qc" ;;
        control) to_role="close" ;;
        # Default unknown lanes to worker (not from_role) to ensure a valid
        # promotion transition exists. researcher->researcher has no gate
        # in the contract and fails validation (GAP-OP-1487).
        *) to_role="worker" ;;
      esac
    fi

    if [[ -z "$transition_gate" ]]; then
      transition_gate="$(yq -r ".promotion_gates.transitions[]? | select(.from == \"$from_role\" and .to == \"$to_role\") | .gate" "$ROLE_RUNTIME_CONTRACT" 2>/dev/null | head -n1)"
    fi
    [[ -n "$transition_gate" && "$transition_gate" != "null" ]] || {
      echo "FAIL: transition gate not found for role transition $from_role -> $to_role" >&2
      exit 1
    }

    required_inputs_json="$(yq -o=json ".handoff_boundaries.\"$transition_gate\".required_input_refs // []" "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || echo '[]')"
    required_outputs_json="$(yq -o=json ".handoff_boundaries.\"$transition_gate\".required_output_refs // []" "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || echo '[]')"

    # Auto-populate required refs from wave packet/scope context and prior done
    # dispatches when not explicitly provided. Orchestrator-generated dispatches
    # should not require manual ref injection when the evidence already exists
    # in the wave state (GAP-OP-1488/1489 and reconciliation-entry smoke seam).
    input_refs_json="$(python3 - "$sf" "$input_refs_json" "$required_inputs_json" "$lane" "$transition_gate" <<'PYAUTOREFS'
import json, sys
import os

state = json.load(open(sys.argv[1], "r", encoding="utf-8"))
refs = json.loads(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else {}
required = json.loads(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else []
lane = sys.argv[4] if len(sys.argv) > 4 else ""
transition_gate = sys.argv[5] if len(sys.argv) > 5 else ""
packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
loop_id = str(packet.get("loop_id") or state.get("wave_id") or "").strip()
state_root = os.environ.get("SPINE_STATE", os.path.join(os.environ.get("HOME", ""), "code", ".runtime", "spine", "state"))
scope_path = f"{state_root}/loop-scopes/{loop_id}.scope.md" if loop_id else ""
workspace_root = os.path.dirname(os.path.dirname(os.path.dirname(state_root)))
evidence_root = os.path.join(workspace_root, ".evidence", "spine")
wave_id = str(state.get("wave_id") or "").strip()
artifacts_dir = os.path.join(state_root, "orchestration", loop_id, "artifacts") if loop_id else ""
wave_dir = os.path.dirname(sys.argv[1])
dispatches = state.get("dispatches") if isinstance(state.get("dispatches"), list) else []

def dispatch_order(dispatch):
    task_id = str(dispatch.get("task_id", "")).strip()
    if task_id.startswith("D") and task_id[1:].isdigit():
        return int(task_id[1:])
    return 0

def latest_done(*lanes):
    rows = [
        d for d in dispatches
        if isinstance(d, dict) and str(d.get("status", "")).strip() == "done"
    ]
    if lanes:
        allowed = {lane_id for lane_id in lanes if lane_id}
        rows = [d for d in rows if str(d.get("lane", "")).strip() in allowed]
    rows.sort(key=lambda d: (dispatch_order(d), str(d.get("completed_at") or d.get("dispatched_at") or "")))
    return rows[-1] if rows else {}

def expected(dispatch, key):
    if not isinstance(dispatch, dict):
        return ""
    expected_output_refs = dispatch.get("expected_output_refs")
    if not isinstance(expected_output_refs, dict):
        return ""
    return str(expected_output_refs.get(key) or "").strip()

def run_key_to_receipt(run_key):
    rk = str(run_key or "").strip()
    if not rk:
        return ""
    return os.path.join(evidence_root, "sessions", f"R{rk}", "receipt.md")

def artifact(name):
    if artifacts_dir:
        return os.path.join(artifacts_dir, f"{wave_id}_{name}.md")
    return os.path.join(wave_dir, f"{name.lower().replace('_', '-')}.md")

execution_dispatch = latest_done("execution")
audit_dispatch = latest_done("audit")

latest_verify_run = (
    expected(audit_dispatch, "verify_ref")
    or str(audit_dispatch.get("run_key") or "").strip()
    or str(execution_dispatch.get("run_key") or "").strip()
)
acceptance_ref = (
    run_key_to_receipt(str(execution_dispatch.get("run_key") or "").strip())
    or expected(execution_dispatch, "acceptance_criteria_ref")
    or scope_path
)
implementation_ref = (
    expected(audit_dispatch, "implementation_ref")
    or expected(execution_dispatch, "implementation_ref")
    or artifact("AUDIT" if lane == "control" and audit_dispatch else "EXECUTION")
)
cleanup_ref = (
    expected(audit_dispatch, "cleanup_ref")
    or artifact("CLEANUP")
)
auto_map = {
    "research_brief_ref": scope_path,
    "scope_ref": scope_path,
    "execution_plan_ref": expected(execution_dispatch, "execution_plan_ref") or scope_path,
    "acceptance_criteria_ref": acceptance_ref,
    "implementation_ref": implementation_ref,
    "verify_ref": latest_verify_run,
    "cleanup_ref": cleanup_ref,
}
for key in required:
    k = str(key).strip()
    if k and not refs.get(k) and k in auto_map and auto_map[k]:
        refs[k] = auto_map[k]
print(json.dumps(refs))
PYAUTOREFS
)"
    output_refs_json="$(python3 - "$sf" "$output_refs_json" "$required_outputs_json" "$lane" "$transition_gate" <<'PYAUTOOUTREFS'
import json, sys
import os

state = json.load(open(sys.argv[1], "r", encoding="utf-8"))
refs = json.loads(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else {}
required = json.loads(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else []
lane = sys.argv[4] if len(sys.argv) > 4 else ""
transition_gate = sys.argv[5] if len(sys.argv) > 5 else ""
packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
loop_id = str(packet.get("loop_id") or state.get("wave_id") or "").strip()
state_root = os.environ.get("SPINE_STATE", os.path.join(os.environ.get("HOME", ""), "code", ".runtime", "spine", "state"))
scope_path = f"{state_root}/loop-scopes/{loop_id}.scope.md" if loop_id else ""
workspace_root = os.path.dirname(os.path.dirname(os.path.dirname(state_root)))
evidence_root = os.path.join(workspace_root, ".evidence", "spine")
wave_id = str(state.get("wave_id") or "").strip()
artifacts_dir = os.path.join(state_root, "orchestration", loop_id, "artifacts") if loop_id else ""
wave_dir = os.path.dirname(sys.argv[1])
dispatches = state.get("dispatches") if isinstance(state.get("dispatches"), list) else []

def dispatch_order(dispatch):
    task_id = str(dispatch.get("task_id", "")).strip()
    if task_id.startswith("D") and task_id[1:].isdigit():
        return int(task_id[1:])
    return 0

def latest_done(*lanes):
    rows = [
        d for d in dispatches
        if isinstance(d, dict) and str(d.get("status", "")).strip() == "done"
    ]
    if lanes:
        allowed = {lane_id for lane_id in lanes if lane_id}
        rows = [d for d in rows if str(d.get("lane", "")).strip() in allowed]
    rows.sort(key=lambda d: (dispatch_order(d), str(d.get("completed_at") or d.get("dispatched_at") or "")))
    return rows[-1] if rows else {}

def run_key_to_receipt(run_key):
    rk = str(run_key or "").strip()
    if not rk:
        return ""
    return os.path.join(evidence_root, "sessions", f"R{rk}", "receipt.md")

def artifact(name):
    if artifacts_dir:
        return os.path.join(artifacts_dir, f"{wave_id}_{name}.md")
    return os.path.join(wave_dir, f"{name.lower().replace('_', '-')}.md")

execution_dispatch = latest_done("execution")
latest_verify_run = str(execution_dispatch.get("run_key") or "").strip()
acceptance_ref = run_key_to_receipt(latest_verify_run) or scope_path
implementation_output = artifact("AUDIT" if lane == "audit" else "EXECUTION")
auto_map = {
    "execution_plan_ref": scope_path,
    "acceptance_criteria_ref": acceptance_ref,
    "implementation_ref": implementation_output,
    "verify_ref": latest_verify_run,
    "cleanup_ref": artifact("CLEANUP"),
    "closeout_ref": artifact("CLOSEOUT"),
    "linkage_ref": artifact("LINKAGE"),
}
for key in required:
    k = str(key).strip()
    if k and not refs.get(k) and k in auto_map and auto_map[k]:
        refs[k] = auto_map[k]
print(json.dumps(refs))
PYAUTOOUTREFS
)"

    missing_inputs="$(jq -r --argjson required "$required_inputs_json" --argjson refs "$input_refs_json" '$required[] | select(($refs[.] // "") == "")' <<<"{}")"
    missing_outputs="$(jq -r --argjson required "$required_outputs_json" --argjson refs "$output_refs_json" '$required[] | select(($refs[.] // "") == "")' <<<"{}")"
    if [[ -n "$missing_inputs" ]]; then
      echo "FAIL: dispatch missing required input refs for gate $transition_gate: $(echo "$missing_inputs" | tr '\n' ',' | sed 's/,$//')" >&2
      echo "HINT: pass --input-refs \"$(echo "$missing_inputs" | tr '\n' ',' | sed 's/,$//' | sed 's/\([^,]*\)/\1=<path>/g')\"" >&2
      exit 1
    fi
    if [[ -n "$missing_outputs" ]]; then
      echo "FAIL: dispatch missing required output refs for gate $transition_gate: $(echo "$missing_outputs" | tr '\n' ',' | sed 's/,$//')" >&2
      echo "HINT: pass --output-refs \"$(echo "$missing_outputs" | tr '\n' ',' | sed 's/,$//' | sed 's/\([^,]*\)/\1=<path>/g')\"" >&2
      exit 1
    fi

    python3 - "$ROLE_RUNTIME_CONTRACT" "$required_inputs_json" "$required_outputs_json" "$input_refs_json" "$output_refs_json" "$transition_gate" <<'PYREFSEM'
import json
import os
import re
import sys

contract_file = sys.argv[1]
required_inputs = json.loads(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else []
required_outputs = json.loads(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else []
input_refs = json.loads(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] else {}
output_refs = json.loads(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5] else {}
transition_gate = sys.argv[6] if len(sys.argv) > 6 else ""

if not os.path.exists(contract_file):
    raise SystemExit(0)

try:
    import yaml
except Exception as exc:
    print(f"FAIL: dispatch semantic handoff validation requires pyyaml: {exc}", file=sys.stderr)
    raise SystemExit(1)

contract = yaml.safe_load(open(contract_file, "r", encoding="utf-8")) or {}
semantics = contract.get("handoff_ref_semantics") if isinstance(contract, dict) else {}
if not isinstance(semantics, dict):
    raise SystemExit(0)

default_kind = str(semantics.get("default_kind") or "file_ref").strip() or "file_ref"
kinds = semantics.get("kinds")
by_ref_key = semantics.get("by_ref_key")
if not isinstance(kinds, dict):
    print("FAIL: handoff_ref_semantics.kinds missing/invalid", file=sys.stderr)
    raise SystemExit(1)
if not isinstance(by_ref_key, dict):
    by_ref_key = {}

compiled = {}
for kind, meta in kinds.items():
    if not isinstance(meta, dict):
        continue
    pattern = str(meta.get("regex") or "").strip()
    if not pattern:
        continue
    try:
        compiled[str(kind).strip()] = re.compile(pattern)
    except re.error as exc:
        print(f"FAIL: invalid handoff_ref_semantics regex for kind '{kind}': {exc}", file=sys.stderr)
        raise SystemExit(1)

if default_kind not in compiled:
    print(f"FAIL: default handoff ref kind '{default_kind}' has no regex", file=sys.stderr)
    raise SystemExit(1)

def validate_ref(ref_key: str, ref_value: str, channel: str):
    kind = str(by_ref_key.get(ref_key) or default_kind).strip() or default_kind
    regex = compiled.get(kind)
    if regex is None:
        return (
            f"{channel} ref '{ref_key}' mapped to unknown kind '{kind}'"
        )
    if not isinstance(ref_value, str) or not regex.match(ref_value):
        return (
            f"{channel} ref '{ref_key}' value '{ref_value}' invalid for kind '{kind}'"
        )
    return None

errors = []
for key in required_inputs:
    name = str(key).strip()
    if not name:
        continue
    value = str(input_refs.get(name, "")).strip()
    msg = validate_ref(name, value, "input")
    if msg:
        errors.append(msg)

for key in required_outputs:
    name = str(key).strip()
    if not name:
        continue
    value = str(output_refs.get(name, "")).strip()
    msg = validate_ref(name, value, "output")
    if msg:
        errors.append(msg)

if errors:
    print(
        f"FAIL: dispatch handoff ref semantics invalid for gate {transition_gate or 'unknown'}",
        file=sys.stderr,
    )
    for err in errors:
        print(f"  - {err}", file=sys.stderr)
    raise SystemExit(1)
PYREFSEM
  fi

  local dispatch_mode=""
  dispatch_mode="$(python3 - "$sf" <<'PYDISPATCHMODE'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    state = json.load(f)

packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
execution_mode = str(packet.get("execution_mode") or "code").strip() or "code"
transport = str(packet.get("transport") or "git").strip() or "git"
print(f"{execution_mode}|{transport}")
PYDISPATCHMODE
)"
  local wave_execution_mode=""
  local wave_transport=""
  IFS='|' read -r wave_execution_mode wave_transport <<<"$dispatch_mode"

  if [[ "$wave_execution_mode" == "operational" || "$wave_transport" == "mailroom" ]]; then
    _dispatch_operational_mailroom "$sf" "$lane" "$task" "$from_role" "$to_role" "$transition_gate" "$input_refs_json" "$output_refs_json"
    sync_runtime_traffic_index "$sf" "dispatch"
    return
  fi

  python3 - "$sf" "$lane" "$task" "$from_role" "$to_role" "$transition_gate" "$input_refs_json" "$output_refs_json" "$dispatch_terminal_identity" <<'PYDISP'
import json, sys, fcntl, os
import tempfile
from datetime import datetime, timezone

sf = sys.argv[1]
lane = sys.argv[2]
task = sys.argv[3]
from_role = sys.argv[4] if len(sys.argv) > 4 else ""
to_role = sys.argv[5] if len(sys.argv) > 5 else ""
transition_gate = sys.argv[6] if len(sys.argv) > 6 else ""
input_refs = json.loads(sys.argv[7]) if len(sys.argv) > 7 and sys.argv[7] else {}
expected_output_refs = json.loads(sys.argv[8]) if len(sys.argv) > 8 and sys.argv[8] else {}
dispatched_by_terminal = sys.argv[9] if len(sys.argv) > 9 else ""
lock_file = sf + ".lock"

def _atomic_write_json(path, payload):
    if not path:
        return
    dirpath = os.path.dirname(path) or "."
    os.makedirs(dirpath, exist_ok=True)
    fd_tmp = None
    tmp_path = None
    try:
        fd_tmp, tmp_path = tempfile.mkstemp(prefix=".state-", suffix=".tmp", dir=dirpath)
        with os.fdopen(fd_tmp, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
            fh.flush()
            os.fsync(fh.fileno())
        fd_tmp = None
        os.replace(tmp_path, path)
        tmp_path = None
    finally:
        if fd_tmp is not None:
            try:
                os.close(fd_tmp)
            except OSError:
                pass
        if tmp_path is not None:
            try:
                os.unlink(tmp_path)
            except FileNotFoundError:
                pass

fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf) as f:
        state = json.load(f)
    packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}

    idx = len(state["dispatches"]) + 1
    task_id = f"D{idx}"

    dispatch = {
        "task_id": task_id,
        "lane": lane,
        "task": task,
        "from_role": from_role,
        "to_role": to_role,
        "transition_gate": transition_gate,
        "input_refs": input_refs,
        "expected_output_refs": expected_output_refs,
        "status": "dispatched",
        "dispatched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "dispatched_by_terminal": dispatched_by_terminal,
        "completed_at": None,
        "result": None,
        "run_key": None,
        "receipt_validated": False
    }

    state["dispatches"].append(dispatch)

    lane_outcomes = packet.get("lane_outcomes") if isinstance(packet.get("lane_outcomes"), list) else []
    lane_updated = False
    for row in lane_outcomes:
        if not isinstance(row, dict):
            continue
        if str(row.get("lane_id", "")).strip() != lane:
            continue
        row["lane_status"] = "DISPATCHED"
        row["owner_terminal"] = str(row.get("owner_terminal") or packet.get("owner_terminal") or "").strip()
        row["updated_at_utc"] = dispatch["dispatched_at"]
        lane_updated = True
        break
    if not lane_updated:
        lane_outcomes.append(
            {
                "lane_id": lane,
                "lane_status": "DISPATCHED",
                "owner_terminal": str(packet.get("owner_terminal") or "").strip(),
                "stub_evidence_ref": "",
                "updated_at_utc": dispatch["dispatched_at"],
            }
        )
    packet["lane_outcomes"] = lane_outcomes
    state["packet"] = packet

    role_flow = state.get("role_flow") if isinstance(state.get("role_flow"), dict) else {}
    if from_role and not role_flow.get("current_role"):
        role_flow["current_role"] = from_role
    if to_role:
        role_flow["next_role"] = to_role
    role_flow["pending_transition"] = {
        "task_id": task_id,
        "from_role": from_role,
        "to_role": to_role,
        "gate": transition_gate,
        "dispatched_at": dispatch["dispatched_at"],
    }
    state["role_flow"] = role_flow

    _atomic_write_json(sf, state)
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)

print(f"Dispatched task #{idx} to lane '{lane}':")
print(f"  Task: {task}")
print(f"  Dispatch ID: {task_id}")
print(f"  Status: dispatched")
if from_role or to_role:
    print(f"  Role transition: {from_role or '?'} -> {to_role or '?'} (gate={transition_gate or 'none'})")
if lane == "execution":
    print(f"  NOTE: execution lane is deny-scoped from canonical docs surfaces")
elif lane == "audit":
    print(f"  NOTE: audit lane is read-only")
PYDISP

  sync_runtime_traffic_index "$sf" "dispatch"
}

_dispatch_watcher() {
  local wave_id="$1"
  local sf="$2"
  local sd="$3"
  local task_desc="$4"

  # Default checks for the watcher (core-8 only, no duplicate pack run)
  local checks=("stability.control.snapshot" "verify.infra.run")

  python3 - "$sf" "$task_desc" <<'PYWATCHER_INIT'
import json, sys, fcntl, os
import tempfile
from datetime import datetime, timezone

sf = sys.argv[1]
task_desc = sys.argv[2]
lock_file = sf + ".lock"

def _atomic_write_json(path, payload):
    if not path:
        return
    dirpath = os.path.dirname(path) or "."
    os.makedirs(dirpath, exist_ok=True)
    fd_tmp = None
    tmp_path = None
    try:
        fd_tmp, tmp_path = tempfile.mkstemp(prefix=".state-", suffix=".tmp", dir=dirpath)
        with os.fdopen(fd_tmp, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
            fh.flush()
            os.fsync(fh.fileno())
        fd_tmp = None
        os.replace(tmp_path, path)
        tmp_path = None
    finally:
        if fd_tmp is not None:
            try:
                os.close(fd_tmp)
            except OSError:
                pass
        if tmp_path is not None:
            try:
                os.unlink(tmp_path)
            except FileNotFoundError:
                pass

fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf) as f:
        state = json.load(f)

    checks = [
        {"cap": "stability.control.snapshot", "status": "queued", "run_key": None, "pid": None, "exit_code": None},
        {"cap": "verify.infra.run", "status": "queued", "run_key": None, "pid": None, "exit_code": None}
    ]

    state["watcher_checks"] = checks
    state["dispatches"].append({
        "lane": "watcher",
        "task": task_desc,
        "status": "dispatched",
        "dispatched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "completed_at": None,
        "result": "background checks enqueued",
        "run_key": None
    })

    _atomic_write_json(sf, state)
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)

print(f"Dispatched watcher to lane 'watcher':")
print(f"  Task: {task_desc}")
print(f"  Enqueued {len(checks)} background checks:")
for c in checks:
    print(f"    - {c['cap']} [{c['status']}]")
print(f"  Checks run in background. Monitor: ops wave status {state['wave_id']}")
PYWATCHER_INIT

  # Launch background checks
  for cap_cmd in "${checks[@]}"; do
    _launch_background_check "$wave_id" "$sf" "$sd" "$cap_cmd" &
  done

  echo
  echo "Background checks launched. They will update wave state as they complete."
}

_launch_background_check() {
  local wave_id="$1"
  local sf="$2"
  local sd="$3"
  local cap_cmd="$4"
  local cap_name
  cap_name="$(echo "$cap_cmd" | awk '{print $1}')"
  local cap_args
  cap_args="$(echo "$cap_cmd" | awk '{$1=""; print $0}' | xargs)"

  local log_file="$sd/watcher-${cap_name//\./-}.log"
  local pid_file="$sd/watcher-${cap_name//\./-}.pid"
  # $$ in a subshell still returns parent PID on bash 3.2; use a python one-liner
  local my_pid
  my_pid="$(python3 -c 'import os; print(os.getpid())')"
  echo "$my_pid" > "$pid_file"

  # Mark as running (with file lock)
  python3 - "$sf" "$cap_cmd" "$my_pid" <<'PYMARK_RUN'
import json, sys, fcntl, os
import tempfile

sf = sys.argv[1]
cap = sys.argv[2]
pid = int(sys.argv[3])
lock_file = sf + ".lock"

def _atomic_write_json(path, payload):
    if not path:
        return
    dirpath = os.path.dirname(path) or "."
    os.makedirs(dirpath, exist_ok=True)
    fd_tmp = None
    tmp_path = None
    try:
        fd_tmp, tmp_path = tempfile.mkstemp(prefix=".state-", suffix=".tmp", dir=dirpath)
        with os.fdopen(fd_tmp, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
            fh.flush()
            os.fsync(fh.fileno())
        fd_tmp = None
        os.replace(tmp_path, path)
        tmp_path = None
    finally:
        if fd_tmp is not None:
            try:
                os.close(fd_tmp)
            except OSError:
                pass
        if tmp_path is not None:
            try:
                os.unlink(tmp_path)
            except FileNotFoundError:
                pass

fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf) as f:
        state = json.load(f)
    for c in state.get("watcher_checks", []):
        if c["cap"] == cap:
            c["status"] = "running"
            c["pid"] = pid
            break
    _atomic_write_json(sf, state)
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)
PYMARK_RUN

  # Run the capability
  local exit_code=0
  if [[ -n "$cap_args" ]]; then
    "$SPINE_REPO/bin/ops" cap run "$cap_name" $cap_args > "$log_file" 2>&1 || exit_code=$?
  else
    "$SPINE_REPO/bin/ops" cap run "$cap_name" > "$log_file" 2>&1 || exit_code=$?
  fi

  # Extract run key from cap output (matches "Run Key: <key>" line)
  local run_key=""
  run_key="$(grep -m1 'Run Key:' "$log_file" 2>/dev/null | awk '{print $NF}' || true)"
  # Fallback: CAP/S governed run-key pattern with alphanumeric suffix
  if [[ -z "$run_key" ]]; then
    run_key="$(grep -oE '(CAP-[0-9]{8}-[0-9]{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+|S[0-9]{8}-[0-9]{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+)' "$log_file" 2>/dev/null | head -1 || true)"
  fi

  # Mark as done/failed (with file lock)
  local final_status="done"
  if [[ "$exit_code" -ne 0 ]]; then
    final_status="failed"
  fi

  python3 - "$sf" "$cap_cmd" "$final_status" "$exit_code" "$run_key" <<'PYMARK_DONE'
import json, sys, fcntl, os
import tempfile
from datetime import datetime, timezone

sf = sys.argv[1]
cap = sys.argv[2]
status = sys.argv[3]
exit_code = int(sys.argv[4])
run_key = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else None
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
lock_file = sf + ".lock"

def _atomic_write_json(path, payload):
    if not path:
        return
    dirpath = os.path.dirname(path) or "."
    os.makedirs(dirpath, exist_ok=True)
    fd_tmp = None
    tmp_path = None
    try:
        fd_tmp, tmp_path = tempfile.mkstemp(prefix=".state-", suffix=".tmp", dir=dirpath)
        with os.fdopen(fd_tmp, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
            fh.flush()
            os.fsync(fh.fileno())
        fd_tmp = None
        os.replace(tmp_path, path)
        tmp_path = None
    finally:
        if fd_tmp is not None:
            try:
                os.close(fd_tmp)
            except OSError:
                pass
        if tmp_path is not None:
            try:
                os.unlink(tmp_path)
            except FileNotFoundError:
                pass

fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf) as f:
        state = json.load(f)
    for c in state.get("watcher_checks", []):
        if c["cap"] == cap:
            c["status"] = status
            c["exit_code"] = exit_code
            c["run_key"] = run_key
            c["completed_at"] = now
            break
    _atomic_write_json(sf, state)
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)
PYMARK_DONE

  rm -f "$pid_file"
}

cmd_collect() {
  local wave_id="${1:-}"
  if [[ -z "$wave_id" ]]; then
    echo "Usage: ops wave collect <WAVE_ID>" >&2
    exit 1
  fi

  ensure_wave_exists "$wave_id"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local sd
  sd="$(wave_state_dir "$wave_id")"

  python3 - "$sf" "$sd" <<'PYCOLLECT'
import json, sys, os, glob, fcntl

sf = sys.argv[1]
sd = sys.argv[2]

with open(sf) as f:
    fcntl.flock(f, fcntl.LOCK_SH)
    try:
        state = json.load(f)
    finally:
        fcntl.flock(f, fcntl.LOCK_UN)

print("=" * 72)
print(f"  WAVE COLLECT: {state['wave_id']}")
print("=" * 72)
print()

# Collect dispatch results
dispatches = state.get("dispatches", [])
print(f"DISPATCHES ({len(dispatches)})")
print("-" * 72)
for i, d in enumerate(dispatches, 1):
    print(f"  #{i} [{d['lane']:10s}] {d['status']:12s} {d['task'][:50]}")
    if d.get("run_key"):
        print(f"     run_key: {d['run_key']}")
    if d.get("dispatch_transport") == "mailroom":
        mtid = d.get("mailroom_task_id", "")
        mstate = d.get("mailroom_task_state", "")
        route_input = d.get("mailroom_route_input", "")
        detail = f"     mailroom: {mtid}" if mtid else "     mailroom: queued"
        if mstate:
            detail += f" [{mstate}]"
        if route_input:
            detail += f" route={route_input}"
        print(detail)
print()

# Collect watcher results
checks = state.get("watcher_checks", [])
if checks:
    done_count = sum(1 for c in checks if c["status"] == "done")
    fail_count = sum(1 for c in checks if c["status"] == "failed")
    running_count = sum(1 for c in checks if c["status"] == "running")
    queued_count = sum(1 for c in checks if c["status"] == "queued")

    print(f"WATCHER CHECKS ({len(checks)}: {done_count} done, {fail_count} failed, {running_count} running, {queued_count} queued)")
    print("-" * 72)
    for c in checks:
        rk = f" run_key={c['run_key']}" if c.get("run_key") else ""
        ec = f" exit={c['exit_code']}" if c.get("exit_code") is not None else ""
        print(f"  [{c['status']:8s}] {c['cap']}{ec}{rk}")

    # Show log snippets for failed checks
    for c in checks:
        if c["status"] == "failed":
            cap_slug = c["cap"].split()[0].replace(".", "-")
            log_file = os.path.join(sd, f"watcher-{cap_slug}.log")
            if os.path.exists(log_file):
                with open(log_file) as lf:
                    lines = lf.readlines()
                tail = lines[-5:] if len(lines) > 5 else lines
                print(f"\n  --- {c['cap']} (last 5 lines) ---")
                for line in tail:
                    print(f"  | {line.rstrip()}")
    print()

# Collect preflight
pf = state.get("preflight")
if pf:
    print(f"PREFLIGHT")
    print("-" * 72)
    print(f"  Domain: {pf.get('domain', '?')}")
    print(f"  Verdict: {pf.get('verdict', '?')}")
    print(f"  Duration: {pf.get('duration_s', '?')}s")
    if pf.get("blockers"):
        print(f"  Blockers:")
        for b in pf["blockers"]:
            print(f"    - {b}")
    print()

print("=" * 72)
all_done = all(c["status"] in ("done", "failed") for c in checks) if checks else True
if all_done:
    print("  All checks complete. Ready to close: ops wave close " + state["wave_id"] + " --disposition landed")
else:
    print("  Some checks still running. Re-check: ops wave status " + state["wave_id"])
print("=" * 72)
PYCOLLECT
}

cmd_status() {
  local status_surface="$SPINE_REPO/ops/plugins/core/orchestration/bin/wave-status"
  [[ -x "$status_surface" ]] || { echo "FAIL: wave status helper not found: $status_surface" >&2; exit 1; }
  "$status_surface" "$@"
}

_status_all() {
  local status_surface="$SPINE_REPO/ops/plugins/core/orchestration/bin/wave-status"
  [[ -x "$status_surface" ]] || { echo "FAIL: wave status helper not found: $status_surface" >&2; exit 1; }
  "$status_surface"
}

cmd_ack() {
  local ack_surface="$SPINE_REPO/ops/plugins/core/orchestration/bin/wave-ack"
  [[ -x "$ack_surface" ]] || { echo "FAIL: wave ack helper not found: $ack_surface" >&2; exit 1; }
  "$ack_surface" "$@"
}

# cmd_close() removed — dead code superseded by cmd_close_v2.
# The dispatch table at the bottom routes close) → cmd_close_v2 directly.
# Keeping this marker so git blame shows the removal context.

_cmd_close_was_here() { :; }
: <<'PYCLOSE'
import json, sys, os, fcntl
import tempfile
from datetime import datetime, timezone

sf = sys.argv[1]
sd = sys.argv[2]
force = sys.argv[3] == "true"
spine_repo = sys.argv[4] if len(sys.argv) > 4 else ""
lock_file = sf + ".lock"

def _atomic_write_json(path, payload):
    if not path:
        return
    dirpath = os.path.dirname(path) or "."
    os.makedirs(dirpath, exist_ok=True)
    fd_tmp = None
    tmp_path = None
    try:
        fd_tmp, tmp_path = tempfile.mkstemp(prefix=".state-", suffix=".tmp", dir=dirpath)
        with os.fdopen(fd_tmp, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
            fh.flush()
            os.fsync(fh.fileno())
        fd_tmp = None
        os.replace(tmp_path, path)
        tmp_path = None
    finally:
        if fd_tmp is not None:
            try:
                os.close(fd_tmp)
            except OSError:
                pass
        if tmp_path is not None:
            try:
                os.unlink(tmp_path)
            except FileNotFoundError:
                pass

fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf) as f:
        state = json.load(f)

    if state["status"] == "closed":
        print(f"Wave '{state['wave_id']}' is already closed.")
        sys.exit(0)

    # ── Synthetic wave fast-close ──
    _wave_kind = str(state.get("wave_kind") or "production").strip()
    _is_synthetic = _wave_kind == "synthetic"
    _is_engineering = _wave_kind == "engineering"
    _skip_ceremony = _is_synthetic or _is_engineering

    # ── Contract enforcement (wave.lifecycle.yaml) ──
    # Close requires: all watcher checks done/failed, preflight run at least once
    # Synthetic/test waves skip preflight and watcher requirements.
    # Engineering waves skip ceremony (preflight, watcher, role-flow) but
    # still enforce dispatch integrity and explicit disposition.
    checks = state.get("watcher_checks", [])
    pf = state.get("preflight")
    contract_violations = []

    if not _skip_ceremony:
        running = [c for c in checks if c["status"] in ("queued", "running")]
        if running:
            statuses = "/".join(sorted(set(c["status"] for c in running)))
            contract_violations.append(f"{len(running)} watcher check(s) still {statuses}")

        # Preflight is always required, not just when watcher checks exist
        if not pf:
            contract_violations.append("Preflight has not been run (required by wave.lifecycle contract)")

    dispatches = state.get("dispatches", []) if isinstance(state.get("dispatches"), list) else []
    pending_dispatches = [
        d for d in dispatches
        if isinstance(d, dict) and str(d.get("status", "")).strip() in {"dispatched", "running"}
    ]
    packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
    lane_outcomes = packet.get("lane_outcomes") if isinstance(packet.get("lane_outcomes"), list) else []

    def _stub_exists(ref: str) -> bool:
        text = str(ref or "").strip()
        if not text:
            return False
        if os.path.isabs(text):
            return os.path.exists(text)
        if spine_repo:
            return os.path.exists(os.path.join(spine_repo, text))
        return os.path.exists(text)

    def _lane_outcome(lane_id: str) -> dict:
        for row in lane_outcomes:
            if not isinstance(row, dict):
                continue
            if str(row.get("lane_id", "")).strip() == lane_id:
                return row
        return {}

    pending_without_stub = []
    for d in pending_dispatches:
        lane = str(d.get("lane", "")).strip()
        outcome = _lane_outcome(lane)
        lane_status = str(outcome.get("lane_status", "")).strip().lower()
        stub_ref = str(outcome.get("stub_evidence_ref", "")).strip()
        blocked_with_stub = lane_status in {"blocked", "stubbed_blocked", "blocked_stubbed"} and _stub_exists(stub_ref)
        if not blocked_with_stub:
            pending_without_stub.append(lane or "unknown")

    if pending_without_stub:
        pending_msg = (
            "dispatch pending without explicit blocked+stub evidence for lane(s): "
            + ", ".join(sorted(set(pending_without_stub)))
        )
        if force:
            print("BLOCKED: force-close denied while dispatches are pending without stub evidence.")
            print(f"  - {pending_msg}")
            print("Remediation: mark lane_outcomes as BLOCKED with valid stub_evidence_ref before retrying --force.")
            sys.exit(1)
        contract_violations.append(pending_msg)

    if contract_violations and not force:
        print("BLOCKED: Wave close contract not met:")
        for v in contract_violations:
            print(f"  - {v}")
        print()
        print("Options:")
        print(f"  1. Wait for checks to complete, then retry: ops wave close {state['wave_id']}")
        print(f"  2. Force close (skip contract): ops wave close {state['wave_id']} --force")
        sys.exit(1)

    if contract_violations and force:
        print(f"WARNING: Forcing close with {len(contract_violations)} contract violation(s):")
        for v in contract_violations:
            print(f"  - {v}")
        print()

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    state_field = "lifecycle_state"
    state["status"] = "closed"
    state["closed_at"] = now
    state["force_closed"] = bool(contract_violations)
    state[state_field] = "closed"
    state["lifecycle_state"] = "closed"
    workspace = state.get("workspace")
    if isinstance(workspace, dict) and workspace.get("enabled"):
        workspace["lifecycle_state"] = "pending_close"
        workspace["closed_at"] = now
        workspace["close_action"] = "explicit_cleanup_required"
        state["workspace"] = workspace

    _atomic_write_json(sf, state)
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)

# ── Generate merge receipt ──────────────────────────────────────────
done_checks = sum(1 for c in checks if c["status"] == "done")
failed_checks = sum(1 for c in checks if c["status"] == "failed")
run_keys = [c["run_key"] for c in checks if c.get("run_key")]
workspace = state.get("workspace") if isinstance(state.get("workspace"), dict) else {}
pf = state.get("preflight", {})

residual_blockers = []
# Contract violations are residual blockers when force-closed
for v in contract_violations:
    residual_blockers.append(f"Contract violation (force-closed): {v}")
for c in checks:
    if c["status"] == "failed":
        residual_blockers.append(f"Watcher check failed: {c['cap']} (exit={c.get('exit_code', '?')})")
if pf and pf.get("verdict") == "no-go":
    for b in pf.get("blockers", []):
        residual_blockers.append(f"Preflight blocker: {b}")

receipt_path = os.path.join(sd, "receipt.md")
with open(receipt_path, "w") as rf:
    rf.write(f"# Wave Merge Receipt: {state['wave_id']}\n\n")
    rf.write(f"- **Wave ID**: {state['wave_id']}\n")
    rf.write(f"- **Objective**: {state.get('objective', '(none)')}\n")
    rf.write(f"- **Created**: {state['created_at']}\n")
    rf.write(f"- **Closed**: {now}\n")
    rf.write(f"- **Status**: closed\n\n")
    if workspace.get("enabled"):
        rf.write("## Workspace Lifecycle\n\n")
        rf.write(f"- Repo: {workspace.get('repo')}\n")
        rf.write(f"- Worktree: {workspace.get('worktree')}\n")
        rf.write(f"- Branch: {workspace.get('branch')}\n")
        rf.write(f"- Lifecycle State: {workspace.get('lifecycle_state')}\n")
        rf.write("- Cleanup: explicit close path required (non-destructive by default)\n\n")

    rf.write(f"## Dispatches ({len(dispatches)})\n\n")
    for i, d in enumerate(dispatches, 1):
        rk = f" (run_key: {d['run_key']})" if d.get("run_key") else ""
        rf.write(f"{i}. [{d['lane']}] {d['task']}{rk} — {d['status']}\n")
    rf.write("\n")

    rf.write(f"## Watcher Checks ({len(checks)})\n\n")
    for c in checks:
        rk = f" R={c['run_key']}" if c.get("run_key") else ""
        ec = f" exit={c['exit_code']}" if c.get("exit_code") is not None else ""
        rf.write(f"- [{c['status']}] {c['cap']}{ec}{rk}\n")
    rf.write("\n")

    if pf:
        rf.write(f"## Preflight\n\n")
        rf.write(f"- Domain: {pf.get('domain', '?')}\n")
        rf.write(f"- Verdict: {pf.get('verdict', '?')}\n")
        rf.write(f"- Duration: {pf.get('duration_s', '?')}s\n")
        if pf.get("blockers"):
            rf.write(f"- Blockers:\n")
            for b in pf["blockers"]:
                rf.write(f"  - {b}\n")
        rf.write("\n")

    rf.write(f"## Run Keys\n\n")
    if run_keys:
        for rk in run_keys:
            rf.write(f"- {rk}\n")
    else:
        rf.write("(none collected)\n")
    rf.write("\n")

    rf.write(f"## Residual Blockers\n\n")
    if residual_blockers:
        for b in residual_blockers:
            rf.write(f"- {b}\n")
    else:
        rf.write("(none)\n")
    rf.write("\n")

    rf.write(f"## Roadmap Status Patch (draft)\n\n")
    rf.write(f"Wave {state['wave_id']} completed. ")
    if not residual_blockers:
        rf.write("All checks passed. Ready for adoption.\n")
    else:
        rf.write(f"{len(residual_blockers)} residual blocker(s) require attention.\n")
    rf.write("\n---\n")
    rf.write(f"READY_FOR_ADOPTION={'true' if not residual_blockers else 'false'}\n")

print(f"Wave '{state['wave_id']}' closed.")
print(f"  Dispatches: {len(dispatches)}")
print(f"  Checks: {done_checks} done, {failed_checks} failed")
if workspace.get("enabled"):
    print(f"  Workspace lifecycle: pending_close ({workspace.get('worktree')})")
if run_keys:
    print(f"  Run keys: {', '.join(run_keys)}")
if residual_blockers:
    print(f"  Residual blockers: {len(residual_blockers)}")
    for b in residual_blockers:
        print(f"    - {b}")
print(f"  Merge receipt: {receipt_path}")
print(f"  READY_FOR_ADOPTION={'true' if not residual_blockers else 'false'}")
PYCLOSE

cmd_preflight() {
  local domain=""
  local target_wave=""

  # Parse args: ops wave preflight <domain> [--wave WAVE_ID]
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --wave) target_wave="${2:-}"; shift 2 ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) domain="$1"; shift ;;
    esac
  done

  if [[ -z "$domain" ]]; then
    echo "Usage: ops wave preflight <domain> [--wave <WAVE_ID>]" >&2
    exit 1
  fi

  # Find the target wave to attach preflight results
  local active_wave_sf=""
  if [[ -n "$target_wave" ]]; then
    # Explicit wave target
    local twf
    twf="$(wave_state_file "$target_wave")"
    if [[ -f "$twf" ]]; then
      active_wave_sf="$twf"
    else
      echo "WARN: wave '$target_wave' not found, preflight will not be attached" >&2
    fi
  elif [[ -d "$WAVES_DIR" ]]; then
    # Auto-detect: count active waves; if exactly one, use it; if multiple, warn
    local active_count=0
    local first_active_sf=""
    for wdir in "$WAVES_DIR"/*/; do
      local wf="$wdir/state.json"
      if [[ -f "$wf" ]]; then
        local wstatus
        wstatus="$(python3 -c "import json; print(json.load(open('$wf')).get('status',''))" 2>/dev/null || true)"
        if [[ "$wstatus" == "active" ]]; then
          active_count=$((active_count + 1))
          if [[ -z "$first_active_sf" ]]; then
            first_active_sf="$wf"
          fi
        fi
      fi
    done
    if [[ "$active_count" -eq 1 ]]; then
      active_wave_sf="$first_active_sf"
    elif [[ "$active_count" -gt 1 ]]; then
      echo "WARN: $active_count active waves found. Use --wave <WAVE_ID> to target a specific one." >&2
    fi
  fi

  local start_time
  start_time="$(python3 -c 'import time; print(time.time())')"

  local blockers=()
  local verdict="go"
  local next_action=""
  local preflight_contract="$SPINE_REPO/ops/bindings/orchestration.preflight.scope.contract.yaml"
  local clean_mode="scope_clean_required"
  local scope_dirty_max="10"
  local ambient_blocking="false"
  local ambient_report_dir="$RUNTIME_ROOT/preflight/ambient-drift"
  local ambient_report=""
  local ambient_dirty_total=0
  local -a ambient_repos=("$SPINE_REPO" "$HOME/code/workbench" "$HOME/code/mint-modules")

  if [[ -f "$preflight_contract" ]] && command -v yq >/dev/null 2>&1; then
    clean_mode="$(yq e -r '.policy.clean_mode // "scope_clean_required"' "$preflight_contract" 2>/dev/null || echo "scope_clean_required")"
    scope_dirty_max="$(yq e -r '.policy.scope_dirty_max_files // 10' "$preflight_contract" 2>/dev/null || echo "10")"
    ambient_blocking="$(yq e -r '.policy.ambient_blocking // false' "$preflight_contract" 2>/dev/null || echo "false")"
    ambient_report_dir="$(yq e -r '.policy.ambient_report_dir // "'"$RUNTIME_ROOT/preflight/ambient-drift"'"' "$preflight_contract" 2>/dev/null || echo "$RUNTIME_ROOT/preflight/ambient-drift")"
    mapfile -t ambient_repos < <(yq e -r '.policy.ambient_repos[]?' "$preflight_contract" 2>/dev/null || true)
    if [[ "${#ambient_repos[@]}" -eq 0 ]]; then
      ambient_repos=("$SPINE_REPO" "$HOME/code/workbench" "$HOME/code/mint-modules")
    fi
  fi
  [[ "$scope_dirty_max" =~ ^[0-9]+$ ]] || scope_dirty_max="10"

  echo "=" * 72 2>/dev/null || true
  echo "========================================================================"
  echo "  PREFLIGHT: $domain (fast, non-blocking, <=120s target)"
  echo "========================================================================"
  echo

  # ── 1. Status tick (ops status --brief) ──
  echo "[1/4] Status tick..."
  local status_out
  status_out="$("$SPINE_REPO/bin/ops" status --brief 2>&1)" || true
  echo "  $status_out"

  # Check for anomalies in status
  if echo "$status_out" | grep -q "Anomalies: [1-9]"; then
    blockers+=("Status anomalies detected")
  fi
  echo

  # ── 2. Git state check (scope-clean + ambient-drift ledger) ──
  echo "[2/4] Git state..."
  local scope_repo="$SPINE_REPO"
  if [[ -n "$active_wave_sf" && -f "$active_wave_sf" ]]; then
    local scoped_repo
    scoped_repo="$(python3 -c "import json; s=json.load(open('$active_wave_sf')); w=(s.get('workspace') or {}); print(w.get('repo') or '')" 2>/dev/null || true)"
    if [[ -n "$scoped_repo" && "$scoped_repo" != "null" ]]; then
      scope_repo="$scoped_repo"
    fi
  fi

  local scope_repo_real
  scope_repo_real="$(python3 -c "import os; print(os.path.realpath('$scope_repo'))" 2>/dev/null || echo "$scope_repo")"
  local branch
  branch="$(git -C "$scope_repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
  local dirty
  dirty="$(git -C "$scope_repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  echo "  Scope clean mode: $clean_mode"
  echo "  Scope repo: $scope_repo_real"
  echo "  Scope branch: $branch"
  echo "  Scope dirty files: $dirty"
  if [[ "$clean_mode" == "scope_clean_required" ]] && [[ "$dirty" -gt "$scope_dirty_max" ]]; then
    blockers+=("Scope dirty files exceed threshold ($dirty > $scope_dirty_max) in $scope_repo_real")
  fi

  local ambient_rows=()
  local repo
  for repo in "${ambient_repos[@]}"; do
    [[ -n "$repo" && "$repo" != "null" ]] || continue
    repo="${repo/#\~/$HOME}"
    if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      continue
    fi
    local repo_real
    repo_real="$(python3 -c "import os; print(os.path.realpath('$repo'))" 2>/dev/null || echo "$repo")"
    if [[ "$repo_real" == "$scope_repo_real" ]]; then
      continue
    fi
    local repo_branch repo_dirty
    repo_branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
    repo_dirty="$(git -C "$repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$repo_dirty" -gt 0 ]]; then
      ambient_dirty_total=$((ambient_dirty_total + repo_dirty))
      ambient_rows+=("$repo_real|$repo_branch|$repo_dirty")
    fi
  done

  mkdir -p "$ambient_report_dir"
  ambient_report="$ambient_report_dir/ambient-drift-$(date -u +%Y%m%dT%H%M%SZ).md"
  {
    echo "# Ambient Drift Ledger"
    echo
    echo "- checked_at: $(ts_now)"
    echo "- clean_mode: $clean_mode"
    echo "- scope_repo: $scope_repo_real"
    echo "- scope_dirty_files: $dirty"
    echo
    echo "| Repo | Branch | Dirty Files |"
    echo "|---|---|---:|"
    if [[ "${#ambient_rows[@]}" -eq 0 ]]; then
      echo "| (none) | - | 0 |"
    else
      local row
      for row in "${ambient_rows[@]}"; do
        IFS='|' read -r rr rb rd <<< "$row"
        echo "| $rr | $rb | $rd |"
      done
    fi
  } > "$ambient_report"

  echo "  Ambient drift report: $ambient_report"
  if [[ "$ambient_dirty_total" -gt 0 ]]; then
    echo "  Ambient dirty files (non-scope): $ambient_dirty_total"
    if [[ "$ambient_blocking" == "true" ]]; then
      blockers+=("Ambient drift blocking enabled: $ambient_dirty_total dirty files outside scope")
    fi
  fi
  echo

  # ── 3. Domain health (targeted, fast) ──
  echo "[3/4] Domain health ($domain)..."
  case "$domain" in
    mint|mint-*)
      # Quick health check via MCP or curl
      local mint_health="unknown"
      if command -v curl >/dev/null 2>&1; then
        # Try mint module health endpoint (fast, 5s timeout)
        local mh_out
        local mint_health_url="http://finance-adapter:3600/health"
        local services_health="$SPINE_REPO/ops/bindings/services.health.yaml"
        if command -v yq >/dev/null 2>&1 && [[ -f "$services_health" ]]; then
          local mapped_mint_health_url
          mapped_mint_health_url="$(yq e -r '.endpoints[] | select(.id=="finance-adapter") | .url // ""' "$services_health" 2>/dev/null | head -n1)"
          if [[ -n "$mapped_mint_health_url" ]]; then
            mint_health_url="$mapped_mint_health_url"
          fi
        fi
        mh_out="$(curl -s --connect-timeout 5 --max-time 10 "$mint_health_url" 2>/dev/null || echo 'unreachable')"
        if echo "$mh_out" | grep -qi "ok\|healthy\|alive"; then
          mint_health="healthy"
        elif [[ "$mh_out" == "unreachable" ]]; then
          mint_health="unreachable"
          blockers+=("Mint module health endpoint unreachable")
        else
          mint_health="degraded"
        fi
      fi
      echo "  Mint health: $mint_health"
      ;;
    ha|home-assistant)
      local ha_health="unknown"
      if command -v curl >/dev/null 2>&1; then
        local ha_out
        local ha_health_url="http://home-assistant:8123/api/"
        local services_health="$SPINE_REPO/ops/bindings/services.health.yaml"
        if command -v yq >/dev/null 2>&1 && [[ -f "$services_health" ]]; then
          local mapped_ha_health_url
          mapped_ha_health_url="$(yq e -r '.endpoints[] | select(.id=="home-assistant") | .url // ""' "$services_health" 2>/dev/null | head -n1)"
          if [[ -n "$mapped_ha_health_url" ]]; then
            ha_health_url="$mapped_ha_health_url"
          fi
        fi
        ha_out="$(curl -s --connect-timeout 5 --max-time 10 "$ha_health_url" 2>/dev/null || echo 'unreachable')"
        if echo "$ha_out" | grep -qi "API running\|message"; then
          ha_health="healthy"
        else
          ha_health="unreachable"
          blockers+=("HA API unreachable")
        fi
      fi
      echo "  HA health: $ha_health"
      ;;
    *)
      echo "  (no targeted health check for domain '$domain')"
      ;;
  esac
  echo

  # ── 4. Lane readiness ──
  echo "[4/4] Lane readiness..."
  if [[ -f "$LANES_STATE" ]]; then
    local lane_count
    lane_count="$(python3 -c "import json; print(len(json.load(open('$LANES_STATE')).get('lanes', {})))" 2>/dev/null || echo '0')"
    echo "  Open lanes: $lane_count"
  else
    echo "  No lanes state (run: ops lane open <profile>)"
  fi
  echo

  # ── Compute verdict ──
  local end_time
  end_time="$(python3 -c 'import time; print(time.time())')"
  local duration_s
  duration_s="$(python3 -c "print(round($end_time - $start_time, 1))")"

  if [[ ${#blockers[@]} -gt 0 ]]; then
    verdict="no-go"
    next_action="Resolve blockers before proceeding"
  else
    next_action="Dispatch work: ops wave dispatch <WAVE_ID> --lane <lane> --task \"...\""
  fi

  echo "========================================================================"
  echo "  VERDICT: $verdict  |  Duration: ${duration_s}s  |  Blockers: ${#blockers[@]}"
  if [[ ${#blockers[@]} -gt 0 ]]; then
    for b in "${blockers[@]}"; do
      echo "    BLOCKER: $b"
    done
  fi
  echo "  Next: $next_action"
  echo "========================================================================"

  # Attach to active wave if one exists
  if [[ -n "$active_wave_sf" && -f "$active_wave_sf" ]]; then
    python3 -c "
import json
import os
import tempfile
sf = '$active_wave_sf'
with open(sf) as f:
    state = json.load(f)
blockers_list = $(python3 -c "import json; print(json.dumps([$(printf '"%s",' "${blockers[@]}" | sed 's/,$//')]))" 2>/dev/null || echo '[]')
state['preflight'] = {
    'domain': '$domain',
    'verdict': '$verdict',
    'duration_s': $duration_s,
    'blockers': blockers_list,
    'scope_clean_mode': '$clean_mode',
    'scope_repo': '$scope_repo_real',
    'scope_dirty_files': int('$dirty'),
    'ambient_dirty_files': int('$ambient_dirty_total'),
    'ambient_report': '$ambient_report',
    'next_action': '$next_action',
    'checked_at': '$(ts_now)'
}
dirpath = os.path.dirname(sf) or '.'
os.makedirs(dirpath, exist_ok=True)
fd_tmp = None
tmp_path = None
try:
    fd_tmp, tmp_path = tempfile.mkstemp(prefix='.state-', suffix='.tmp', dir=dirpath)
    with os.fdopen(fd_tmp, 'w', encoding='utf-8') as f:
        json.dump(state, f, indent=2)
        f.write('\n')
        f.flush()
        os.fsync(f.fileno())
    fd_tmp = None
    os.replace(tmp_path, sf)
    tmp_path = None
finally:
    if fd_tmp is not None:
        try:
            os.close(fd_tmp)
        except OSError:
            pass
    if tmp_path is not None:
        try:
            os.unlink(tmp_path)
        except FileNotFoundError:
            pass
" 2>/dev/null || true
    echo
    echo "  Preflight attached to active wave."
    sync_runtime_traffic_index "$active_wave_sf" "preflight"
  fi
}

# ── Receipt validation (pure Python, no external deps) ─────────────────

cmd_receipt_validate() {
  local validator="$SPINE_REPO/ops/plugins/core/orchestration/bin/wave-receipt-validate"
  [[ -x "$validator" ]] || { echo "FAIL: wave receipt validator not found: $validator" >&2; exit 1; }
  "$validator" "$@"
}

# ── Enhanced collect with receipt ingestion ────────────────────────────

cmd_collect_v2() {
  local wave_id=""
  local sync_roadmap=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --sync-roadmap) sync_roadmap=true; shift ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) wave_id="$1"; shift ;;
    esac
  done

  if [[ -z "$wave_id" ]]; then
    echo "Usage: ops wave collect <WAVE_ID> [--sync-roadmap]" >&2
    exit 1
  fi

  ensure_wave_exists "$wave_id"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local sd
  sd="$(wave_state_dir "$wave_id")"
  local receipts_dir="$sd/evidence"
  local schema_path="$SPINE_REPO/ops/bindings/orchestration.exec_receipt.schema.json"
  local collect_surface="$SPINE_REPO/ops/plugins/core/orchestration/bin/wave-collect"
  load_runtime_role_control
  [[ -x "$collect_surface" ]] || { echo "FAIL: wave collect helper not found: $collect_surface" >&2; exit 1; }
  "$collect_surface" "$sf" "$sd" "$receipts_dir" "$SPINE_STATE/agent-tasks" "$schema_path" "$sync_roadmap" "$SPINE_REPO" "$ROLE_RUNTIME_CONTRACT" "$(wave_allowed_lanes_csv)" "$TRAFFIC_INDEX_FILE"
}

# ── Enhanced close with receipt gating ─────────────────────────────────

cmd_close_v2() {
  local wave_id=""
  local force=false
  local controller_only=false
  local controller_verify_receipt=""
  local fixed_in=""
  local dod_override_reason=""
  local lock_override_reason=""
  local disposition=""
  local completion_level=""
  local allowed_dispositions_csv=""
  local allowed_completion_levels_csv=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --force) force=true; shift ;;
      --controller-only)
        controller_only=true
        shift
        ;;
      --verify-receipt)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          echo "ERROR: --verify-receipt requires a non-empty value" >&2
          exit 1
        fi
        controller_verify_receipt="${2:-}"
        shift 2
        ;;
      --fixed-in)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          echo "ERROR: --fixed-in requires a non-empty value" >&2
          exit 1
        fi
        fixed_in="${2:-}"
        shift 2
        ;;
      --disposition)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          echo "ERROR: --disposition requires a non-empty value" >&2
          exit 1
        fi
        disposition="${2:-}"
        shift 2
        ;;
      --completion-level)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          echo "ERROR: --completion-level requires a non-empty value" >&2
          exit 1
        fi
        completion_level="${2:-}"
        shift 2
        ;;
      --dod-override)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          echo "ERROR: --dod-override requires a non-empty reason" >&2
          exit 1
        fi
        dod_override_reason="${2:-}"
        shift 2
        ;;
      --lock-override)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          echo "ERROR: --lock-override requires a non-empty reason" >&2
          exit 1
        fi
        lock_override_reason="${2:-}"
        shift 2
        ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) wave_id="$1"; shift ;;
    esac
  done

  if [[ -z "$wave_id" ]]; then
    echo "Usage: ops wave close <WAVE_ID> --disposition <state> [--completion-level <level>] [--force] [--controller-only --verify-receipt <receipt> --fixed-in <sha>] [--dod-override \"<reason>\"] [--lock-override \"<reason>\"]" >&2
    exit 1
  fi
  allowed_dispositions_csv="$(close_dispositions_csv)"
  allowed_completion_levels_csv="$(close_completion_levels_csv)"
  require_close_disposition "$disposition" "$allowed_dispositions_csv"
  require_close_completion_level "$disposition" "$completion_level" "$allowed_completion_levels_csv"

  ensure_wave_exists "$wave_id"
  wave_lock_guard "$wave_id" "close" "$lock_override_reason"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local sd
  sd="$(wave_state_dir "$wave_id")"

  local close_surface="$SPINE_REPO/ops/plugins/core/orchestration/bin/wave-close"
  load_runtime_role_control
  [[ -x "$close_surface" ]] || { echo "FAIL: wave close helper not found: $close_surface" >&2; exit 1; }
  WAVE_CLOSE_VERIFY_RECEIPT="$controller_verify_receipt" \
  WAVE_CLOSE_FIXED_IN="$fixed_in" \
  WAVE_CLOSE_ROLE_RUNTIME_CONTRACT="$ROLE_RUNTIME_CONTRACT" \
  WAVE_CLOSE_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT" \
  WAVE_CLOSE_ALLOWED_DISPOSITIONS_CSV="$allowed_dispositions_csv" \
  WAVE_CLOSE_ALLOWED_LANES_CSV="$(wave_allowed_lanes_csv)" \
  WAVE_CLOSE_PATH_CLAIMS_FILE="$PATH_CLAIMS_FILE" \
  WAVE_CLOSE_TRAFFIC_INDEX_FILE="$TRAFFIC_INDEX_FILE" \
  "$close_surface" "$sf" "$force" "$dod_override_reason" "$lock_override_reason" "$disposition" "$completion_level" "$controller_only"
}

# ── Agent-result -> EXEC_RECEIPT bridge ────────────────────────────────
# Controller boundary: converts an in-band Agent-tool subagent result into a
# worker-class EXEC_RECEIPT JSON artifact under waves/<WAVE_ID>/evidence/.
# Preserves the single receipt model so `ops wave receipt-validate` remains
# authoritative for every dispatch, regardless of whether the worker was a
# shell lane or an Agent-tool subagent.
cmd_emit_agent_receipt() {
  local emitter="$SPINE_REPO/ops/plugins/core/orchestration/bin/wave-emit-agent-receipt"
  [[ -x "$emitter" ]] || { echo "FAIL: wave emit-agent-receipt helper not found: $emitter" >&2; exit 1; }
  "$emitter" "$@"
}

cmd_residue() {
  local residue_surface="$SPINE_REPO/ops/plugins/core/lifecycle/bin/wave-residue"
  [[ -x "$residue_surface" ]] || { echo "FAIL: wave residue helper not found: $residue_surface" >&2; return 1; }
  "$residue_surface" "$@"
}

# ── Dispatch ─────────────────────────────────────────────────────────────

case "${1:-}" in
  start)              shift; cmd_start "$@" ;;
  dispatch)           shift; cmd_dispatch "$@" ;;
  ack)                shift; cmd_ack "$@" ;;
  collect)            shift; cmd_collect_v2 "$@" ;;
  status)             shift; cmd_status "$@" ;;
  claims-reconcile)   shift; cmd_claims_reconcile "$@" ;;
  close)              shift; cmd_close_v2 "$@" ;;
  preflight)          shift; cmd_preflight "$@" ;;
  receipt-validate)   shift; cmd_receipt_validate "$@" ;;
  emit-agent-receipt) shift; cmd_emit_agent_receipt "$@" ;;
  residue)            shift; cmd_residue "$@" ;;
  -h|--help)          usage ;;
  "")                 usage ;;
  *)
    echo "Unknown wave subcommand: $1" >&2
    usage
    exit 1
    ;;
esac
