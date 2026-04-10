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
#   ops wave close <WAVE_ID> --disposition <state>
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
RUNTIME_PATHS_LIB="$SPINE_REPO/ops/lib/runtime-paths.sh"
[[ -f "$RUNTIME_PATHS_LIB" ]] || { echo "FATAL: runtime-paths.sh not found at $RUNTIME_PATHS_LIB" >&2; exit 1; }
source "$RUNTIME_PATHS_LIB"
spine_runtime_resolve_paths
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

resolve_wave_worktree_prefix() {
  local repo_path="${1:-$SPINE_REPO}"
  local lifecycle_contract="$SPINE_REPO/ops/bindings/worktree.lifecycle.contract.yaml"
  local canonical_root="/Users/ronnyworks/code/.runtime/spine/tmp/worktrees"
  local repo_root=""
  local repo_name=""

  repo_root="$(git -C "$repo_path" rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$repo_root" ]] || repo_root="$SPINE_REPO"
  repo_name="$(basename "$repo_root")"
  [[ -n "$repo_name" ]] || repo_name="agentic-spine"

  if command -v yq >/dev/null 2>&1 && [[ -f "$lifecycle_contract" ]]; then
    canonical_root="$(yq e -r '.policy.canonical_worktree_root // "/Users/ronnyworks/code/.runtime/spine/tmp/worktrees"' "$lifecycle_contract" 2>/dev/null || echo "$canonical_root")"
  fi
  if [[ "$canonical_root" == "~/"* ]]; then
    canonical_root="$HOME/${canonical_root#~/}"
  fi

  printf '%s/%s/\n' "${canonical_root%/}" "$repo_name"
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
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)
        fh.write("\n")


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
  ops wave close <WAVE_ID> --disposition <state> [--force] [--dod-override "<reason>"] [--lock-override "<reason>"]  Close a wave
  ops wave preflight <domain>                        Fast non-blocking preflight
  ops wave receipt-validate <path>                   Validate EXEC_RECEIPT JSON
  ops wave emit-agent-receipt <WAVE_ID> --lane <L>|--dispatch D<N> --result "<text>" [--file-read <p>]... [--task-id <id>]
                                                    Bridge: emit worker-class EXEC_RECEIPT JSON for an in-band Agent-tool subagent result

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
  verify.core.run, verify.pack.run) and tracks them without blocking.
  Results appear in 'ops wave status' when complete.
EOF
}

wave_start_usage() {
  echo "Usage: ops wave start <WAVE_ID> --objective \"<text>\" [--loop-id <LOOP_ID>] [--deadline-utc <ISO8601>] [--horizon now|later|future] [--execution-readiness runnable|blocked] [--claimed-paths \"a,b\"] [--worktree auto|off] [--repo <path>]" >&2
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
  if [[ "$worktree_mode" != "auto" && "$worktree_mode" != "off" ]]; then
    echo "Usage: --worktree must be auto or off (got: $worktree_mode)" >&2
    exit 1
  fi

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
    workspace_repo="$(git -C "$workspace_repo" rev-parse --show-toplevel 2>/dev/null || true)"
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
    cat > "$lease_path" <<EOF
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

  python3 - "$sf" "$wave_id" "$objective" "$workspace_enabled" "$workspace_repo" "$workspace_worktree" "$workspace_branch" "$workspace_note" "$default_role" "$default_next_role" "$loop_id" "$deadline_utc" "$horizon" "$execution_readiness" "$owner_terminal" "$claimed_paths_json" "$packet_required_fields" "$packet_allowed_horizon" "$packet_allowed_readiness" "$packet_allowed_roles" "$PATH_CLAIMS_FILE" "$PATH_CLAIMS_TTL_MINUTES" "$PATH_CLAIMS_NON_OVERLAP" "$wave_kind" <<'PYSTART'
import json, sys
import os
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
deadline_utc = sys.argv[12] if len(sys.argv) > 12 else ""
horizon = sys.argv[13] if len(sys.argv) > 13 else ""
execution_readiness = sys.argv[14] if len(sys.argv) > 14 else ""
owner_terminal = sys.argv[15] if len(sys.argv) > 15 else ""
claimed_paths = json.loads(sys.argv[16]) if len(sys.argv) > 16 and sys.argv[16] else []
required_fields = [x.strip() for x in (sys.argv[17] if len(sys.argv) > 17 else "").split(",") if x.strip()]
allowed_horizon = {x.strip() for x in (sys.argv[18] if len(sys.argv) > 18 else "now,later,future").split(",") if x.strip()}
allowed_readiness = {x.strip() for x in (sys.argv[19] if len(sys.argv) > 19 else "runnable,blocked").split(",") if x.strip()}
allowed_roles = {
    x.strip() for x in (sys.argv[20] if len(sys.argv) > 20 else "researcher,worker,qc,close,librarian").split(",") if x.strip()
}
path_claims_file = sys.argv[21] if len(sys.argv) > 21 else ""
path_claims_ttl_minutes = 180
try:
    path_claims_ttl_minutes = int(sys.argv[22]) if len(sys.argv) > 22 else 180
except Exception:
    path_claims_ttl_minutes = 180
path_claims_non_overlap = (sys.argv[23].lower() == "true") if len(sys.argv) > 23 else True
wave_kind = (sys.argv[24].strip() if len(sys.argv) > 24 and sys.argv[24].strip() else "production")
single_terminal_mode = str(owner_terminal or "").strip().startswith("SPINE-CONTROL-")

packet = {
    "schema_version": "1.0",
    "wave_id": wave_id,
    "wave_kind": wave_kind,
    "loop_id": loop_id,
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
normalized_claims.append(
    {
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
)
claims_payload = {
    "schema_version": "1.0",
    "updated_at": now,
    "claims": normalized_claims,
}
if path_claims_file:
    _save_doc(path_claims_file, claims_payload)
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
    "packet": packet,
    # Compatibility alias: governance contracts use wave_packet naming.
    "wave_packet": packet,
}

with open(sf, "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

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
from datetime import datetime, timezone

sf = sys.argv[1]
spine_repo = sys.argv[2]
lane = sys.argv[3]
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def run(cmd):
    proc = subprocess.run(cmd, text=True, capture_output=True)
    return proc.returncode, (proc.stdout or "").strip(), (proc.stderr or "").strip()

state = json.load(open(sf, "r", encoding="utf-8"))
workspace = state.get("workspace") if isinstance(state.get("workspace"), dict) else {}
packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
if not packet and isinstance(state.get("wave_packet"), dict):
    packet = state["wave_packet"]
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
    state["wave_packet"] = packet
    with open(sf, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
        f.write("\n")

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
    state["wave_packet"] = packet
    with open(sf, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
        f.write("\n")

    print("BLOCKED: dispatch pushability preflight failed")
    for msg in errors:
        print(f"  - {msg}")
    if stub_rel:
        print(f"  blocker_stub: {stub_rel}")
    raise SystemExit(1)

state["packet"] = packet
state["wave_packet"] = packet
state["preflight"] = {
    "domain": "dispatch-pushability",
    "started_at": now,
    "finished_at": now,
    "duration_s": 0,
    "verdict": "go",
    "blockers": [],
    "next_action": "Proceed with dispatch.",
}
with open(sf, "w", encoding="utf-8") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

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
    state["wave_packet"] = packet

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

    with open(sf, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
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

  python3 - "$sf" "$lane" "$task" "$from_role" "$to_role" "$transition_gate" "$input_refs_json" "$output_refs_json" <<'PYDISP'
import json, sys, fcntl, os
from datetime import datetime, timezone

sf = sys.argv[1]
lane = sys.argv[2]
task = sys.argv[3]
from_role = sys.argv[4] if len(sys.argv) > 4 else ""
to_role = sys.argv[5] if len(sys.argv) > 5 else ""
transition_gate = sys.argv[6] if len(sys.argv) > 6 else ""
input_refs = json.loads(sys.argv[7]) if len(sys.argv) > 7 and sys.argv[7] else {}
expected_output_refs = json.loads(sys.argv[8]) if len(sys.argv) > 8 and sys.argv[8] else {}
lock_file = sf + ".lock"

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
    state["wave_packet"] = packet

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

    with open(sf, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
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
  local checks=("stability.control.snapshot" "verify.core.run")

  python3 - "$sf" "$task_desc" <<'PYWATCHER_INIT'
import json, sys, fcntl, os
from datetime import datetime, timezone

sf = sys.argv[1]
task_desc = sys.argv[2]
lock_file = sf + ".lock"

fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf) as f:
        state = json.load(f)

    checks = [
        {"cap": "stability.control.snapshot", "status": "queued", "run_key": None, "pid": None, "exit_code": None},
        {"cap": "verify.core.run", "status": "queued", "run_key": None, "pid": None, "exit_code": None}
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

    with open(sf, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
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

sf = sys.argv[1]
cap = sys.argv[2]
pid = int(sys.argv[3])
lock_file = sf + ".lock"

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
    with open(sf, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
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
from datetime import datetime, timezone

sf = sys.argv[1]
cap = sys.argv[2]
status = sys.argv[3]
exit_code = int(sys.argv[4])
run_key = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else None
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
lock_file = sf + ".lock"

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
    with open(sf, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
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
import json, sys, os, glob

sf = sys.argv[1]
sd = sys.argv[2]

with open(sf) as f:
    state = json.load(f)

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
  if [[ "${1:-}" == "--" ]]; then
    shift
  fi
  local wave_id="${1:-}"

  # If no wave_id, list all waves
  if [[ -z "$wave_id" ]]; then
    _status_all
    return
  fi

  ensure_wave_exists "$wave_id"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local sd
  sd="$(wave_state_dir "$wave_id")"

  python3 - "$sf" "$sd" "$LANES_STATE" <<'PYSTAT'
import json, sys, os

sf = sys.argv[1]
sd = sys.argv[2]
lanes_file = sys.argv[3]

with open(sf) as f:
    state = json.load(f)

lanes = {}
try:
    with open(lanes_file) as f:
        lanes_state = json.load(f)
        lanes = lanes_state.get("lanes", {})
except (FileNotFoundError, json.JSONDecodeError):
    pass

print("=" * 72)
print(f"  WAVE STATUS: {state['wave_id']}")
print("=" * 72)
print()
print(f"  Status:    {state['status']}")
print(f"  Objective: {state.get('objective', '(none)')}")
print(f"  Created:   {state['created_at']}")
if state.get("closed_at"):
    print(f"  Closed:    {state['closed_at']}")
workspace = state.get("workspace") if isinstance(state.get("workspace"), dict) else None
if workspace and workspace.get("enabled"):
    print(f"  Worktree:  {workspace.get('worktree')}")
    print(f"  Branch:    {workspace.get('branch')}")
    print(f"  Lifecycle: {workspace.get('lifecycle_state', 'active')}")
print()

# Open lanes
if lanes:
    print("LANES")
    print("-" * 72)
    for name, info in sorted(lanes.items()):
        print(f"  {name:12s}  terminal={info['terminal_id']}  since={info['opened_at']}")
    print()

# Dispatches
dispatches = state.get("dispatches", [])
if dispatches:
    print(f"DISPATCHES ({len(dispatches)})")
    print("-" * 72)
    for i, d in enumerate(dispatches, 1):
        status_icon = {"dispatched": "->", "running": "~~", "done": "OK", "failed": "XX"}.get(d["status"], "??")
        print(f"  {status_icon} #{i} [{d['lane']:10s}] {d['task'][:50]}")
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

# Watcher checks
checks = state.get("watcher_checks", [])
if checks:
    done_count = sum(1 for c in checks if c["status"] == "done")
    fail_count = sum(1 for c in checks if c["status"] == "failed")
    running_count = sum(1 for c in checks if c["status"] == "running")
    queued_count = sum(1 for c in checks if c["status"] == "queued")

    header = f"WATCHER ({done_count} done"
    if fail_count: header += f", {fail_count} failed"
    if running_count: header += f", {running_count} running"
    if queued_count: header += f", {queued_count} queued"
    header += ")"

    print(header)
    print("-" * 72)
    for c in checks:
        icon = {"queued": "..", "running": "~~", "done": "OK", "failed": "XX"}.get(c["status"], "??")
        rk = ""
        if c.get("run_key"):
            rk = f"  R={c['run_key']}"
        ec = ""
        if c.get("exit_code") is not None:
            ec = f"  exit={c['exit_code']}"
        ct = ""
        if c.get("completed_at"):
            ct = f"  @{c['completed_at']}"
        print(f"  {icon} {c['cap']}{ec}{rk}{ct}")

    # Check for still-running PIDs
    for c in checks:
        if c["status"] == "running" and c.get("pid"):
            pid = c["pid"]
            # Check if PID still alive
            try:
                os.kill(pid, 0)
                still_alive = True
            except (ProcessLookupError, PermissionError):
                still_alive = False
            if not still_alive:
                print(f"  WARN: {c['cap']} PID {pid} no longer running (may have crashed)")
    print()

# Preflight
pf = state.get("preflight")
if pf:
    print("PREFLIGHT")
    print("-" * 72)
    verdict_icon = "GO" if pf.get("verdict") == "go" else "NO-GO" if pf.get("verdict") == "no-go" else "??"
    print(f"  [{verdict_icon}] domain={pf.get('domain', '?')}  duration={pf.get('duration_s', '?')}s")
    if pf.get("blockers"):
        for b in pf["blockers"]:
            print(f"    BLOCKER: {b}")
    if pf.get("next_action"):
        print(f"    Next: {pf['next_action']}")
    print()

# Summary
print("=" * 72)
total_dispatches = len(dispatches)
total_checks = len(checks)
checks_complete = sum(1 for c in checks if c["status"] in ("done", "failed"))
print(f"  {total_dispatches} dispatches | {checks_complete}/{total_checks} checks complete | {len(lanes)} lanes open")
print("=" * 72)
PYSTAT
}

_status_all() {
  python3 - "$WAVES_DIR" "$LANES_STATE" <<'PYALL'
import json, sys, os

waves_dir = sys.argv[1]
lanes_file = sys.argv[2]

lanes = {}
try:
    with open(lanes_file) as f:
        lanes = json.load(f).get("lanes", {})
except (FileNotFoundError, json.JSONDecodeError):
    pass

waves = []
if os.path.isdir(waves_dir):
    for d in sorted(os.listdir(waves_dir)):
        sf = os.path.join(waves_dir, d, "state.json")
        if os.path.isfile(sf):
            try:
                with open(sf) as f:
                    state = json.load(f)
                waves.append(state)
            except (json.JSONDecodeError, OSError):
                pass

print("=" * 72)
print("  WAVE ORCHESTRATION STATUS")
print("=" * 72)
print()

# Lanes
if lanes:
    print(f"LANES ({len(lanes)})")
    print("-" * 72)
    for name, info in sorted(lanes.items()):
        print(f"  {name:12s}  terminal={info['terminal_id']}  since={info['opened_at']}")
    print()
else:
    print("LANES: (none open)")
    print()

# Waves
if waves:
    active = [w for w in waves if w.get("status") == "active"]
    closed = [w for w in waves if w.get("status") == "closed"]

    if active:
        print(f"ACTIVE WAVES ({len(active)})")
        print("-" * 72)
        for w in active:
            checks = w.get("watcher_checks", [])
            done = sum(1 for c in checks if c["status"] in ("done", "failed"))
            total = len(checks)
            dispatches = len(w.get("dispatches", []))
            check_str = f"checks={done}/{total}" if total else "no checks"
            print(f"  {w['wave_id']:30s}  {dispatches} dispatches  {check_str}")
            if w.get("objective"):
                print(f"  {'':30s}  {w['objective'][:50]}")
        print()

    if closed:
        print(f"CLOSED WAVES ({len(closed)})")
        print("-" * 72)
        for w in closed[-5:]:  # Last 5
            print(f"  {w['wave_id']:30s}  closed={w.get('closed_at', '?')}")
        print()
else:
    print("WAVES: (none)")
    print()

print("=" * 72)
print(f"  {len(lanes)} lanes | {len([w for w in waves if w.get('status') == 'active'])} active waves | {len([w for w in waves if w.get('status') == 'closed'])} closed")
print("=" * 72)
PYALL
}

cmd_ack() {
  local wave_id=""
  local lane=""
  local result=""
  local run_key=""
  local dispatch_id=""
  local lock_override_reason=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --lane) lane="${2:-}"; shift 2 ;;
      --result) result="${2:-}"; shift 2 ;;
      --run-key) run_key="${2:-}"; shift 2 ;;
      --dispatch) dispatch_id="${2:-}"; shift 2 ;;
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
    cat >&2 <<'ACKUSAGE'
Usage: ops wave ack <WAVE_ID> --lane <lane> --result "<text>" [OPTIONS]

Required:
  <WAVE_ID>              The wave to acknowledge
  --lane <lane>          Lane of the dispatch to ack (e.g., execution, control)
  --result "<text>"      Result description

Options:
  --dispatch D<N>        Ack by dispatch index instead of lane (e.g., D1, D2)
  --run-key <key>        Attach a run key to the ack
  --lock-override "<reason>"  Override wave lock

Examples:
  ops wave ack WAVE-20260409-01 --lane execution --result "done: all tests pass"
  ops wave ack WAVE-20260409-01 --dispatch D1 --result "done" --run-key CAP-20260409-run1
ACKUSAGE
    exit 1
  fi
  if [[ -z "$lane" && -z "$dispatch_id" ]]; then
    echo "Must specify --lane <lane> or --dispatch D<N> to identify the task." >&2
    echo "  Example: ops wave ack $wave_id --lane execution --result \"done\"" >&2
    echo "  Example: ops wave ack $wave_id --dispatch D1 --result \"done\"" >&2
    exit 1
  fi

  ensure_wave_exists "$wave_id"
  wave_lock_guard "$wave_id" "ack" "$lock_override_reason"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local terminal_role_contract=""
  local ack_terminal_role="${OPS_TERMINAL_ROLE:-${SPINE_TERMINAL_ROLE:-${SPINE_TERMINAL_NAME:-${SPINE_TERMINAL_ID:-}}}}"
  local ack_runtime_role="${SPINE_RUNTIME_ROLE:-}"

  python3 - "$sf" "$lane" "$result" "$run_key" "$dispatch_id" "$ROLE_RUNTIME_CONTRACT" "$terminal_role_contract" "$ack_terminal_role" "$ack_runtime_role" <<'PYACK'
import json, sys, fcntl, os
from datetime import datetime, timezone

sf = sys.argv[1]
lane = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
result = sys.argv[3] if len(sys.argv) > 3 else ""
run_key = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else None
dispatch_id = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else None
role_contract = sys.argv[6] if len(sys.argv) > 6 else ""
terminal_role_contract = sys.argv[7] if len(sys.argv) > 7 else ""
ack_terminal_role = (sys.argv[8] if len(sys.argv) > 8 else "").strip()
ack_runtime_role = (sys.argv[9] if len(sys.argv) > 9 else "").strip()
lock_file = sf + ".lock"


def _resolve_runtime_role(terminal_role: str, explicit_runtime_role: str, default_role: str) -> str:
    explicit = (explicit_runtime_role or "").strip()
    if explicit:
        return explicit

    terminal = (terminal_role or "").strip()
    if terminal and terminal_role_contract and os.path.exists(terminal_role_contract):
        try:
            import yaml
            doc = yaml.safe_load(open(terminal_role_contract, "r", encoding="utf-8")) or {}
            defaults = doc.get("runtime_role_defaults") if isinstance(doc, dict) else {}
            by_id = defaults.get("by_terminal_id") if isinstance(defaults, dict) else {}
            by_type = defaults.get("by_terminal_type") if isinstance(defaults, dict) else {}
            role_type = ""

            if isinstance(by_id, dict):
                role_value = str(by_id.get(terminal, "")).strip()
                if role_value and role_value.lower() != "null":
                    return role_value

            roles = doc.get("roles") if isinstance(doc, dict) else []
            if isinstance(roles, list):
                for entry in roles:
                    if not isinstance(entry, dict):
                        continue
                    if str(entry.get("id", "")).strip() == terminal:
                        role_type = str(entry.get("type", "")).strip()
                        break
            if role_type and isinstance(by_type, dict):
                role_value = str(by_type.get(role_type, "")).strip()
                if role_value and role_value.lower() != "null":
                    return role_value
        except Exception:
            pass

    return (default_role or "researcher").strip() or "researcher"


fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf) as f:
        state = json.load(f)
    packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    dispatches = state.get("dispatches", [])
    acked_idx = None

    # If dispatch_id given (e.g. "D2"), use index directly
    if dispatch_id and dispatch_id.startswith("D"):
        try:
            idx = int(dispatch_id[1:]) - 1  # D1 = index 0
            if 0 <= idx < len(dispatches):
                d = dispatches[idx]
                if d["status"] != "dispatched":
                    print(f"Dispatch {dispatch_id} is not pending (status={d['status']})")
                    sys.exit(1)
                acked_idx = idx
            else:
                print(f"Dispatch {dispatch_id} out of range (have {len(dispatches)} dispatches)")
                sys.exit(1)
        except ValueError:
            print(f"Invalid dispatch ID: {dispatch_id} (use D1, D2, ...)")
            sys.exit(1)
    elif lane:
        # Find by lane — if multiple pending for same lane, list them
        pending = [(i, d) for i, d in enumerate(dispatches)
                   if d["lane"] == lane and d["status"] == "dispatched"]
        if len(pending) == 0:
            print(f"No pending dispatch for lane '{lane}' in wave '{state['wave_id']}'")
            sys.exit(1)
        elif len(pending) > 1:
            print(f"Multiple pending dispatches for lane '{lane}':")
            for i, d in pending:
                print(f"  D{i+1}: {d['task'][:60]}")
            print(f"Use --dispatch D<N> to specify which one to ack.")
            sys.exit(1)
        else:
            idx, d = pending[0]
            acked_idx = idx

    if acked_idx is None:
        print("No dispatch acked.")
        sys.exit(1)

    d = dispatches[acked_idx]
    selected_lane = str(d.get("lane", "")).strip()
    from_role = str(d.get("from_role", "")).strip()
    to_role = str(d.get("to_role", "")).strip()

    promotion_next = ""
    close_aliases = {"close", "librarian"}
    allowed_by_lane = {
        "control": ["worker"],
        "execution": ["worker"],
        "audit": ["researcher", "qc"],
        "watcher": ["researcher"],
    }
    default_runtime_role = "researcher"
    if role_contract and os.path.exists(role_contract):
        try:
            import yaml
            contract = yaml.safe_load(open(role_contract, "r", encoding="utf-8")) or {}
            runtime_roles = contract.get("runtime_roles") if isinstance(contract, dict) else {}
            if isinstance(runtime_roles, dict):
                default_runtime_role = str(runtime_roles.get("default_role", default_runtime_role)).strip() or default_runtime_role
                aliases = runtime_roles.get("close_role_aliases")
                if isinstance(aliases, list) and aliases:
                    close_aliases = {str(x).strip() for x in aliases if str(x).strip()} or close_aliases
            lane_compat = contract.get("lane_role_compatibility") if isinstance(contract, dict) else {}
            if isinstance(lane_compat, dict):
                allowed = lane_compat.get("allowed_runtime_roles_by_lane")
                if isinstance(allowed, dict) and allowed:
                    parsed_allowed = {}
                    for lane_id, roles in allowed.items():
                        if not isinstance(roles, list):
                            continue
                        normalized = [str(x).strip() for x in roles if str(x).strip()]
                        if normalized:
                            parsed_allowed[str(lane_id).strip()] = normalized
                    if parsed_allowed:
                        allowed_by_lane = parsed_allowed
            transitions = contract.get("promotion_gates", {}).get("transitions", [])
            if isinstance(transitions, list):
                for t in transitions:
                    if not isinstance(t, dict):
                        continue
                    if str(t.get("from", "")).strip() == to_role:
                        promotion_next = str(t.get("to", "")).strip()
                        if promotion_next:
                            break
        except Exception:
            pass

    effective_runtime_role = _resolve_runtime_role(
        ack_terminal_role,
        ack_runtime_role,
        default_runtime_role,
    )
    allowed_roles = allowed_by_lane.get(selected_lane, [])
    allowed_roles = [str(x).strip() for x in allowed_roles if str(x).strip()]
    if not allowed_roles:
        print(
            f"Lane-role authorization missing for lane '{selected_lane}' in lane_role_compatibility.allowed_runtime_roles_by_lane"
        )
        sys.exit(1)

    single_terminal_mode = bool(packet.get("single_terminal_mode"))
    if not single_terminal_mode:
        single_terminal_mode = str(packet.get("owner_terminal", "")).strip().startswith("SPINE-CONTROL-")
    lane_outcomes = packet.get("lane_outcomes") if isinstance(packet.get("lane_outcomes"), list) else []
    lane_owner_terminal = ""
    for row in lane_outcomes:
        if not isinstance(row, dict):
            continue
        if str(row.get("lane_id", "")).strip() != selected_lane:
            continue
        lane_owner_terminal = str(row.get("owner_terminal", "")).strip()
        if lane_owner_terminal:
            break
    if not lane_owner_terminal and single_terminal_mode:
        lane_owner_terminal = str(packet.get("owner_terminal", "")).strip()

    control_lane_override = (
        single_terminal_mode
        and ack_terminal_role.startswith("SPINE-CONTROL-")
        and lane_owner_terminal.startswith("SPINE-CONTROL-")
    )

    if not control_lane_override and effective_runtime_role not in allowed_roles:
        print(
            f"Lane-role authorization failed: lane={selected_lane} runtime_role={effective_runtime_role} allowed={allowed_roles}"
        )
        if ack_terminal_role:
            print(f"Terminal role context: {ack_terminal_role}")
        sys.exit(1)
    if control_lane_override:
        print(
            f"Lane-role override: terminal={ack_terminal_role} acknowledged owned lane '{selected_lane}' in single-terminal mode"
        )

    d["status"] = "done"
    d["completed_at"] = now
    d["result"] = result
    d["run_key"] = run_key

    lane_outcomes = packet.get("lane_outcomes") if isinstance(packet.get("lane_outcomes"), list) else []
    lane_updated = False
    for row in lane_outcomes:
        if not isinstance(row, dict):
            continue
        if str(row.get("lane_id", "")).strip() != selected_lane:
            continue
        row["lane_status"] = "DONE"
        row["owner_terminal"] = lane_owner_terminal or ack_terminal_role or packet.get("owner_terminal", "")
        row["stub_evidence_ref"] = str(row.get("stub_evidence_ref", "") or "")
        row["updated_at_utc"] = now
        if run_key:
            row["run_key"] = run_key
        lane_updated = True
        break
    if not lane_updated:
        entry = {
            "lane_id": selected_lane,
            "lane_status": "DONE",
            "owner_terminal": lane_owner_terminal or ack_terminal_role or packet.get("owner_terminal", ""),
            "stub_evidence_ref": "",
            "updated_at_utc": now,
        }
        if run_key:
            entry["run_key"] = run_key
        lane_outcomes.append(entry)
    packet["lane_outcomes"] = lane_outcomes

    role_flow = state.get("role_flow") if isinstance(state.get("role_flow"), dict) else {}
    if to_role:
        role_flow["current_role"] = to_role
    elif from_role and not role_flow.get("current_role"):
        role_flow["current_role"] = from_role
    if promotion_next:
        role_flow["next_role"] = promotion_next
    elif to_role in close_aliases:
        role_flow["next_role"] = ""
    elif to_role and not role_flow.get("next_role"):
        role_flow["next_role"] = to_role
    role_flow["last_transition"] = {
        "task_id": d.get("task_id"),
        "from_role": from_role,
        "to_role": to_role,
        "completed_at": now,
        "run_key": run_key,
    }
    role_flow.pop("pending_transition", None)
    state["role_flow"] = role_flow
    state["packet"] = packet
    state["wave_packet"] = packet

    lifecycle_state = str(state.get("lifecycle_state", "active")).strip() or "active"
    if lifecycle_state == "active" and to_role == "worker":
        state["lifecycle_state"] = "implemented"
    elif lifecycle_state in {"active", "implemented"} and to_role in {"qc"}:
        state["lifecycle_state"] = "implemented"
    elif lifecycle_state in {"active", "implemented"} and to_role in close_aliases:
        state["lifecycle_state"] = "validated"

    with open(sf, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)

d = dispatches[acked_idx]
print(f"Acknowledged D{acked_idx+1} [{d['lane']}]:")
print(f"  Task: {d['task']}")
print(f"  Result: {result}")
if run_key:
    print(f"  Run key: {run_key}")
print(f"  Status: done")
print(f"  Lifecycle: {state.get('lifecycle_state', 'active')}")
print(f"  Ack role: terminal={ack_terminal_role or 'unset'} runtime={effective_runtime_role} lane={selected_lane}")
PYACK

  sync_runtime_traffic_index "$sf" "ack"
}

# cmd_close() removed — dead code superseded by cmd_close_v2.
# The dispatch table at the bottom routes close) → cmd_close_v2 directly.
# Keeping this marker so git blame shows the removal context.

_cmd_close_was_here() { :; }
: <<'PYCLOSE'
import json, sys, os, fcntl
from datetime import datetime, timezone

sf = sys.argv[1]
sd = sys.argv[2]
force = sys.argv[3] == "true"
spine_repo = sys.argv[4] if len(sys.argv) > 4 else ""
lock_file = sf + ".lock"

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

    with open(sf, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
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
with open(sf, 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
" 2>/dev/null || true
    echo
    echo "  Preflight attached to active wave."
    sync_runtime_traffic_index "$active_wave_sf" "preflight"
  fi
}

# ── Receipt validation (pure Python, no external deps) ─────────────────

cmd_receipt_validate() {
  local receipt_path="${1:-}"
  if [[ -z "$receipt_path" ]]; then
    echo "Usage: ops wave receipt-validate <path-to-receipt.json>" >&2
    exit 1
  fi
  if [[ ! -f "$receipt_path" ]]; then
    echo "FAIL: File not found: $receipt_path" >&2
    exit 1
  fi

  local schema_path="$SPINE_REPO/ops/bindings/orchestration.exec_receipt.schema.json"

  python3 - "$receipt_path" "$schema_path" "$ROLE_RUNTIME_CONTRACT" "$(wave_allowed_lanes_csv)" <<'PYVALIDATE'
import json, sys, re, os

receipt_path = sys.argv[1]
schema_path = sys.argv[2]
role_runtime_contract = sys.argv[3] if len(sys.argv) > 3 else ""
allowed_lanes_csv = sys.argv[4] if len(sys.argv) > 4 else "control,execution,audit,watcher"
allowed_lanes = {
    item.strip()
    for item in allowed_lanes_csv.split(",")
    if item.strip()
} or {"control", "execution", "audit", "watcher"}

errors = []
run_key_pattern_texts = [r"^(CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+|S\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+)$"]
commit_ref_pattern = r"^[0-9a-f]{7,40}$"
allowed_blocker_classes = {"none", "deterministic", "freshness", "dependency", "cleanup", "policy", "external"}
required_evidence_fields = ["run_key_refs", "file_refs", "commit_refs", "blocker_class"]

if role_runtime_contract and os.path.exists(role_runtime_contract):
    try:
        import yaml
        contract = yaml.safe_load(open(role_runtime_contract, "r", encoding="utf-8")) or {}
        evidence = contract.get("evidence") if isinstance(contract, dict) else {}
        if isinstance(evidence, dict):
            run_key_regexes = evidence.get("run_key_regexes")
            if isinstance(run_key_regexes, list) and run_key_regexes:
                parsed = [str(x).strip() for x in run_key_regexes if str(x).strip()]
                if parsed:
                    run_key_pattern_texts = parsed
            elif evidence.get("run_key_regex"):
                run_key_pattern_texts = [str(evidence.get("run_key_regex")).strip()]
            commit_ref_pattern = str(evidence.get("commit_ref_regex", commit_ref_pattern))
            blockers = evidence.get("blocker_classes")
            if isinstance(blockers, list) and blockers:
                allowed_blocker_classes = {str(x).strip() for x in blockers if str(x).strip()} or allowed_blocker_classes
            required = evidence.get("required_ref_fields")
            if isinstance(required, list) and required:
                required_evidence_fields = [str(x).strip() for x in required if str(x).strip()] or required_evidence_fields
    except Exception:
        pass

run_key_patterns = []
for pattern_text in run_key_pattern_texts:
    try:
        run_key_patterns.append(re.compile(pattern_text))
    except re.error as exc:
        print(f"FAIL: invalid run key regex in contract: {pattern_text} ({exc})")
        sys.exit(1)

if not run_key_patterns:
    run_key_patterns = [re.compile(r"^(CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+|S\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+)$")]

def run_key_matches(value: str) -> bool:
    return any(pat.match(value) for pat in run_key_patterns)

# Load receipt
try:
    with open(receipt_path) as f:
        receipt = json.load(f)
except json.JSONDecodeError as e:
    print(f"FAIL: Invalid JSON: {e}")
    sys.exit(1)

if not isinstance(receipt, dict):
    print("FAIL: Receipt must be a JSON object")
    sys.exit(1)

# Load schema for reference
try:
    with open(schema_path) as f:
        schema = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    schema = None

# Required fields
required = ["task_id", "terminal_id", "lane", "status", "files_changed",
            "run_keys", "blockers", "ready_for_verify", "timestamp_utc"]

for field in required:
    if field not in receipt:
        errors.append(f"Missing required field: {field}")

# Type checks
str_fields = ["task_id", "terminal_id", "lane", "status", "timestamp_utc"]
for f in str_fields:
    if f in receipt and not isinstance(receipt[f], str):
        errors.append(f"Field '{f}' must be a string, got {type(receipt[f]).__name__}")

arr_fields = ["files_changed", "run_keys", "blockers"]
for f in arr_fields:
    if f in receipt and not isinstance(receipt[f], list):
        errors.append(f"Field '{f}' must be an array, got {type(receipt[f]).__name__}")

if "ready_for_verify" in receipt and not isinstance(receipt["ready_for_verify"], bool):
    errors.append(f"Field 'ready_for_verify' must be a boolean")

# Enum checks
if receipt.get("lane") and receipt["lane"] not in allowed_lanes:
    errors.append(
        f"Invalid lane: '{receipt['lane']}' (must be {'|'.join(sorted(allowed_lanes))})"
    )

if receipt.get("status") and receipt["status"] not in ("done", "failed", "blocked"):
    errors.append(f"Invalid status: '{receipt['status']}' (must be done|failed|blocked)")

# Non-empty string checks
if receipt.get("task_id") == "":
    errors.append("task_id must not be empty")
if receipt.get("terminal_id") == "":
    errors.append("terminal_id must not be empty")

# Timestamp format
ts = receipt.get("timestamp_utc", "")
if ts and not re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", ts):
    errors.append(f"timestamp_utc must match YYYY-MM-DDTHH:MM:SSZ, got '{ts}'")

# Run key pattern validation
for i, rk in enumerate(receipt.get("run_keys", [])):
    if not isinstance(rk, str):
        errors.append(f"run_keys[{i}] must be a string")
    elif not run_key_matches(rk):
        errors.append(f"run_keys[{i}] '{rk}' does not match any allowed run_key namespace")

# Conditional: blocked status must have blockers
if receipt.get("status") == "blocked":
    blockers = receipt.get("blockers", [])
    if not blockers or len(blockers) == 0:
        errors.append("status=blocked requires at least one entry in blockers[]")

# Optional field validation
if "wave_id" in receipt:
    wid = receipt["wave_id"]
    if not isinstance(wid, str) or not re.match(r"^WAVE-\d{8}-\d{2}$", wid):
        errors.append(f"wave_id must match WAVE-YYYYMMDD-NN pattern, got '{wid}'")

if "commit_hashes" in receipt:
    if not isinstance(receipt["commit_hashes"], list):
        errors.append("commit_hashes must be an array")
    else:
        commit_pat = re.compile(commit_ref_pattern)
        for i, h in enumerate(receipt["commit_hashes"]):
            if not isinstance(h, str) or not commit_pat.match(h):
                errors.append(f"commit_hashes[{i}] must be a 7-40 char hex string")

if "evidence_refs" not in receipt:
    errors.append("Missing required field: evidence_refs")
else:
    evidence_refs = receipt["evidence_refs"]
    if not isinstance(evidence_refs, dict):
        errors.append("evidence_refs must be an object")
    else:
        for key in required_evidence_fields:
            if key not in evidence_refs:
                errors.append(f"evidence_refs missing {key}")

        run_key_refs = evidence_refs.get("run_key_refs", [])
        file_refs = evidence_refs.get("file_refs", [])
        commit_refs = evidence_refs.get("commit_refs", [])
        blocker_class = str(evidence_refs.get("blocker_class", "")).strip()

        if not isinstance(run_key_refs, list):
            errors.append("evidence_refs.run_key_refs must be an array")
        else:
            for i, rk in enumerate(run_key_refs):
                if not isinstance(rk, str) or not run_key_matches(rk):
                    errors.append(f"evidence_refs.run_key_refs[{i}] invalid run key")

        if not isinstance(file_refs, list):
            errors.append("evidence_refs.file_refs must be an array")
        else:
            for i, ref in enumerate(file_refs):
                if not isinstance(ref, str) or not ref.strip():
                    errors.append(f"evidence_refs.file_refs[{i}] must be non-empty string")

        commit_pat = re.compile(commit_ref_pattern)
        if not isinstance(commit_refs, list):
            errors.append("evidence_refs.commit_refs must be an array")
        else:
            for i, ref in enumerate(commit_refs):
                if not isinstance(ref, str) or not commit_pat.match(ref):
                    errors.append(f"evidence_refs.commit_refs[{i}] invalid commit ref")

        if not blocker_class:
            errors.append("evidence_refs.blocker_class must be non-empty")
        elif blocker_class not in allowed_blocker_classes:
            errors.append(f"evidence_refs.blocker_class invalid: {blocker_class}")

# additionalProperties check
allowed_keys = set(required + ["wave_id", "commit_hashes", "loop_id", "gap_ids", "evidence_refs", "completion_level", "prompt_lineage"])
for k in receipt.keys():
    if k not in allowed_keys:
        errors.append(f"Unknown field: '{k}' (additionalProperties not allowed)")

# Output
if errors:
    print(f"FAIL: {len(errors)} validation error(s) in {os.path.basename(receipt_path)}:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
else:
    print(f"OK: {os.path.basename(receipt_path)} is a valid EXEC_RECEIPT")
    sys.exit(0)
PYVALIDATE
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

  python3 - "$sf" "$sd" "$receipts_dir" "$SPINE_STATE/agent-tasks" "$schema_path" "$sync_roadmap" "$SPINE_REPO" "$ROLE_RUNTIME_CONTRACT" "$(wave_allowed_lanes_csv)" <<'PYCOLLECT2'
import json, sys, os, re, glob, fcntl, yaml
from datetime import datetime, timezone

run_key_patterns_text = [r"^(CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+|S\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+)$"]
commit_ref_pattern = r"^[0-9a-f]{7,40}$"
allowed_blocker_classes = {"none", "deterministic", "freshness", "dependency", "cleanup", "policy", "external"}
required_evidence_fields = ["run_key_refs", "file_refs", "commit_refs", "blocker_class"]
close_aliases = {"close", "librarian"}
allowed_lanes = {
    item.strip()
    for item in (sys.argv[9] if len(sys.argv) > 9 else "control,execution,audit,watcher").split(",")
    if item.strip()
} or {"control", "execution", "audit", "watcher"}

def _compile_run_key_patterns(patterns_text):
    compiled = []
    for pattern_text in patterns_text:
        try:
            compiled.append(re.compile(str(pattern_text)))
        except re.error as exc:
            raise RuntimeError(f"invalid run key regex '{pattern_text}': {exc}")
    if not compiled:
        compiled = [re.compile(r"^CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+$")]
    return compiled

def _run_key_matches(value, patterns):
    return any(pat.match(value) for pat in patterns)

run_key_patterns = _compile_run_key_patterns(run_key_patterns_text)

def _validate_receipt(receipt):
    """Validate receipt dict, return list of error strings."""
    errors = []
    required = ["task_id", "terminal_id", "lane", "status", "files_changed",
                "run_keys", "blockers", "ready_for_verify", "timestamp_utc"]
    for field in required:
        if field not in receipt:
            errors.append(f"Missing: {field}")
    str_fields = ["task_id", "terminal_id", "lane", "status", "timestamp_utc"]
    for f in str_fields:
        if f in receipt and not isinstance(receipt[f], str):
            errors.append(f"{f} not string")
    arr_fields = ["files_changed", "run_keys", "blockers"]
    for f in arr_fields:
        if f in receipt and not isinstance(receipt[f], list):
            errors.append(f"{f} not array")
    if "ready_for_verify" in receipt and not isinstance(receipt["ready_for_verify"], bool):
        errors.append("ready_for_verify not bool")
    if receipt.get("lane") and receipt["lane"] not in allowed_lanes:
        errors.append(f"bad lane: {receipt['lane']}")
    if receipt.get("status") and receipt["status"] not in ("done", "failed", "blocked"):
        errors.append(f"bad status: {receipt['status']}")
    ts = receipt.get("timestamp_utc", "")
    if ts and not re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", ts):
        errors.append("bad timestamp format")
    for rk in receipt.get("run_keys", []):
        if isinstance(rk, str) and not _run_key_matches(rk, run_key_patterns):
            errors.append(f"bad run_key: {rk}")
    if receipt.get("status") == "blocked" and not receipt.get("blockers"):
        errors.append("blocked needs blockers[]")

    if "evidence_refs" not in receipt:
        errors.append("missing evidence_refs")
    else:
        evidence_refs = receipt["evidence_refs"]
        if not isinstance(evidence_refs, dict):
            errors.append("evidence_refs not object")
        else:
            for key in required_evidence_fields:
                if key not in evidence_refs:
                    errors.append(f"evidence_refs missing {key}")
            run_key_refs = evidence_refs.get("run_key_refs", [])
            file_refs = evidence_refs.get("file_refs", [])
            commit_refs = evidence_refs.get("commit_refs", [])
            blocker_class = str(evidence_refs.get("blocker_class", "")).strip()

            if not isinstance(run_key_refs, list):
                errors.append("evidence_refs.run_key_refs not array")
            else:
                for rk in run_key_refs:
                    if not isinstance(rk, str) or not _run_key_matches(rk, run_key_patterns):
                        errors.append(f"bad evidence run_key_ref: {rk}")

            if not isinstance(file_refs, list):
                errors.append("evidence_refs.file_refs not array")
            else:
                for ref in file_refs:
                    if not isinstance(ref, str) or not ref.strip():
                        errors.append("bad evidence file_ref")

            commit_pat = re.compile(commit_ref_pattern)
            if not isinstance(commit_refs, list):
                errors.append("evidence_refs.commit_refs not array")
            else:
                for ref in commit_refs:
                    if not isinstance(ref, str) or not commit_pat.match(ref):
                        errors.append(f"bad evidence commit_ref: {ref}")

            if not blocker_class:
                errors.append("evidence_refs.blocker_class missing")
            elif blocker_class not in allowed_blocker_classes:
                errors.append(f"bad evidence blocker_class: {blocker_class}")

    allowed = set(required + ["wave_id", "commit_hashes", "loop_id", "gap_ids", "evidence_refs", "completion_level", "prompt_lineage"])
    for k in receipt.keys():
        if k not in allowed:
            errors.append(f"unknown field: {k}")
    return errors

sf = sys.argv[1]
sd = sys.argv[2]
receipts_dir = sys.argv[3]
mailroom_task_root = sys.argv[4]
schema_path = sys.argv[5]
sync_roadmap = sys.argv[6] == "true"
spine_repo = sys.argv[7]
role_runtime_contract = sys.argv[8] if len(sys.argv) > 8 else ""
lock_file = sf + ".lock"
promotion_next_by_role = {}

if role_runtime_contract and os.path.exists(role_runtime_contract):
    try:
        contract = yaml.safe_load(open(role_runtime_contract, "r", encoding="utf-8")) or {}
        evidence = contract.get("evidence") if isinstance(contract, dict) else {}
        if isinstance(evidence, dict):
            run_key_regexes = evidence.get("run_key_regexes")
            if isinstance(run_key_regexes, list) and run_key_regexes:
                parsed = [str(x).strip() for x in run_key_regexes if str(x).strip()]
                if parsed:
                    run_key_patterns_text = parsed
            elif evidence.get("run_key_regex"):
                run_key_patterns_text = [str(evidence.get("run_key_regex")).strip()]
            commit_ref_pattern = str(evidence.get("commit_ref_regex", commit_ref_pattern))
            blockers = evidence.get("blocker_classes")
            if isinstance(blockers, list) and blockers:
                allowed_blocker_classes = {str(x).strip() for x in blockers if str(x).strip()} or allowed_blocker_classes
            required = evidence.get("required_ref_fields")
            if isinstance(required, list) and required:
                required_evidence_fields = [str(x).strip() for x in required if str(x).strip()] or required_evidence_fields
        runtime_roles = contract.get("runtime_roles") if isinstance(contract, dict) else {}
        if isinstance(runtime_roles, dict):
            aliases = runtime_roles.get("close_role_aliases")
            if isinstance(aliases, list) and aliases:
                close_aliases = {str(x).strip() for x in aliases if str(x).strip()} or close_aliases
        transitions = contract.get("promotion_gates", {}).get("transitions", [])
        if isinstance(transitions, list):
            for row in transitions:
                if not isinstance(row, dict):
                    continue
                from_role = str(row.get("from", "")).strip()
                to_role = str(row.get("to", "")).strip()
                if from_role and to_role and from_role not in promotion_next_by_role:
                    promotion_next_by_role[from_role] = to_role
    except Exception:
        pass

try:
    run_key_patterns = _compile_run_key_patterns(run_key_patterns_text)
except RuntimeError as exc:
    print(f"FAIL: {exc}", file=sys.stderr)
    sys.exit(1)

# ── Load state with lock ──
fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf) as f:
        state = json.load(f)
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)

wave_id = state["wave_id"]
print("=" * 72)
print(f"  WAVE COLLECT: {wave_id}")
print("=" * 72)
print()

packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
lane_outcomes = packet.get("lane_outcomes") if isinstance(packet.get("lane_outcomes"), list) else []

def _extract_run_key_from_text(text):
    raw = str(text or "").strip()
    if not raw:
        return ""
    match = re.search(r"run_key=([^\s]+)", raw)
    if match:
        candidate = match.group(1).strip()
        if _run_key_matches(candidate, run_key_patterns):
            return candidate
    for token in re.split(r"\s+", raw):
        if _run_key_matches(token, run_key_patterns):
            return token
    return ""

def _extract_receipt_from_text(text):
    raw = str(text or "").strip()
    if not raw:
        return ""
    match = re.search(r"receipt=([^\s]+)", raw)
    return match.group(1).strip() if match else ""

def _upsert_lane_outcome(dispatch, lane_status, *, completed_at="", run_key="", blocker=""):
    lane_id = str(dispatch.get("lane", "")).strip()
    if not lane_id:
        return
    owner_terminal = str(dispatch.get("owner_terminal") or packet.get("owner_terminal") or "").strip()
    for row in lane_outcomes:
        if not isinstance(row, dict):
            continue
        if str(row.get("lane_id", "")).strip() != lane_id:
            continue
        row["lane_status"] = lane_status
        if owner_terminal:
            row["owner_terminal"] = owner_terminal
        row["updated_at_utc"] = completed_at or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        row["dispatch_transport"] = str(dispatch.get("dispatch_transport") or row.get("dispatch_transport") or "").strip()
        if dispatch.get("task_id"):
            row["dispatch_task_id"] = dispatch.get("task_id")
        if dispatch.get("mailroom_task_id"):
            row["mailroom_task_id"] = dispatch.get("mailroom_task_id")
        if run_key:
            row["run_key"] = run_key
        if blocker:
            row["blocker"] = blocker
        elif "blocker" in row:
            row.pop("blocker", None)
        return

    entry = {
        "lane_id": lane_id,
        "lane_status": lane_status,
        "owner_terminal": owner_terminal,
        "updated_at_utc": completed_at or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    if dispatch.get("dispatch_transport"):
        entry["dispatch_transport"] = dispatch.get("dispatch_transport")
    if dispatch.get("task_id"):
        entry["dispatch_task_id"] = dispatch.get("task_id")
    if dispatch.get("mailroom_task_id"):
        entry["mailroom_task_id"] = dispatch.get("mailroom_task_id")
    if run_key:
        entry["run_key"] = run_key
    if blocker:
        entry["blocker"] = blocker
    lane_outcomes.append(entry)

# ── Scan receipt artifacts ──
receipt_files = []
valid_receipts = []
invalid_receipts = []

if os.path.isdir(receipts_dir):
    for fn in sorted(os.listdir(receipts_dir)):
        if fn.endswith(".json"):
            fp = os.path.join(receipts_dir, fn)
            receipt_files.append(fp)

            try:
                with open(fp) as rf:
                    receipt = json.load(rf)
            except json.JSONDecodeError as e:
                invalid_receipts.append((fn, f"Invalid JSON: {e}"))
                continue

            # Validate receipt
            errs = _validate_receipt(receipt)
            if errs:
                invalid_receipts.append((fn, "; ".join(errs)))
            else:
                valid_receipts.append((fn, receipt))

print(f"RECEIPT ARTIFACTS ({len(receipt_files)} found, {len(valid_receipts)} valid, {len(invalid_receipts)} invalid)")
print("-" * 72)

if invalid_receipts:
    for fn, reason in invalid_receipts:
        print(f"  XX {fn}: {reason}")

for fn, receipt in valid_receipts:
    print(f"  OK {fn}: task={receipt['task_id']} status={receipt['status']} lane={receipt['lane']}")
print()

# ── Scan mailroom task artifacts ──
mailroom_task_files = []
mailroom_tasks = {}
for bucket in ("done", "failed"):
    bucket_dir = os.path.join(mailroom_task_root, bucket)
    if not os.path.isdir(bucket_dir):
        continue
    for fp in sorted(glob.glob(os.path.join(bucket_dir, "*.yaml"))):
        mailroom_task_files.append(fp)
        try:
            task_doc = yaml.safe_load(open(fp, "r", encoding="utf-8")) or {}
        except Exception:
            continue
        if not isinstance(task_doc, dict):
            continue
        task_id = str(task_doc.get("task_id") or os.path.splitext(os.path.basename(fp))[0]).strip()
        status = str(task_doc.get("status") or bucket).strip()
        if not task_id or status not in {"done", "failed"}:
            continue
        updated_at = str(task_doc.get("updated_at") or task_doc.get("completed_at") or task_doc.get("failed_at") or "").strip()
        mailroom_tasks[task_id] = {
            "task_id": task_id,
            "status": status,
            "file": fp,
            "updated_at": updated_at,
            "completed_at": str(task_doc.get("completed_at") or task_doc.get("failed_at") or updated_at).strip(),
            "result": str(task_doc.get("result") or "").strip(),
            "failure_reason": str(task_doc.get("failure_reason") or "").strip(),
        }

print(f"MAILROOM TASKS ({len(mailroom_task_files)} found, {len(mailroom_tasks)} terminal states)")
print("-" * 72)
for task_id, task_doc in sorted(mailroom_tasks.items()):
    print(f"  {task_doc['status'].upper():4s} {task_id}: {os.path.basename(task_doc['file'])}")
print()

# ── Match receipts to dispatches and update state ──
dispatches = state.get("dispatches", [])
matched = 0
receipt_map = {r["task_id"]: r for _, r in valid_receipts}
mailroom_matched = 0

for i, d in enumerate(dispatches):
    task_id = d.get("task_id", d.get("task", f"D{i+1}"))
    if task_id in receipt_map:
        r = receipt_map[task_id]
        old_status = d["status"]
        d["status"] = r["status"]
        d["completed_at"] = r["timestamp_utc"]
        d["run_key"] = r["run_keys"][0] if r.get("run_keys") else d.get("run_key")
        d["result"] = f"Receipt: {r['status']}"
        if r.get("blockers"):
            d["result"] += f" (blockers: {', '.join(r['blockers'])})"
        d["receipt_file"] = os.path.basename(receipt_map[task_id].get("_source", ""))
        d["receipt_validated"] = True
        matched += 1

    if str(d.get("dispatch_transport", "")).strip() != "mailroom":
        continue

    mailroom_task_id = str(d.get("mailroom_task_id") or "").strip()
    if not mailroom_task_id or mailroom_task_id not in mailroom_tasks:
        continue

    task_doc = mailroom_tasks[mailroom_task_id]
    task_status = str(task_doc.get("status") or "").strip()
    task_completed_at = str(task_doc.get("completed_at") or task_doc.get("updated_at") or "").strip()
    task_result = str(task_doc.get("result") or "").strip()
    task_failure = str(task_doc.get("failure_reason") or "").strip()
    task_run_key = _extract_run_key_from_text(task_result)
    task_receipt = _extract_receipt_from_text(task_result)

    d["mailroom_task_state"] = task_status
    d["mailroom_task_file"] = task_doc.get("file")
    d["mailroom_task_updated_at"] = str(task_doc.get("updated_at") or "")
    if task_receipt:
        d["mailroom_receipt_path"] = task_receipt

    if task_status == "done":
        d["status"] = "done"
        d["completed_at"] = task_completed_at
        d["result"] = f"Mailroom: {task_result}" if task_result else "Mailroom: done"
        if task_run_key:
            d["run_key"] = task_run_key
        _upsert_lane_outcome(d, "DONE", completed_at=task_completed_at, run_key=task_run_key)
        matched += 1
        mailroom_matched += 1
        # Write dispatch completion artifact (dispatch.envelope.contract.yaml)
        _envelope_id = str(d.get("envelope_id") or "").strip()
        if _envelope_id:
            _spine_state = os.environ.get("SPINE_STATE", "")
            if _spine_state:
                _comp_dir = os.path.join(_spine_state, "dispatch", "completion")
                os.makedirs(_comp_dir, exist_ok=True)
                _comp = {
                    "envelope_id": _envelope_id,
                    "completion_status": "complete",
                    "wave_id": str(state.get("wave_id") or ""),
                    "run_key": task_run_key or "",
                    "mailroom_task_id": mailroom_task_id,
                    "completed_at_utc": task_completed_at,
                    "transport_mode": "mailroom",
                }
                _comp_file = os.path.join(_comp_dir, f"{_envelope_id}.completion.json")
                with open(_comp_file, "w", encoding="utf-8") as _cf:
                    json.dump(_comp, _cf, indent=2)
                    _cf.write("\n")
    elif task_status == "failed":
        blocker = task_failure or "mailroom task failed"
        d["status"] = "failed"
        d["completed_at"] = task_completed_at
        d["result"] = f"Mailroom failed: {blocker}"
        _upsert_lane_outcome(d, "BLOCKED", completed_at=task_completed_at, blocker=blocker)
        matched += 1
        mailroom_matched += 1
        # Write dispatch completion artifact for failure
        _envelope_id = str(d.get("envelope_id") or "").strip()
        if _envelope_id:
            _spine_state = os.environ.get("SPINE_STATE", "")
            if _spine_state:
                _comp_dir = os.path.join(_spine_state, "dispatch", "completion")
                os.makedirs(_comp_dir, exist_ok=True)
                _comp = {
                    "envelope_id": _envelope_id,
                    "completion_status": "blocked_delegated",
                    "wave_id": str(state.get("wave_id") or ""),
                    "run_key": "",
                    "mailroom_task_id": mailroom_task_id,
                    "completed_at_utc": task_completed_at,
                    "transport_mode": "mailroom",
                    "failure_reason": blocker,
                }
                _comp_file = os.path.join(_comp_dir, f"{_envelope_id}.completion.json")
                with open(_comp_file, "w", encoding="utf-8") as _cf:
                    json.dump(_comp, _cf, indent=2)
                    _cf.write("\n")

# Promote role/lifecycle state deterministically from completed dispatches.
role_flow = state.get("role_flow") if isinstance(state.get("role_flow"), dict) else {}
lifecycle_state = str(state.get("lifecycle_state", "active")).strip() or "active"
completed = [d for d in dispatches if isinstance(d, dict) and str(d.get("status", "")).strip() == "done"]
if completed:
    def _dispatch_order(dispatch):
        task_id = str(dispatch.get("task_id", "")).strip()
        if task_id.startswith("D") and task_id[1:].isdigit():
            return int(task_id[1:])
        return 0
    completed.sort(key=lambda d: (_dispatch_order(d), str(d.get("completed_at") or d.get("dispatched_at") or "")))
    last_done = completed[-1]
    close_done = [
        d for d in completed
        if str(d.get("to_role", "")).strip() in close_aliases
    ]
    if close_done:
        close_done.sort(key=lambda d: (_dispatch_order(d), str(d.get("completed_at") or d.get("dispatched_at") or "")))
        last_done = close_done[-1]
    last_to_role = str(last_done.get("to_role", "")).strip()
    last_from_role = str(last_done.get("from_role", "")).strip()
    promotion_next = promotion_next_by_role.get(last_to_role, "")
    if last_to_role:
        role_flow["current_role"] = last_to_role
    elif last_from_role and not role_flow.get("current_role"):
        role_flow["current_role"] = last_from_role
    if promotion_next:
        role_flow["next_role"] = promotion_next
    elif last_to_role in close_aliases:
        role_flow["next_role"] = ""
    elif last_to_role:
        role_flow["next_role"] = last_to_role
    role_flow["last_transition"] = {
        "task_id": last_done.get("task_id"),
        "from_role": last_from_role,
        "to_role": last_to_role,
        "completed_at": last_done.get("completed_at"),
        "run_key": last_done.get("run_key"),
    }
    role_flow.pop("pending_transition", None)

for d in completed:
    to_role = str(d.get("to_role", "")).strip()
    if to_role == "worker" and lifecycle_state == "active":
        lifecycle_state = "implemented"
    elif to_role == "qc" and lifecycle_state == "active":
        lifecycle_state = "implemented"
    elif to_role in close_aliases and lifecycle_state in {"active", "implemented"}:
        lifecycle_state = "validated"

resolved_dispatch_ids = {
    str(d.get("task_id", "")).strip()
    for d in dispatches
    if isinstance(d, dict) and str(d.get("status", "")).strip() in {"done", "failed", "blocked"}
}
pending_transition = role_flow.get("pending_transition") if isinstance(role_flow.get("pending_transition"), dict) else {}
pending_transition_task_id = str(pending_transition.get("task_id", "")).strip()
if pending_transition_task_id and pending_transition_task_id in resolved_dispatch_ids:
    role_flow.pop("pending_transition", None)

pending_transitions = [
    d for d in dispatches if isinstance(d, dict) and str(d.get("status", "")).strip() == "dispatched" and str(d.get("to_role", "")).strip()
]
if pending_transitions:
    pending_transitions.sort(key=lambda d: str(d.get("dispatched_at") or ""))
    role_flow["next_role"] = str(pending_transitions[0].get("to_role", "")).strip()
elif str(role_flow.get("current_role", "")).strip() in close_aliases:
    role_flow["next_role"] = ""

packet["lane_outcomes"] = lane_outcomes
state["packet"] = packet
state["wave_packet"] = packet
state["role_flow"] = role_flow
state["lifecycle_state"] = lifecycle_state

# Also collect run keys from all valid receipts
all_run_keys = []
for _, r in valid_receipts:
    all_run_keys.extend(r.get("run_keys", []))

# Merge run keys into state results
existing_rks = set()
for r in state.get("results", []):
    if r.get("run_key"):
        existing_rks.add(r["run_key"])

for rk in all_run_keys:
    if rk not in existing_rks:
        state.setdefault("results", []).append({"run_key": rk, "source": "receipt"})
        existing_rks.add(rk)

# Store receipt collection metadata
state["last_collect"] = {
    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "receipts_scanned": len(receipt_files),
    "receipts_valid": len(valid_receipts),
    "receipts_invalid": len(invalid_receipts),
    "mailroom_tasks_scanned": len(mailroom_task_files),
    "mailroom_tasks_matched": mailroom_matched,
    "dispatches_matched": matched
}

# ── Legacy collect: dispatches + watcher ──
print(f"DISPATCHES ({len(dispatches)})")
print("-" * 72)
for i, d in enumerate(dispatches, 1):
    status_icon = {"dispatched": "->", "done": "OK", "failed": "XX", "blocked": "!!", "running": "~~"}.get(d["status"], "??")
    receipt_tag = " [receipt]" if d.get("receipt_validated") else ""
    print(f"  {status_icon} #{i} [{d.get('lane', '?'):10s}] {d['status']:12s} {d.get('task', '')[:45]}{receipt_tag}")
    if d.get("run_key"):
        print(f"     run_key: {d['run_key']}")
print()

# Watcher checks
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
    print()

# Preflight
pf = state.get("preflight")
if pf:
    print("PREFLIGHT")
    print("-" * 72)
    print(f"  Domain: {pf.get('domain', '?')}")
    print(f"  Verdict: {pf.get('verdict', '?')}")
    if pf.get("blockers"):
        for b in pf["blockers"]:
            print(f"    - {b}")
    print()

# ── Write collection summary artifact ──
summary = {
    "wave_id": wave_id,
    "collected_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "receipts": {
        "scanned": len(receipt_files),
        "valid": len(valid_receipts),
        "invalid": len(invalid_receipts),
        "invalid_details": [{"file": fn, "reason": r} for fn, r in invalid_receipts]
    },
    "dispatches": {
        "total": len(dispatches),
        "done": sum(1 for d in dispatches if d["status"] == "done"),
        "failed": sum(1 for d in dispatches if d["status"] == "failed"),
        "blocked": sum(1 for d in dispatches if d["status"] == "blocked"),
        "pending": sum(1 for d in dispatches if d["status"] == "dispatched")
    },
    "run_keys": list(existing_rks),
    "ready_for_close": all(
        d["status"] in ("done", "blocked") for d in dispatches
    ) and len(invalid_receipts) == 0 if dispatches else False
}

summary_path = os.path.join(sd, "collect-summary.json")
with open(summary_path, "w") as f:
    json.dump(summary, f, indent=2)
    f.write("\n")

# ── Save updated state ──
fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)

# ── Sync roadmap (optional) ──
if sync_roadmap:
    print("ROADMAP SYNC")
    print("-" * 72)
    # Deterministic status updates based on receipt data
    updates = []
    for _, r in valid_receipts:
        entry = {
            "task_id": r["task_id"],
            "status": r["status"],
            "run_keys": r.get("run_keys", []),
            "blockers": r.get("blockers", [])
        }
        if r.get("loop_id"):
            entry["loop_id"] = r["loop_id"]
        if r.get("gap_ids"):
            entry["gap_ids"] = r["gap_ids"]
        updates.append(entry)

    roadmap_patch_path = os.path.join(sd, "roadmap-patch.json")
    with open(roadmap_patch_path, "w") as f:
        json.dump({
            "wave_id": wave_id,
            "patched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "updates": updates
        }, f, indent=2)
        f.write("\n")
    print(f"  Wrote {len(updates)} update(s) to {roadmap_patch_path}")
    for u in updates:
        loop_tag = f" loop={u['loop_id']}" if u.get("loop_id") else ""
        gap_tag = f" gaps={','.join(u['gap_ids'])}" if u.get("gap_ids") else ""
        print(f"  - {u['task_id']}: {u['status']}{loop_tag}{gap_tag}")
    print()

# ── Summary ──
print("=" * 72)
close_ready = summary["ready_for_close"]
if close_ready:
    print(f"  All dispatches resolved, receipts valid. Ready: ops wave close {wave_id}")
elif invalid_receipts:
    print(f"  {len(invalid_receipts)} invalid receipt(s). Fix before close.")
else:
    pending = summary["dispatches"]["pending"]
    if pending:
        print(f"  {pending} dispatch(es) still pending. Awaiting receipts.")
    else:
        print(f"  Collection complete. Review before close: ops wave close {wave_id} --disposition landed")
print(f"  Summary: {summary_path}")
print("=" * 72)
PYCOLLECT2

  sync_runtime_traffic_index "$sf" "collect"
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
  local allowed_dispositions_csv=""

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
    echo "Usage: ops wave close <WAVE_ID> --disposition <state> [--force] [--controller-only --verify-receipt <receipt> --fixed-in <sha>] [--dod-override \"<reason>\"] [--lock-override \"<reason>\"]" >&2
    exit 1
  fi
  allowed_dispositions_csv="$(close_dispositions_csv)"
  require_close_disposition "$disposition" "$allowed_dispositions_csv"

  ensure_wave_exists "$wave_id"
  wave_lock_guard "$wave_id" "close" "$lock_override_reason"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local sd
  sd="$(wave_state_dir "$wave_id")"

  WAVE_CLOSE_CONTROLLER_ONLY="$controller_only" \
  WAVE_CLOSE_VERIFY_RECEIPT="$controller_verify_receipt" \
  WAVE_CLOSE_FIXED_IN="$fixed_in" \
  python3 - "$sf" "$sd" "$force" "$SPINE_REPO" "$ROLE_RUNTIME_CONTRACT" "$dod_override_reason" "$lock_override_reason" "$disposition" "$allowed_dispositions_csv" "$(wave_allowed_lanes_csv)" <<'PYCLOSE2'
import json, sys, os, re, fcntl, subprocess
from datetime import datetime, timezone

# ── Add lifecycle lib to path for wave_close_validator ──
_lifecycle_lib = os.path.join(os.path.abspath(sys.argv[4]), "ops", "plugins", "core", "lifecycle", "lib") if len(sys.argv) > 4 and sys.argv[4] else ""
if _lifecycle_lib and os.path.isdir(_lifecycle_lib):
    sys.path.insert(0, _lifecycle_lib)

import wave_close_validator as wcv

sf = sys.argv[1]
sd = sys.argv[2]
force = sys.argv[3] == "true"
spine_repo = sys.argv[4]
role_runtime_contract = sys.argv[5] if len(sys.argv) > 5 else ""
dod_override_reason = (sys.argv[6] if len(sys.argv) > 6 else "").strip()
lock_override_reason = (sys.argv[7] if len(sys.argv) > 7 else "").strip()
disposition = (sys.argv[8] if len(sys.argv) > 8 else "").strip()
allowed_dispositions = {item.strip() for item in (sys.argv[9] if len(sys.argv) > 9 else "").split(",") if item.strip()}
allowed_lanes = {
    item.strip()
    for item in (sys.argv[10] if len(sys.argv) > 10 else "control,execution,audit,watcher").split(",")
    if item.strip()
} or {"control", "execution", "audit", "watcher"}
controller_only = os.environ.get("WAVE_CLOSE_CONTROLLER_ONLY", "").strip().lower() == "true"
controller_verify_receipt = os.environ.get("WAVE_CLOSE_VERIFY_RECEIPT", "").strip()
fixed_in = os.environ.get("WAVE_CLOSE_FIXED_IN", "").strip()
lock_file = sf + ".lock"
receipts_dir = os.path.join(sd, "receipts")
controller_precheck_path = os.path.join(sd, "controller-close-precheck.json")

# ── Build config from defaults + role-runtime contract overrides ──
run_key_patterns_text = list(wcv.DEFAULT_RUN_KEY_PATTERNS)
commit_ref_pattern = wcv.DEFAULT_COMMIT_REF_PATTERN
allowed_blocker_classes = set(wcv.DEFAULT_ALLOWED_BLOCKER_CLASSES)
required_evidence_fields = list(wcv.DEFAULT_REQUIRED_EVIDENCE_FIELDS)
state_field = wcv.DEFAULT_STATE_FIELD
state_transitions = dict(wcv.DEFAULT_STATE_TRANSITIONS)
close_aliases = set(wcv.DEFAULT_CLOSE_ALIASES)

if role_runtime_contract and os.path.exists(role_runtime_contract):
    try:
        import yaml
        contract = yaml.safe_load(open(role_runtime_contract, "r", encoding="utf-8")) or {}
        evidence = contract.get("evidence") if isinstance(contract, dict) else {}
        if isinstance(evidence, dict):
            run_key_regexes = evidence.get("run_key_regexes")
            if isinstance(run_key_regexes, list) and run_key_regexes:
                parsed = [str(x).strip() for x in run_key_regexes if str(x).strip()]
                if parsed:
                    run_key_patterns_text = parsed
            elif evidence.get("run_key_regex"):
                run_key_patterns_text = [str(evidence.get("run_key_regex")).strip()]
            commit_ref_pattern = str(evidence.get("commit_ref_regex", commit_ref_pattern))
            blockers = evidence.get("blocker_classes")
            if isinstance(blockers, list) and blockers:
                allowed_blocker_classes = {str(x).strip() for x in blockers if str(x).strip()} or allowed_blocker_classes
            required = evidence.get("required_ref_fields")
            if isinstance(required, list) and required:
                required_evidence_fields = [str(x).strip() for x in required if str(x).strip()] or required_evidence_fields
        runtime_roles = contract.get("runtime_roles") if isinstance(contract, dict) else {}
        if isinstance(runtime_roles, dict):
            aliases = runtime_roles.get("close_role_aliases")
            if isinstance(aliases, list) and aliases:
                close_aliases = {str(x).strip() for x in aliases if str(x).strip()} or close_aliases
        sm = contract.get("closeout_state_machine") if isinstance(contract, dict) else {}
        if isinstance(sm, dict):
            state_field = str(sm.get("state_field", state_field)).strip() or state_field
            states = sm.get("states")
            if isinstance(states, dict) and states:
                parsed = {}
                for st, meta in states.items():
                    if not isinstance(meta, dict):
                        continue
                    parsed[str(st).strip()] = {
                        str(x).strip() for x in (meta.get("transitions") or []) if str(x).strip()
                    }
                if parsed:
                    state_transitions = parsed
    except Exception:
        pass

try:
    config = wcv.CloseConfig(
        run_key_patterns_text=run_key_patterns_text,
        commit_ref_pattern=commit_ref_pattern,
        allowed_blocker_classes=allowed_blocker_classes,
        required_evidence_fields=required_evidence_fields,
        state_field=state_field,
        state_transitions=state_transitions,
        close_aliases=close_aliases,
        allowed_lanes=allowed_lanes,
    )
except RuntimeError as exc:
    print(f"FAIL: {exc}")
    sys.exit(1)

# ── Disposition validation (via module) ──
disp_err = wcv.validate_disposition(disposition, allowed_dispositions)
if disp_err:
    print(disp_err)
    sys.exit(1)

# ── Side-effectful helpers (stay inline: subprocess, filesystem) ──

def _resolve_ref_path(value: str) -> str:
    text = str(value or "").strip()
    if not text:
        return ""
    if os.path.isabs(text):
        return text
    if spine_repo:
        return os.path.join(spine_repo, text)
    return text


def _load_json(path: str):
    if not path or not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _git(args):
    return subprocess.run(
        ["git", "-C", spine_repo] + args,
        text=True,
        capture_output=True,
        check=False,
    )


def _commit_on_main(commit_sha: str) -> bool:
    commit = str(commit_sha or "").strip()
    if not commit or not spine_repo:
        return False
    if _git(["rev-parse", "--verify", f"{commit}^{{commit}}"]).returncode != 0:
        return False
    if _git(["rev-parse", "--verify", "main^{commit}"]).returncode != 0:
        return False
    return _git(["merge-base", "--is-ancestor", commit, "main"]).returncode == 0


def _validate_verify_receipt(path_value: str):
    resolved = _resolve_ref_path(path_value)
    if not resolved:
        return None, "controller-only requires --verify-receipt"
    if not os.path.exists(resolved):
        return None, f"controller-only verify receipt not found: {resolved}"

    receipt_dir = os.path.dirname(resolved)
    exec_path = os.path.join(receipt_dir, "receipt.exec.json")
    output_path = os.path.join(receipt_dir, "output.txt")
    receipt_exec = _load_json(exec_path)
    if str(receipt_exec.get("task_id", "")).strip() != "verify.run":
        return None, f"controller-only verify receipt is not verify.run: {resolved}"
    if str(receipt_exec.get("status", "")).strip().lower() not in wcv.VERIFY_PASS_STATUSES:
        return None, f"controller-only verify receipt not done: {resolved}"
    if not os.path.exists(output_path):
        return None, f"controller-only verify output missing: {output_path}"

    try:
        verify_payload = _load_json(output_path)
    except Exception as exc:
        return None, f"controller-only verify output unreadable: {exc}"

    wrapper = verify_payload.get("wrapper") if isinstance(verify_payload.get("wrapper"), dict) else {}
    blocking = verify_payload.get("blocking_fail_ids") if isinstance(verify_payload.get("blocking_fail_ids"), list) else []
    scope = str(verify_payload.get("scope", "")).strip()
    fail_count = int(wrapper.get("fail", 0) or 0)
    if scope != "fast":
        return None, f"controller-only verify receipt must be fast scope: {resolved}"
    if fail_count > 0 or blocking:
        return None, f"controller-only verify receipt has blocking failures: {resolved}"

    run_keys = receipt_exec.get("run_keys") if isinstance(receipt_exec.get("run_keys"), list) else []
    run_key = ""
    for value in run_keys:
        candidate = str(value or "").strip()
        if candidate and config.matches_run_key(candidate):
            run_key = candidate
            break
    if not run_key:
        return None, f"controller-only verify receipt missing run key: {resolved}"

    return {
        "receipt_path": resolved,
        "output_path": output_path,
        "run_key": run_key,
        "wrapper": {
            "total": int(wrapper.get("total", 0) or 0),
            "pass": int(wrapper.get("pass", 0) or 0),
            "fail": fail_count,
            "warn": int(wrapper.get("warn", 0) or 0),
        },
    }, None


def _worktree_cleanup_blockers(wave_id: str, workspace: dict):
    script = os.path.join(spine_repo, "ops", "plugins", "core", "lifecycle", "bin", "worktree-lifecycle-reconcile")
    if not os.path.exists(script):
        return {
            "error": f"cleanup classifier not found: {script}",
            "global_blocked_count": 0,
            "blocking_rows": [],
            "raw_summary": {},
        }

    proc = subprocess.run(
        [script, "--json"],
        text=True,
        capture_output=True,
        check=False,
        cwd=spine_repo,
    )
    text = proc.stdout.strip() or proc.stderr.strip()
    if proc.returncode != 0 or not text:
        return {
            "error": text or "cleanup classifier failed",
            "global_blocked_count": 0,
            "blocking_rows": [],
            "raw_summary": {},
        }

    try:
        payload = json.loads(text)
    except json.JSONDecodeError as exc:
        return {
            "error": f"cleanup classifier returned invalid json: {exc}",
            "global_blocked_count": 0,
            "blocking_rows": [],
            "raw_summary": {},
        }

    workspace_path = str(workspace.get("worktree", "")).strip()
    workspace_branch = str(workspace.get("branch", "")).strip()
    blocking_rows = []
    global_blocked_count = 0
    for section in ("worktrees", "local_branches", "temp_clones", "stashes"):
        for row in payload.get(section, []) or []:
            issues = [str(item).strip() for item in (row.get("issues") or []) if str(item).strip()]
            if not issues:
                continue
            global_blocked_count += 1
            row_path = str(row.get("path", "")).strip()
            branch = str(row.get("branch", "")).strip()
            owner_id = str(row.get("owner_id", "")).strip()
            is_current = (
                owner_id == wave_id
                or (workspace_branch and branch == workspace_branch)
                or (workspace_path and row_path == workspace_path)
                or (workspace_path and row_path.startswith(workspace_path + os.sep))
            )
            if not is_current:
                continue
            blocking_rows.append(
                {
                    "category": section,
                    "path": row_path,
                    "branch": branch,
                    "owner_id": owner_id,
                    "issues": issues,
                }
            )

    root_checkout = payload.get("root_checkout") if isinstance(payload.get("root_checkout"), dict) else {}
    root_issues = [str(item).strip() for item in (root_checkout.get("issues") or []) if str(item).strip()]
    if root_issues:
        global_blocked_count += 1
        blocking_rows.append(
            {
                "category": "root_checkout",
                "path": str(root_checkout.get("path", "")).strip(),
                "branch": str(root_checkout.get("branch", "")).strip(),
                "owner_id": "root_checkout",
                "issues": root_issues,
            }
        )

    return {
        "error": "",
        "global_blocked_count": global_blocked_count,
        "blocking_rows": blocking_rows,
        "raw_summary": payload.get("summary", {}) if isinstance(payload, dict) else {},
    }

def _stub_exists(ref: str) -> bool:
    text = str(ref or "").strip()
    if not text:
        return False
    if os.path.isabs(text):
        return os.path.exists(text)
    if spine_repo:
        return os.path.exists(os.path.join(spine_repo, text))
    return os.path.exists(text)

# ── Lock state file and load ──
fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf) as f:
        state = json.load(f)

    if state["status"] == "closed":
        print(f"Wave '{state['wave_id']}' is already closed.")
        sys.exit(0)

    # ── Controller-only precheck (side-effectful: filesystem + subprocess) ──
    checks = state.get("watcher_checks", [])
    pf = state.get("preflight")
    dispatches = state.get("dispatches", [])
    packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
    controller_context = {
        "requested": controller_only,
        "eligible": False,
        "minimal_shell": False,
        "fixed_in": "",
        "verify_run_key": "",
        "verify_receipt_path": "",
        "cleanup_ref": "",
        "cleanup_error": "",
        "cleanup_blocking_rows": [],
        "cleanup_global_blocked_count": 0,
        "controller_infra_violations": [],
        "controller_dod_violations": [],
    }
    workspace = state.get("workspace") if isinstance(state.get("workspace"), dict) else {}
    workspace_enabled = workspace.get("enabled")
    if isinstance(workspace_enabled, str):
        workspace_enabled = workspace_enabled.strip().lower() == "true"
    workspace_enabled = bool(workspace_enabled)
    results = state.get("results") if isinstance(state.get("results"), list) else []

    zero_work_fast_close = (
        not controller_only
        and disposition in {"abandoned", "superseded"}
        and not dispatches
        and not checks
        and not results
        and not pf
    )
    if zero_work_fast_close:
        controller_context["minimal_shell"] = True
        controller_context["eligible"] = True
        controller_context["cleanup_ref"] = controller_precheck_path

    minimal_controller_shell = (
        controller_only
        and not dispatches
        and not checks
        and not workspace_enabled
        and not results
        and not pf
    )
    controller_context["minimal_shell"] = minimal_controller_shell

    if controller_only:
        if dispatches:
            controller_context["controller_infra_violations"].append(
                "controller-only close requires zero dispatches"
            )

        if minimal_controller_shell:
            controller_context["cleanup_ref"] = controller_precheck_path
        else:
            push_receipt_path = os.path.join(sd, "push.receipt.json")
            push_receipt = _load_json(push_receipt_path) if os.path.exists(push_receipt_path) else {}
            fixed_commit = fixed_in or str(push_receipt.get("commit_sha", "")).strip()
            controller_context["fixed_in"] = fixed_commit

            if push_receipt and str(push_receipt.get("push_result", "")).strip() not in {"", "success"}:
                controller_context["controller_infra_violations"].append(
                    f"controller-only push receipt is not successful: {push_receipt.get('push_result')}"
                )

            if not fixed_commit:
                controller_context["controller_dod_violations"].append(
                    "controller-only close requires landed commit proof (--fixed-in or push.receipt.json)"
                )
            elif not _commit_on_main(fixed_commit):
                controller_context["controller_infra_violations"].append(
                    f"controller-only fixed commit not present on main: {fixed_commit}"
                )

            verify_info, verify_error = _validate_verify_receipt(controller_verify_receipt)
            if verify_error:
                controller_context["controller_dod_violations"].append(verify_error)
            else:
                controller_context["verify_run_key"] = verify_info["run_key"]
                controller_context["verify_receipt_path"] = verify_info["receipt_path"]

            cleanup_check = _worktree_cleanup_blockers(state.get("wave_id", ""), workspace)
            controller_context["cleanup_error"] = cleanup_check.get("error", "")
            controller_context["cleanup_blocking_rows"] = cleanup_check.get("blocking_rows", [])
            controller_context["cleanup_global_blocked_count"] = cleanup_check.get("global_blocked_count", 0)
            if cleanup_check.get("error"):
                controller_context["controller_infra_violations"].append(
                    f"controller-only cleanup classifier failed: {cleanup_check['error']}"
                )
            elif cleanup_check.get("blocking_rows"):
                details = []
                for row in cleanup_check.get("blocking_rows", []):
                    issue_text = ",".join(row.get("issues", []))
                    label = row.get("path") or row.get("branch") or row.get("category") or "unknown"
                    details.append(f"{label} [{issue_text}]")
                controller_context["controller_dod_violations"].append(
                    "controller-only cleanup residue unresolved: " + "; ".join(details)
                )
            else:
                controller_context["cleanup_ref"] = controller_precheck_path

        controller_context["eligible"] = not controller_context["controller_infra_violations"] and not controller_context["controller_dod_violations"]
        with open(controller_precheck_path, "w", encoding="utf-8") as handle:
            json.dump(
                {
                    "wave_id": state.get("wave_id", ""),
                    "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "mode": "controller_only_close_precheck",
                    "eligible": controller_context["eligible"],
                    "minimal_shell": controller_context["minimal_shell"],
                    "fixed_in": controller_context["fixed_in"],
                    "verify_receipt_path": controller_context["verify_receipt_path"],
                    "verify_run_key": controller_context["verify_run_key"],
                    "cleanup_global_blocked_count": controller_context["cleanup_global_blocked_count"],
                    "cleanup_blocking_rows": controller_context["cleanup_blocking_rows"],
                    "controller_infra_violations": controller_context["controller_infra_violations"],
                    "controller_dod_violations": controller_context["controller_dod_violations"],
                },
                handle,
                indent=2,
            )
            handle.write("\n")

    # ── Receipt validation (via module) ──
    invalid_receipts = []
    valid_receipt_count = 0
    valid_receipts = []

    if zero_work_fast_close:
        print(
            "ZERO-WORK FAST CLOSE: no dispatches, checks, results, or preflight; "
            "skipping heavy DoD ceremony."
        )
        state["zero_work_fast_close"] = True
        if not isinstance(state.get("dod"), dict) or not state.get("dod"):
            state["dod"] = {
                "verify_results": [],
                "blocker_classification": ["none"],
                "cleanup_proof": ["zero_work_fast_close"],
                "linkage": {
                    "packet_loop_id": str(packet.get("loop_id", "")).strip(),
                    "valid_receipts": 0,
                    "errors": [],
                },
            }
    else:
        receipts_dir = os.path.join(sd, "evidence")
        if os.path.isdir(receipts_dir):
            for fn in sorted(os.listdir(receipts_dir)):
                if not fn.endswith(".json"):
                    continue
                fp = os.path.join(receipts_dir, fn)
                try:
                    with open(fp) as rf:
                        r = json.load(rf)
                    errs = wcv.validate_receipt(r, config)
                    if errs:
                        invalid_receipts.append(f"{fn}: {'; '.join(errs)}")
                    else:
                        valid_receipt_count += 1
                        valid_receipts.append(r)
                except json.JSONDecodeError as e:
                    invalid_receipts.append(f"{fn}: invalid JSON ({e})")

    # ── Inject validated receipts into state for module access ──
    state["_valid_receipts"] = valid_receipts
    state["_invalid_receipt_details"] = invalid_receipts

    # ── Full close validation pipeline (via module) ──
    if zero_work_fast_close:
        violations = wcv.CloseViolations()
        dod = {}
        hard_blocked = False
        gate = wcv.evaluate_gate(violations, force, dod_override_reason)
    else:
        violations, dod, hard_blocked = wcv.validate_close(
            state=state,
            force=force,
            disposition=disposition,
            allowed_dispositions=allowed_dispositions,
            dod_override_reason=dod_override_reason,
            controller_context=controller_context,
            config=config,
            stub_exists_fn=_stub_exists,
        )

    # Clean up internal keys
    state.pop("_valid_receipts", None)
    state.pop("_invalid_receipt_details", None)

    if hard_blocked:
        print("BLOCKED: force-close denied while dispatches are pending without stub evidence.")
        pending_msg = [v for v in violations.infra if "dispatch pending" in v]
        for msg in pending_msg:
            print(f"  - {msg}")
        print("Remediation: mark lane_outcomes as BLOCKED with valid stub_evidence_ref before retrying --force.")
        sys.exit(1)

    # ── Gate decision (via module) ──
    if not zero_work_fast_close:
        gate = wcv.evaluate_gate(violations, force, dod_override_reason)

    if gate.blocked:
        print("BLOCKED: Wave close contract not met:")
        if gate.infra_violations:
            print("Infra violations:")
            for v in gate.infra_violations:
                print(f"  - {v}")
        if gate.dod_violations:
            print("DoD violations:")
            for v in gate.dod_violations:
                print(f"  - {v}")
        if invalid_receipts:
            print()
            print("Invalid receipts:")
            for ir in invalid_receipts:
                print(f"  - {ir}")
        print()
        print("Options:")
        print(f"  1. Fix issues, then retry: ops wave close {state['wave_id']}")
        if gate.infra_violations:
            print(f"  2. Force close (infra only): ops wave close {state['wave_id']} --force")
        if gate.dod_violations:
            print(
                "  3. Override DoD with explicit reason: "
                f"ops wave close {state['wave_id']} --dod-override \"<reason>\""
            )
        sys.exit(1)

    if gate.force_used:
        print(f"WARNING: Forcing close with {len(gate.infra_violations)} infra violation(s):")
        for v in gate.infra_violations:
            print(f"  - {v}")
        print()

    if gate.dod_overridden:
        print(f"WARNING: Overriding {len(gate.dod_violations)} DoD violation(s):")
        for v in gate.dod_violations:
            print(f"  - {v}")
        print(f"  DoD override reason: {dod_override_reason}")
        print()

    # ── State mutation (stays inline — side-effectful) ──
    infra_violations = gate.infra_violations
    dod_violations = gate.dod_violations
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    state["status"] = "closed"
    state["closed_at"] = now
    state["disposition"] = disposition
    state["force_closed"] = gate.force_used
    state["dod_overridden"] = gate.dod_overridden
    state["dod_override_reason"] = dod_override_reason if gate.dod_overridden else ""
    state["lock_overridden"] = bool(lock_override_reason)
    state["lock_override_reason"] = lock_override_reason
    state["controller_only"] = bool(controller_only)
    state["controller_precheck_path"] = controller_precheck_path if controller_only else ""
    state[config.state_field] = "closed"
    state["lifecycle_state"] = "closed"
    workspace = state.get("workspace")
    if isinstance(workspace, dict) and workspace.get("enabled"):
        workspace["lifecycle_state"] = "pending_close"
        workspace["closed_at"] = now
        workspace["close_action"] = "explicit_cleanup_required"
        state["workspace"] = workspace

    with open(sf, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)

# ── Generate merge receipt (via module + inline markdown) ──
done_checks = sum(1 for c in checks if c["status"] == "done")
failed_checks = sum(1 for c in checks if c["status"] == "failed")
run_keys = [c["run_key"] for c in checks if c.get("run_key")]
workspace = state.get("workspace") if isinstance(state.get("workspace"), dict) else {}

for r in valid_receipts:
    for rk in r.get("run_keys", []):
        if rk not in run_keys:
            run_keys.append(rk)

close_receipt = wcv.build_close_receipt(
    state=state,
    disposition=disposition,
    now_utc=now,
    dispatches=dispatches,
    checks=checks,
    valid_receipt_count=valid_receipt_count,
    invalid_receipt_count=len(invalid_receipts),
    run_keys=run_keys,
    gate=gate,
    controller_only=controller_only,
    controller_precheck_path=controller_precheck_path,
    controller_context=controller_context,
    dod_override_reason=dod_override_reason,
    lock_override_reason=lock_override_reason,
)

residual_blockers = close_receipt["residual_blockers"]
ready_for_adoption = close_receipt["READY_FOR_ADOPTION"]

close_receipt_path = os.path.join(sd, "close-receipt.json")
with open(close_receipt_path, "w") as f:
    json.dump(close_receipt, f, indent=2)
    f.write("\n")

# Markdown receipt (backward compat)
receipt_path = os.path.join(sd, "receipt.md")
with open(receipt_path, "w") as rf:
    rf.write(f"# Wave Merge Receipt: {state['wave_id']}\n\n")
    rf.write(f"- **Wave ID**: {state['wave_id']}\n")
    rf.write(f"- **Objective**: {state.get('objective', '(none)')}\n")
    rf.write(f"- **Created**: {state['created_at']}\n")
    rf.write(f"- **Closed**: {now}\n")
    rf.write(f"- **Status**: closed\n\n")
    rf.write(f"- **Disposition**: {disposition}\n\n")
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
        receipt_tag = " [receipt-validated]" if d.get("receipt_validated") else ""
        rf.write(f"{i}. [{d.get('lane', '?')}] {d.get('task', '')}{rk} - {d['status']}{receipt_tag}\n")
    rf.write("\n")

    rf.write(f"## Watcher Checks ({len(checks)})\n\n")
    for c in checks:
        rk = f" R={c['run_key']}" if c.get("run_key") else ""
        ec = f" exit={c['exit_code']}" if c.get("exit_code") is not None else ""
        rf.write(f"- [{c['status']}] {c['cap']}{ec}{rk}\n")
    rf.write("\n")

    rf.write(f"## EXEC_RECEIPT Artifacts ({valid_receipt_count} valid)\n\n")
    if os.path.isdir(receipts_dir):
        for fn in sorted(os.listdir(receipts_dir)):
            if fn.endswith(".json"):
                rf.write(f"- {fn}\n")
    rf.write("\n")

    rf.write(f"## Run Keys\n\n")
    if run_keys:
        for rk in run_keys:
            rf.write(f"- {rk}\n")
    else:
        rf.write("(none collected)\n")
    rf.write("\n")

    rf.write("## DoD Guard\n\n")
    dod = state.get("dod", {}) if isinstance(state.get("dod"), dict) else {}
    verify_rows = dod.get("verify_results") if isinstance(dod.get("verify_results"), list) else []
    blocker_rows = dod.get("blocker_classification") if isinstance(dod.get("blocker_classification"), list) else []
    cleanup_rows = dod.get("cleanup_proof") if isinstance(dod.get("cleanup_proof"), list) else []
    linkage = dod.get("linkage") if isinstance(dod.get("linkage"), dict) else {}
    rf.write(f"- verify_results: {len(verify_rows)}\n")
    rf.write(f"- blocker_classification: {', '.join(blocker_rows) if blocker_rows else 'none'}\n")
    rf.write(f"- cleanup_proof: {len(cleanup_rows)}\n")
    if linkage:
        rf.write(f"- linkage.packet_loop_id: {linkage.get('packet_loop_id', '')}\n")
        link_errors = linkage.get("errors") if isinstance(linkage.get("errors"), list) else []
        rf.write(f"- linkage.errors: {len(link_errors)}\n")
    rf.write("\n")

    rf.write(f"## Residual Blockers\n\n")
    if residual_blockers:
        for b in residual_blockers:
            rf.write(f"- {b}\n")
    else:
        rf.write("(none)\n")
    rf.write("\n")

    rf.write(f"---\nREADY_FOR_ADOPTION={'true' if ready_for_adoption else 'false'}\n")

print(f"Wave '{state['wave_id']}' closed.")
print(f"  Disposition: {disposition}")
print(f"  Dispatches: {len(dispatches)} ({sum(1 for d in dispatches if d['status'] == 'done')} done, {sum(1 for d in dispatches if d['status'] == 'blocked')} blocked)")
print(f"  Checks: {done_checks} done, {failed_checks} failed")
print(f"  Receipts: {valid_receipt_count} valid, {len(invalid_receipts)} invalid")
if workspace.get("enabled"):
    print(f"  Workspace lifecycle: pending_close ({workspace.get('worktree')})")
if run_keys:
    print(f"  Run keys: {len(run_keys)}")
if residual_blockers:
    print(f"  Residual blockers: {len(residual_blockers)}")
    for b in residual_blockers:
        print(f"    - {b}")
print(f"  Close receipt: {close_receipt_path}")
print(f"  Merge receipt: {receipt_path}")
print(f"  READY_FOR_ADOPTION={'true' if ready_for_adoption else 'false'}")
PYCLOSE2

  release_wave_path_claims "$wave_id" "released"
  sync_runtime_traffic_index "$sf" "close"

  # Mark workspace lease as pending_close if the wave had an auto workspace.
  local lease_filename=".spine-lane-lease.yaml"
  local lifecycle_contract="$SPINE_REPO/ops/bindings/worktree.lifecycle.contract.yaml"
  if command -v yq >/dev/null 2>&1 && [[ -f "$lifecycle_contract" ]]; then
    lease_filename="$(yq e -r '.policy.lease_filename // ".spine-lane-lease.yaml"' "$lifecycle_contract" 2>/dev/null || echo "$lease_filename")"
  fi
  local workspace_path
  workspace_path="$(python3 - "$sf" <<'PYLEASEPATH'
import json, sys
state = json.load(open(sys.argv[1]))
w = state.get("workspace") or {}
print(w.get("worktree") or "")
PYLEASEPATH
)"
  if [[ -n "$workspace_path" && -f "$workspace_path/$lease_filename" ]]; then
    python3 - "$workspace_path/$lease_filename" <<'PYLEASEUPDATE'
import sys
from datetime import datetime, timezone
from pathlib import Path

p = Path(sys.argv[1])
raw = p.read_text(encoding="utf-8", errors="ignore")
lines = raw.splitlines()
body = [ln for ln in lines if ln.strip() and ln.strip() != "---"]
kv = {}
for ln in body:
    if ":" not in ln:
        continue
    k, v = ln.split(":", 1)
    kv[k.strip()] = v.strip().strip('"')
kv["status"] = "pending_close"
kv["heartbeat_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
kv["closed_at"] = kv["heartbeat_at"]
out = ["---"]
for k in [
    "version", "status", "owner", "loop_or_wave_id", "repo", "worktree",
    "branch", "created_at", "heartbeat_at", "closed_at", "ttl_hours"
]:
    if k in kv:
        out.append(f'{k}: "{kv[k]}"' if k not in {"version", "ttl_hours"} else f"{k}: {kv[k]}")
out.append("---")
p.write_text("\n".join(out) + "\n", encoding="utf-8")
PYLEASEUPDATE
  fi
}

# ── Agent-result -> EXEC_RECEIPT bridge ────────────────────────────────
# Controller boundary: converts an in-band Agent-tool subagent result into a
# worker-class EXEC_RECEIPT JSON artifact under waves/<WAVE_ID>/evidence/.
# Preserves the single receipt model so `ops wave receipt-validate` remains
# authoritative for every dispatch, regardless of whether the worker was a
# shell lane or an Agent-tool subagent.
cmd_emit_agent_receipt() {
  local wave_id=""
  local lane=""
  local dispatch_id=""
  local result=""
  local task_id_override=""
  local -a file_reads=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --lane) lane="${2:-}"; shift 2 ;;
      --dispatch) dispatch_id="${2:-}"; shift 2 ;;
      --result) result="${2:-}"; shift 2 ;;
      --file-read) file_reads+=("${2:-}"); shift 2 ;;
      --task-id) task_id_override="${2:-}"; shift 2 ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) wave_id="$1"; shift ;;
    esac
  done

  if [[ -z "$wave_id" ]]; then
    cat >&2 <<'EAREMITUSAGE'
Usage: ops wave emit-agent-receipt <WAVE_ID> --lane <lane>|--dispatch D<N> --result "<text>" [--file-read <path>]... [--task-id <id>]

Bridge: controller-side emit of a worker-class EXEC_RECEIPT JSON for an
in-band Agent-tool subagent result. Writes to:
  <WAVES_DIR>/<WAVE_ID>/evidence/<task_id>.exec_receipt.json
Then invokes receipt-validate and reports.
EAREMITUSAGE
    exit 1
  fi
  if [[ -z "$lane" && -z "$dispatch_id" ]]; then
    echo "ERROR: --lane <lane> or --dispatch D<N> is required." >&2
    exit 1
  fi

  ensure_wave_exists "$wave_id"
  local sf wdir evidence_dir
  sf="$(wave_state_file "$wave_id")"
  wdir="$(wave_state_dir "$wave_id")"
  evidence_dir="$wdir/evidence"
  mkdir -p "$evidence_dir"

  local emit_terminal="${OPS_TERMINAL_ROLE:-${SPINE_TERMINAL_ROLE:-${SPINE_TERMINAL_NAME:-${SPINE_TERMINAL_ID:-SPINE-CONTROL-01}}}}"

  local files_read_csv=""
  if [[ ${#file_reads[@]} -gt 0 ]]; then
    local IFS_SAVED="$IFS"
    IFS='|'
    files_read_csv="${file_reads[*]}"
    IFS="$IFS_SAVED"
  fi

  local receipt_path
  receipt_path="$(
    python3 - "$sf" "$wave_id" "$lane" "$dispatch_id" "$result" "$task_id_override" "$emit_terminal" "$evidence_dir" "$files_read_csv" <<'PYEMIT'
import json, os, sys
from datetime import datetime, timezone

sf = sys.argv[1]
wave_id = sys.argv[2]
lane_in = sys.argv[3]
dispatch_id_in = sys.argv[4]
result = sys.argv[5]
task_id_override = sys.argv[6]
terminal_id = sys.argv[7] or "SPINE-CONTROL-01"
evidence_dir = sys.argv[8]
files_read_csv = sys.argv[9]

with open(sf) as f:
    state = json.load(f)

dispatches = state.get("dispatches", [])
if not isinstance(dispatches, list) or not dispatches:
    print("ERROR: wave has no dispatches", file=sys.stderr)
    sys.exit(1)

selected = None
if dispatch_id_in and dispatch_id_in.startswith("D"):
    try:
        idx = int(dispatch_id_in[1:]) - 1
        if 0 <= idx < len(dispatches):
            selected = dispatches[idx]
    except ValueError:
        pass
    if selected is None:
        print(f"ERROR: dispatch {dispatch_id_in} not found", file=sys.stderr)
        sys.exit(1)
elif lane_in:
    for d in dispatches:
        if d.get("lane") == lane_in:
            selected = d
    if selected is None:
        print(f"ERROR: no dispatch found on lane '{lane_in}'", file=sys.stderr)
        sys.exit(1)
else:
    print("ERROR: --lane or --dispatch required", file=sys.stderr)
    sys.exit(1)

task_id = task_id_override.strip() or str(selected.get("task_id") or "").strip()
if not task_id:
    print("ERROR: unable to resolve task_id from dispatch; pass --task-id", file=sys.stderr)
    sys.exit(1)

selected_lane = str(selected.get("lane") or lane_in or "execution").strip()

file_refs = []
if files_read_csv:
    file_refs = [p for p in files_read_csv.split("|") if p.strip()]

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# Minimal worker-class EXEC_RECEIPT for an in-band Agent-tool subagent result.
# No fabricated run keys. No fabricated commits. No fabricated files_changed.
# blocker_class=none because the bridge only runs on successful in-band return.
receipt = {
    "task_id": task_id,
    "terminal_id": terminal_id,
    "lane": selected_lane,
    "status": "done",
    "files_changed": [],
    "run_keys": [],
    "blockers": [],
    "ready_for_verify": True,
    "timestamp_utc": now,
    "wave_id": wave_id,
    "evidence_refs": {
        "run_key_refs": [],
        "file_refs": file_refs,
        "commit_refs": [],
        "blocker_class": "none",
    },
}

out_path = os.path.join(evidence_dir, f"{task_id}.exec_receipt.json")
with open(out_path, "w") as f:
    json.dump(receipt, f, indent=2)
    f.write("\n")

print(out_path)
PYEMIT
  )" || { echo "FAIL: receipt emit failed" >&2; exit 1; }

  if [[ -z "$receipt_path" || ! -f "$receipt_path" ]]; then
    echo "FAIL: receipt path not produced" >&2
    exit 1
  fi

  echo "Emitted agent-bridged EXEC_RECEIPT: $receipt_path"
  echo "Validating..."
  cmd_receipt_validate "$receipt_path"
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
  -h|--help)          usage ;;
  "")                 usage ;;
  *)
    echo "Unknown wave subcommand: $1" >&2
    usage
    exit 1
    ;;
esac
