#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops wave - Wave orchestration with lane-aware dispatch
# ═══════════════════════════════════════════════════════════════════════════
#
# Coordinates multi-terminal work across lanes with non-blocking preflight,
# background watcher for long checks, and unified status view.
#
# Usage:
#   ops wave start <WAVE_ID> --objective "<text>" [--loop-id <LOOP_ID>] [--deadline-utc <ISO8601>] [--horizon now|later|future] [--execution-readiness runnable|blocked] [--claimed-paths "a,b"] [--worktree auto|off] [--repo <path>]
#   ops wave dispatch <WAVE_ID> --lane <lane> --task "<text>" [--from-role <role>] [--to-role <role>] [--input-refs "k=v,..."] [--output-refs "k=v,..."]
#   ops wave collect <WAVE_ID>
#   ops wave status [WAVE_ID]
#   ops wave close <WAVE_ID>
#   ops wave preflight <domain>
#   ops wave receipt-validate <path>
#
# Receipt artifacts: $RUNTIME_ROOT/waves/<WAVE_ID>/receipts/<task_id>.json
# State: $RUNTIME_ROOT/waves/<WAVE_ID>/state.json (runtime-only)
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
RUNTIME_ROOT="${SPINE_RUNTIME_ROOT:-$HOME/code/.runtime/spine-mailroom}"
WAVES_DIR="$RUNTIME_ROOT/waves"
LANES_STATE="$RUNTIME_ROOT/lanes/state.json"
ROLE_RUNTIME_CONTRACT="$SPINE_REPO/ops/bindings/role.runtime.control.contract.yaml"
source "$SPINE_REPO/ops/lib/git-lock.sh" 2>/dev/null || true

mkdir -p "$WAVES_DIR"

# ── Helpers ──────────────────────────────────────────────────────────────

RUNTIME_ROLE_CONTROL_LOADED=0
PATH_CLAIMS_FILE="$SPINE_REPO/mailroom/state/path.claims.yaml"
PATH_CLAIMS_TTL_MINUTES="180"
PATH_CLAIMS_NON_OVERLAP="true"
TRAFFIC_INDEX_FILE="$SPINE_REPO/mailroom/state/traffic.index.yaml"

_repo_abs_path() {
  local p="${1:-}"
  if [[ -z "$p" || "$p" == "null" ]]; then
    echo ""
    return
  fi
  if [[ "$p" = /* ]]; then
    echo "$p"
  else
    echo "$SPINE_REPO/$p"
  fi
}

load_runtime_role_control() {
  if [[ "$RUNTIME_ROLE_CONTROL_LOADED" -eq 1 ]]; then
    return
  fi
  local path_claims_rel="mailroom/state/path.claims.yaml"
  local traffic_index_rel="mailroom/state/traffic.index.yaml"

  if command -v yq >/dev/null 2>&1 && [[ -f "$ROLE_RUNTIME_CONTRACT" ]]; then
    path_claims_rel="$(yq e -r '.path_claims.state_file // "mailroom/state/path.claims.yaml"' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || echo "$path_claims_rel")"
    PATH_CLAIMS_TTL_MINUTES="$(yq e -r '.path_claims.default_ttl_minutes // 180' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || echo 180)"
    PATH_CLAIMS_NON_OVERLAP="$(yq e -r '.path_claims.require_non_overlapping_active_claims // true' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || echo true)"
    traffic_index_rel="$(yq e -r '.traffic_index.state_file // "mailroom/state/traffic.index.yaml"' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || echo "$traffic_index_rel")"
  fi

  [[ "$PATH_CLAIMS_TTL_MINUTES" =~ ^[0-9]+$ ]] || PATH_CLAIMS_TTL_MINUTES="180"
  PATH_CLAIMS_FILE="$(_repo_abs_path "$path_claims_rel")"
  TRAFFIC_INDEX_FILE="$(_repo_abs_path "$traffic_index_rel")"
  [[ -n "$PATH_CLAIMS_FILE" ]] || PATH_CLAIMS_FILE="$SPINE_REPO/mailroom/state/path.claims.yaml"
  [[ -n "$TRAFFIC_INDEX_FILE" ]] || TRAFFIC_INDEX_FILE="$SPINE_REPO/mailroom/state/traffic.index.yaml"
  RUNTIME_ROLE_CONTROL_LOADED=1
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
from datetime import datetime, timezone

claims_file = sys.argv[1]
wave_id = sys.argv[2]
claim_status = sys.argv[3]
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

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
PYPATHRELEASE
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

# ── Subcommands ──────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
ops wave - Wave orchestration with lane-aware dispatch

Usage:
  ops wave start <WAVE_ID> --objective "<text>" [--loop-id <LOOP_ID>] [--deadline-utc <ISO8601>] [--horizon now|later|future] [--execution-readiness runnable|blocked] [--claimed-paths "a,b"] [--worktree auto|off] [--repo <path>]
                                                    Create a new wave (default auto worktree)
  ops wave dispatch <WAVE_ID> --lane <L> --task "T" [--from-role <R>] [--to-role <R>] [--input-refs "k=v,..."] [--output-refs "k=v,..."] [--lock-override "<reason>"]  Dispatch task to a lane
  ops wave ack <WAVE_ID> --lane <L> --result "text" [--lock-override "<reason>"]  Acknowledge task completion
  ops wave collect <WAVE_ID>                         Collect results from lanes
  ops wave status [WAVE_ID]                          Show wave status (or all)
  ops wave close <WAVE_ID> [--force] [--dod-override "<reason>"] [--lock-override "<reason>"]  Close a wave (infra force requires --force, DoD force requires --dod-override)
  ops wave preflight <domain>                        Fast non-blocking preflight
  ops wave receipt-validate <path>                   Validate EXEC_RECEIPT JSON

Wave IDs: use WAVE-YYYYMMDD-NN format (e.g. WAVE-20260222-01)

EXEC_RECEIPT Artifacts:
  Workers emit JSON receipts to $RUNTIME_ROOT/waves/<WAVE_ID>/receipts/.
  Use receipt-validate to check schema compliance before collect.

Background Watcher:
  The watcher lane auto-enqueues long checks (stability.control.snapshot,
  verify.core.run, verify.pack.run) and tracks them without blocking.
  Results appear in 'ops wave status' when complete.
EOF
}

cmd_start() {
  local wave_id=""
  local objective=""
  local loop_id=""
  local deadline_utc=""
  local horizon="now"
  local execution_readiness="runnable"
  local owner_terminal="${OPS_TERMINAL_ROLE:-${SPINE_TERMINAL_ID:-${USER:-unknown}}}"
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
  load_runtime_role_control

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --objective) objective="${2:-}"; shift 2 ;;
      --loop-id) loop_id="${2:-}"; shift 2 ;;
      --deadline-utc) deadline_utc="${2:-}"; shift 2 ;;
      --horizon) horizon="${2:-}"; shift 2 ;;
      --execution-readiness) execution_readiness="${2:-}"; shift 2 ;;
      --owner-terminal) owner_terminal="${2:-}"; shift 2 ;;
      --claimed-paths) claimed_paths_raw="${2:-}"; shift 2 ;;
      --current-role) default_role="${2:-}"; current_role_explicit=1; shift 2 ;;
      --next-role) default_next_role="${2:-}"; next_role_explicit=1; shift 2 ;;
      --worktree) worktree_mode="${2:-}"; shift 2 ;;
      --repo) workspace_repo="${2:-}"; shift 2 ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) wave_id="$1"; shift ;;
    esac
  done

  if [[ -z "$wave_id" ]]; then
    echo "Usage: ops wave start <WAVE_ID> --objective \"<text>\" [--loop-id <LOOP_ID>] [--deadline-utc <ISO8601>] [--horizon now|later|future] [--execution-readiness runnable|blocked] [--claimed-paths \"a,b\"] [--worktree auto|off] [--repo <path>]" >&2
    exit 1
  fi
  if [[ "$worktree_mode" != "auto" && "$worktree_mode" != "off" ]]; then
    echo "Usage: --worktree must be auto or off (got: $worktree_mode)" >&2
    exit 1
  fi

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

  [[ -n "$loop_id" ]] || loop_id="${SPINE_LOOP_ID:-LOOP-${wave_id}}"
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
  [[ -n "$claimed_paths_raw" ]] || claimed_paths_raw="$(yq e -r ".roles[]? | select(.id == \"${OPS_TERMINAL_ROLE:-}\") | .write_scope[]?" "$SPINE_REPO/ops/bindings/terminal.role.contract.yaml" 2>/dev/null | paste -sd, -)"
  [[ -n "$claimed_paths_raw" ]] || claimed_paths_raw="."

  mkdir -p "$sd"

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
    default_branch="$(git -C "$workspace_repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
    default_branch="${default_branch:-main}"

    local lifecycle_contract="$SPINE_REPO/ops/bindings/worktree.lifecycle.contract.yaml"
    local canonical_root="$HOME/.wt"
    local lease_filename=".spine-lane-lease.yaml"
    local lease_ttl_hours="24"
    local lease_owner="${OPS_TERMINAL_ROLE:-SPINE-CONTROL-01}"
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
    repo_name="$(basename "$workspace_repo")"
    workspace_worktree="$canonical_root/$repo_name/${wave_id}"

    if ! git -C "$workspace_repo" show-ref --verify --quiet "refs/heads/$workspace_branch"; then
      if git -C "$workspace_repo" show-ref --verify --quiet "refs/remotes/origin/$default_branch"; then
        git -C "$workspace_repo" branch "$workspace_branch" "origin/$default_branch" >/dev/null
      else
        git -C "$workspace_repo" branch "$workspace_branch" "$default_branch" >/dev/null
      fi
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

  python3 - "$sf" "$wave_id" "$objective" "$workspace_enabled" "$workspace_repo" "$workspace_worktree" "$workspace_branch" "$workspace_note" "$default_role" "$default_next_role" "$loop_id" "$deadline_utc" "$horizon" "$execution_readiness" "$owner_terminal" "$claimed_paths_json" "$packet_required_fields" "$packet_allowed_horizon" "$packet_allowed_readiness" "$packet_allowed_roles" "$PATH_CLAIMS_FILE" "$PATH_CLAIMS_TTL_MINUTES" "$PATH_CLAIMS_NON_OVERLAP" <<'PYSTART'
import json, sys
import os
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

packet = {
    "schema_version": "1.0",
    "wave_id": wave_id,
    "loop_id": loop_id,
    "owner_terminal": owner_terminal,
    "current_role": default_role,
    "next_role": default_next_role,
    "deadline_utc": deadline_utc,
    "horizon": horizon,
    "execution_readiness": execution_readiness,
    "claimed_paths": claimed_paths,
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
claims_doc = _load_doc(path_claims_file) if path_claims_file else {}
claims = claims_doc.get("claims") if isinstance(claims_doc.get("claims"), list) else []
normalized_claims = []
conflicts = []

for claim in claims:
    if not isinstance(claim, dict):
        continue
    status = str(claim.get("status", "active")).strip() or "active"
    expires_at = str(claim.get("expires_at", "")).strip()
    if status == "active" and expires_at:
        try:
            if datetime.fromisoformat(expires_at.replace("Z", "+00:00")) <= now_dt:
                status = "expired"
                claim["status"] = "expired"
                claim["expired_at"] = now
        except Exception:
            pass
    if status == "active" and path_claims_non_overlap and str(claim.get("wave_id", "")).strip() != wave_id:
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

state = {
    "wave_id": wave_id,
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
}

with open(sf, "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

print(f"Wave '{wave_id}' created.")
if objective:
    print(f"  Objective: {objective}")
print(f"  Status: active")
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
    echo "Usage: ops wave dispatch <WAVE_ID> --lane <lane> --task \"<text>\" [--from-role <role>] [--to-role <role>] [--input-refs \"k=v,...\"] [--output-refs \"k=v,...\"] [--lock-override \"<reason>\"]" >&2
    exit 1
  fi

  ensure_wave_exists "$wave_id"
  wave_lock_guard "$wave_id" "dispatch" "$lock_override_reason"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local sd
  sd="$(wave_state_dir "$wave_id")"

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
        *) to_role="$from_role" ;;
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
    missing_inputs="$(jq -r --argjson required "$required_inputs_json" --argjson refs "$input_refs_json" '$required[] | select(($refs[.] // "") == "")' <<<"{}")"
    missing_outputs="$(jq -r --argjson required "$required_outputs_json" --argjson refs "$output_refs_json" '$required[] | select(($refs[.] // "") == "")' <<<"{}")"
    if [[ -n "$missing_inputs" ]]; then
      echo "FAIL: dispatch missing required input refs for gate $transition_gate: $(echo "$missing_inputs" | tr '\n' ',' | sed 's/,$//')" >&2
      exit 1
    fi
    if [[ -n "$missing_outputs" ]]; then
      echo "FAIL: dispatch missing required output refs for gate $transition_gate: $(echo "$missing_outputs" | tr '\n' ',' | sed 's/,$//')" >&2
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
    print(f"  NOTE: execution lane is deny-scoped from docs/planning/*")
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
  # Fallback: try CAP-* pattern with alphanumeric run key suffix
  if [[ -z "$run_key" ]]; then
    run_key="$(grep -oE 'CAP-[0-9]+-[0-9]+__[A-Za-z0-9._-]+__R[A-Za-z0-9]+' "$log_file" 2>/dev/null | head -1 || true)"
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
    print("  All checks complete. Ready to close: ops wave close " + state["wave_id"])
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
    echo "Usage: ops wave ack <WAVE_ID> --lane <lane> [--dispatch D<N>] --result \"<text>\" [--run-key <key>] [--lock-override \"<reason>\"]" >&2
    exit 1
  fi
  if [[ -z "$lane" && -z "$dispatch_id" ]]; then
    echo "Must specify --lane <lane> or --dispatch D<N> to identify the task" >&2
    exit 1
  fi

  ensure_wave_exists "$wave_id"
  wave_lock_guard "$wave_id" "ack" "$lock_override_reason"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local terminal_role_contract="$SPINE_REPO/ops/bindings/terminal.role.contract.yaml"
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
    if effective_runtime_role not in allowed_roles:
        print(
            f"Lane-role authorization failed: lane={selected_lane} runtime_role={effective_runtime_role} allowed={allowed_roles}"
        )
        if ack_terminal_role:
            print(f"Terminal role context: {ack_terminal_role}")
        sys.exit(1)

    d["status"] = "done"
    d["completed_at"] = now
    d["result"] = result
    d["run_key"] = run_key

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

cmd_close() {
  local wave_id=""
  local force=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --force) force=true; shift ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) wave_id="$1"; shift ;;
    esac
  done

  if [[ -z "$wave_id" ]]; then
    echo "Usage: ops wave close <WAVE_ID> [--force] [--dod-override \"<reason>\"]" >&2
    exit 1
  fi

  ensure_wave_exists "$wave_id"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local sd
  sd="$(wave_state_dir "$wave_id")"

  python3 - "$sf" "$sd" "$force" <<'PYCLOSE'
import json, sys, os, fcntl
from datetime import datetime, timezone

sf = sys.argv[1]
sd = sys.argv[2]
force = sys.argv[3] == "true"
lock_file = sf + ".lock"

fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf) as f:
        state = json.load(f)

    if state["status"] == "closed":
        print(f"Wave '{state['wave_id']}' is already closed.")
        sys.exit(0)

    # ── Contract enforcement (wave.lifecycle.yaml) ──
    # Close requires: all watcher checks done/failed, preflight run at least once
    checks = state.get("watcher_checks", [])
    pf = state.get("preflight")
    contract_violations = []

    running = [c for c in checks if c["status"] in ("queued", "running")]
    if running:
        statuses = "/".join(sorted(set(c["status"] for c in running)))
        contract_violations.append(f"{len(running)} watcher check(s) still {statuses}")

    # Preflight is always required, not just when watcher checks exist
    if not pf:
        contract_violations.append("Preflight has not been run (required by wave.lifecycle contract)")

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
dispatches = state.get("dispatches", [])
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
}

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

  python3 - "$receipt_path" "$schema_path" "$ROLE_RUNTIME_CONTRACT" <<'PYVALIDATE'
import json, sys, re, os

receipt_path = sys.argv[1]
schema_path = sys.argv[2]
role_runtime_contract = sys.argv[3] if len(sys.argv) > 3 else ""

errors = []
run_key_pattern_texts = [r"^CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+$"]
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
    run_key_patterns = [re.compile(r"^CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+$")]

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
if receipt.get("lane") and receipt["lane"] not in ("control", "execution", "audit", "watcher"):
    errors.append(f"Invalid lane: '{receipt['lane']}' (must be control|execution|audit|watcher)")

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
allowed_keys = set(required + ["wave_id", "commit_hashes", "loop_id", "gap_ids", "evidence_refs"])
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
  local receipts_dir="$sd/receipts"
  local schema_path="$SPINE_REPO/ops/bindings/orchestration.exec_receipt.schema.json"

  python3 - "$sf" "$sd" "$receipts_dir" "$schema_path" "$sync_roadmap" "$SPINE_REPO" "$ROLE_RUNTIME_CONTRACT" <<'PYCOLLECT2'
import json, sys, os, re, glob, fcntl
from datetime import datetime, timezone

run_key_patterns_text = [r"^CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+$"]
commit_ref_pattern = r"^[0-9a-f]{7,40}$"
allowed_blocker_classes = {"none", "deterministic", "freshness", "dependency", "cleanup", "policy", "external"}
required_evidence_fields = ["run_key_refs", "file_refs", "commit_refs", "blocker_class"]
close_aliases = {"close", "librarian"}

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
    if receipt.get("lane") and receipt["lane"] not in ("control", "execution", "audit", "watcher"):
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

    allowed = set(required + ["wave_id", "commit_hashes", "loop_id", "gap_ids", "evidence_refs"])
    for k in receipt.keys():
        if k not in allowed:
            errors.append(f"unknown field: {k}")
    return errors

sf = sys.argv[1]
sd = sys.argv[2]
receipts_dir = sys.argv[3]
schema_path = sys.argv[4]
sync_roadmap = sys.argv[5] == "true"
spine_repo = sys.argv[6]
role_runtime_contract = sys.argv[7] if len(sys.argv) > 7 else ""
lock_file = sf + ".lock"

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

# ── Match receipts to dispatches and update state ──
dispatches = state.get("dispatches", [])
matched = 0
receipt_map = {r["task_id"]: r for _, r in valid_receipts}

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
    last_to_role = str(last_done.get("to_role", "")).strip()
    last_from_role = str(last_done.get("from_role", "")).strip()
    if last_to_role:
        role_flow["current_role"] = last_to_role
    elif last_from_role and not role_flow.get("current_role"):
        role_flow["current_role"] = last_from_role
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

pending_transitions = [
    d for d in dispatches if isinstance(d, dict) and str(d.get("status", "")).strip() == "dispatched" and str(d.get("to_role", "")).strip()
]
if pending_transitions:
    pending_transitions.sort(key=lambda d: str(d.get("dispatched_at") or ""))
    role_flow["next_role"] = str(pending_transitions[0].get("to_role", "")).strip()
elif str(role_flow.get("current_role", "")).strip() in close_aliases:
    role_flow["next_role"] = ""

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
        print(f"  Collection complete. Review before close: ops wave close {wave_id}")
print(f"  Summary: {summary_path}")
print("=" * 72)
PYCOLLECT2

  sync_runtime_traffic_index "$sf" "collect"
}

# ── Enhanced close with receipt gating ─────────────────────────────────

cmd_close_v2() {
  local wave_id=""
  local force=false
  local dod_override_reason=""
  local lock_override_reason=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --force) force=true; shift ;;
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
    echo "Usage: ops wave close <WAVE_ID> [--force] [--dod-override \"<reason>\"] [--lock-override \"<reason>\"]" >&2
    exit 1
  fi

  ensure_wave_exists "$wave_id"
  wave_lock_guard "$wave_id" "close" "$lock_override_reason"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local sd
  sd="$(wave_state_dir "$wave_id")"

  python3 - "$sf" "$sd" "$force" "$SPINE_REPO" "$ROLE_RUNTIME_CONTRACT" "$dod_override_reason" "$lock_override_reason" <<'PYCLOSE2'
import json, sys, os, re, fcntl
from datetime import datetime, timezone

sf = sys.argv[1]
sd = sys.argv[2]
force = sys.argv[3] == "true"
spine_repo = sys.argv[4]
role_runtime_contract = sys.argv[5] if len(sys.argv) > 5 else ""
dod_override_reason = (sys.argv[6] if len(sys.argv) > 6 else "").strip()
lock_override_reason = (sys.argv[7] if len(sys.argv) > 7 else "").strip()
lock_file = sf + ".lock"
receipts_dir = os.path.join(sd, "receipts")

run_key_patterns_text = [r"^CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+$"]
commit_ref_pattern = r"^[0-9a-f]{7,40}$"
allowed_blocker_classes = {"none", "deterministic", "freshness", "dependency", "cleanup", "policy", "external"}
required_evidence_fields = ["run_key_refs", "file_refs", "commit_refs", "blocker_class"]
state_field = "lifecycle_state"
state_transitions = {
    "active": {"implemented"},
    "implemented": {"validated"},
    "validated": {"closed"},
    "closed": set(),
}
close_aliases = {"close", "librarian"}

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

run_key_patterns = _compile_run_key_patterns(run_key_patterns_text)

def _run_key_matches(value):
    return any(pat.match(value) for pat in run_key_patterns)

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
    run_key_patterns = _compile_run_key_patterns(run_key_patterns_text)
except RuntimeError as exc:
    print(f"FAIL: {exc}")
    sys.exit(1)

fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf) as f:
        state = json.load(f)

    if state["status"] == "closed":
        print(f"Wave '{state['wave_id']}' is already closed.")
        sys.exit(0)

    # ── Contract enforcement (enhanced) ──
    checks = state.get("watcher_checks", [])
    pf = state.get("preflight")
    dispatches = state.get("dispatches", [])
    packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
    infra_violations = []
    dod_violations = []

    # 1. Watcher checks must be done/failed
    running = [c for c in checks if c["status"] in ("queued", "running")]
    if running:
        statuses = "/".join(sorted(set(c["status"] for c in running)))
        infra_violations.append(f"{len(running)} watcher check(s) still {statuses}")

    # 2. Preflight required
    if not pf:
        infra_violations.append("Preflight has not been run (required by wave.lifecycle contract)")

    # 3. All dispatches must be done or explicitly blocked
    pending = [d for d in dispatches if d["status"] == "dispatched"]
    if pending:
        infra_violations.append(f"{len(pending)} dispatch(es) still pending (not done/blocked)")

    # 4. Canonical packet presence required at close as DoD source-of-truth
    packet_required = [
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
    packet_missing = [k for k in packet_required if packet.get(k) in (None, "", [])]
    if packet_missing:
        infra_violations.append(f"wave packet missing required field(s): {', '.join(packet_missing)}")

    # 5. Receipt validation: all receipt files must satisfy EXEC_RECEIPT contract
    invalid_receipts = []
    valid_receipt_count = 0
    valid_receipts = []

    def _validate_receipt_close(receipt):
        errors = []
        required_fields = ["task_id", "terminal_id", "lane", "status", "files_changed",
                           "run_keys", "blockers", "ready_for_verify", "timestamp_utc"]
        for field in required_fields:
            if field not in receipt:
                errors.append(f"missing {field}")

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

        if receipt.get("lane") and receipt["lane"] not in ("control", "execution", "audit", "watcher"):
            errors.append(f"bad lane: {receipt['lane']}")

        if receipt.get("status") and receipt["status"] not in ("done", "failed", "blocked"):
            errors.append(f"bad status: {receipt['status']}")

        ts = receipt.get("timestamp_utc", "")
        if ts and not re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", ts):
            errors.append("bad timestamp format")

        for rk in receipt.get("run_keys", []):
            if not isinstance(rk, str):
                errors.append("run_key not string")
            elif not _run_key_matches(rk):
                errors.append(f"bad run_key: {rk}")

        if receipt.get("status") == "blocked" and not receipt.get("blockers"):
            errors.append("blocked needs blockers[]")

        if "wave_id" in receipt:
            wid = receipt["wave_id"]
            if not isinstance(wid, str) or not re.match(r"^WAVE-\d{8}-\d{2}$", wid):
                errors.append(f"bad wave_id: {wid}")

        if "commit_hashes" in receipt:
            if not isinstance(receipt["commit_hashes"], list):
                errors.append("commit_hashes not array")
            else:
                commit_pat = re.compile(commit_ref_pattern)
                for h in receipt["commit_hashes"]:
                    if not isinstance(h, str) or not commit_pat.match(h):
                        errors.append(f"bad commit_hash: {h}")

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
                        if not isinstance(rk, str) or not _run_key_matches(rk):
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

        allowed = set(required_fields + ["wave_id", "commit_hashes", "loop_id", "gap_ids", "evidence_refs"])
        for key in receipt.keys():
            if key not in allowed:
                errors.append(f"unknown field: {key}")

        return errors

    if os.path.isdir(receipts_dir):
        for fn in sorted(os.listdir(receipts_dir)):
            if not fn.endswith(".json"):
                continue
            fp = os.path.join(receipts_dir, fn)
            try:
                with open(fp) as rf:
                    r = json.load(rf)
                errs = _validate_receipt_close(r)
                if errs:
                    invalid_receipts.append(f"{fn}: {'; '.join(errs)}")
                else:
                    valid_receipt_count += 1
                    valid_receipts.append(r)
            except json.JSONDecodeError as e:
                invalid_receipts.append(f"{fn}: invalid JSON ({e})")

    if invalid_receipts:
        infra_violations.append(f"{len(invalid_receipts)} invalid receipt(s) in receipts/")

    # 6. Verify/preflight checks present
    done_checks = [c for c in checks if c["status"] == "done"]
    if checks and not done_checks:
        infra_violations.append("No watcher checks completed successfully")

    # 7. DoD guard completeness
    verify_results = []
    for c in checks:
        rk = c.get("run_key")
        if isinstance(rk, str) and rk:
            verify_results.append(rk)
    for r in valid_receipts:
        for rk in r.get("run_keys", []):
            if isinstance(rk, str) and rk:
                verify_results.append(rk)
        evidence_refs = r.get("evidence_refs") if isinstance(r.get("evidence_refs"), dict) else {}
        for rk in evidence_refs.get("run_key_refs", []) if isinstance(evidence_refs.get("run_key_refs"), list) else []:
            if isinstance(rk, str) and rk:
                verify_results.append(rk)
    if not verify_results:
        dod_violations.append("DoD missing verify results (no run keys in watcher checks or receipts)")

    blocker_classes = []
    cleanup_proof = []
    linkage_errors = []
    packet_loop_id = str(packet.get("loop_id", "")).strip()
    blocked_or_failed = [d for d in dispatches if d.get("status") in ("blocked", "failed")]

    if packet_loop_id and packet_loop_id.lower() == "null":
        packet_loop_id = ""
    if not packet_loop_id:
        linkage_errors.append("packet.loop_id missing")

    for r in valid_receipts:
        evidence_refs = r.get("evidence_refs") if isinstance(r.get("evidence_refs"), dict) else {}
        blocker_class = str(evidence_refs.get("blocker_class", "")).strip() if evidence_refs else ""
        if blocker_class:
            blocker_classes.append(blocker_class)

        for ref in evidence_refs.get("file_refs", []) if isinstance(evidence_refs.get("file_refs"), list) else []:
            if isinstance(ref, str) and ref and ("cleanup" in ref.lower() or "clean" in ref.lower()):
                cleanup_proof.append(ref)

        receipt_loop = str(r.get("loop_id", "")).strip()
        if packet_loop_id and receipt_loop != packet_loop_id:
            linkage_errors.append(
                f"receipt task_id={r.get('task_id', '?')} loop_id mismatch (expected {packet_loop_id}, got {receipt_loop or 'missing'})"
            )

        for gap_id in r.get("gap_ids", []) if isinstance(r.get("gap_ids"), list) else []:
            if not isinstance(gap_id, str) or not re.match(r"^GAP-[A-Z0-9-]+$", gap_id):
                linkage_errors.append(f"receipt task_id={r.get('task_id', '?')} has invalid gap_id '{gap_id}'")

    for d in dispatches:
        expected = d.get("expected_output_refs") if isinstance(d.get("expected_output_refs"), dict) else {}
        cleanup_ref = str(expected.get("cleanup_ref", "")).strip() if expected else ""
        if cleanup_ref:
            cleanup_proof.append(cleanup_ref)

    if blocked_or_failed and not blocker_classes:
        dod_violations.append("DoD missing blocker classification for blocked/failed dispatches")
    elif not blocker_classes:
        blocker_classes.append("none")

    if not cleanup_proof:
        dod_violations.append("DoD missing cleanup proof (no cleanup refs in evidence/output refs)")

    if linkage_errors:
        dod_violations.append("DoD linkage integrity failed: " + "; ".join(linkage_errors))

    state["dod"] = {
        "verify_results": sorted(set(verify_results)),
        "blocker_classification": sorted(set(blocker_classes)),
        "cleanup_proof": sorted(set(cleanup_proof)),
        "linkage": {
            "packet_loop_id": packet_loop_id,
            "valid_receipts": valid_receipt_count,
            "errors": linkage_errors,
        },
    }

    lifecycle_state = str(state.get(state_field, state.get("lifecycle_state", "active"))).strip() or "active"
    if lifecycle_state not in state_transitions:
        infra_violations.append(f"state machine unknown state '{lifecycle_state}'")
    else:
        allowed = state_transitions.get(lifecycle_state, set())
        if "closed" not in allowed:
            infra_violations.append(f"state machine blocked: {lifecycle_state} -> closed not allowed")

    role_flow = state.get("role_flow") if isinstance(state.get("role_flow"), dict) else {}
    current_role = str(role_flow.get("current_role", "")).strip()
    if close_aliases and current_role and current_role not in close_aliases:
        infra_violations.append(
            f"role flow blocked close: current_role={current_role} expected one of {sorted(close_aliases)}"
        )

    # ── Gate decision ──
    infra_blocked = bool(infra_violations) and not force
    dod_blocked = bool(dod_violations) and not dod_override_reason

    if infra_blocked or dod_blocked:
        print("BLOCKED: Wave close contract not met:")
        if infra_violations:
            print("Infra violations:")
            for v in infra_violations:
                print(f"  - {v}")
        if dod_violations:
            print("DoD violations:")
            for v in dod_violations:
                print(f"  - {v}")
        if invalid_receipts:
            print()
            print("Invalid receipts:")
            for ir in invalid_receipts:
                print(f"  - {ir}")
        print()
        print("Options:")
        print(f"  1. Fix issues, then retry: ops wave close {state['wave_id']}")
        if infra_violations:
            print(f"  2. Force close (infra only): ops wave close {state['wave_id']} --force")
        if dod_violations:
            print(
                "  3. Override DoD with explicit reason: "
                f"ops wave close {state['wave_id']} --dod-override \"<reason>\""
            )
        sys.exit(1)

    if infra_violations and force:
        print(f"WARNING: Forcing close with {len(infra_violations)} infra violation(s):")
        for v in infra_violations:
            print(f"  - {v}")
        print()

    if dod_violations and dod_override_reason:
        print(f"WARNING: Overriding {len(dod_violations)} DoD violation(s):")
        for v in dod_violations:
            print(f"  - {v}")
        print(f"  DoD override reason: {dod_override_reason}")
        print()

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    state["status"] = "closed"
    state["closed_at"] = now
    state["force_closed"] = bool(infra_violations)
    state["dod_overridden"] = bool(dod_violations)
    state["dod_override_reason"] = dod_override_reason if dod_violations else ""
    state["lock_overridden"] = bool(lock_override_reason)
    state["lock_override_reason"] = lock_override_reason
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

# ── Generate merge receipt (JSON + markdown) ──
done_checks = sum(1 for c in checks if c["status"] == "done")
failed_checks = sum(1 for c in checks if c["status"] == "failed")
run_keys = [c["run_key"] for c in checks if c.get("run_key")]
workspace = state.get("workspace") if isinstance(state.get("workspace"), dict) else {}

# Also collect run keys from validated receipt artifacts only
for r in valid_receipts:
    for rk in r.get("run_keys", []):
        if rk not in run_keys:
            run_keys.append(rk)

residual_blockers = []
for v in infra_violations:
    residual_blockers.append(f"Infra violation (force-closed): {v}")
for v in dod_violations:
    residual_blockers.append(f"DoD violation (override): {v}")
for c in checks:
    if c["status"] == "failed":
        residual_blockers.append(f"Watcher check failed: {c['cap']} (exit={c.get('exit_code', '?')})")
if pf and pf.get("verdict") == "no-go":
    for b in pf.get("blockers", []):
        residual_blockers.append(f"Preflight blocker: {b}")

ready_for_adoption = not residual_blockers

# JSON close receipt
close_receipt = {
    "wave_id": state["wave_id"],
    "objective": state.get("objective", ""),
    "created_at": state["created_at"],
    "closed_at": now,
    "force_closed": bool(infra_violations),
    "dod_overridden": bool(dod_violations),
    "dod_override_reason": dod_override_reason if dod_violations else "",
    "lock_overridden": bool(lock_override_reason),
    "lock_override_reason": lock_override_reason,
    "dispatches": len(dispatches),
    "dispatches_done": sum(1 for d in dispatches if d["status"] == "done"),
    "dispatches_blocked": sum(1 for d in dispatches if d["status"] == "blocked"),
    "watcher_checks_done": done_checks,
    "watcher_checks_failed": failed_checks,
    "valid_receipts": valid_receipt_count,
    "invalid_receipts": len(invalid_receipts),
    "run_keys": run_keys,
    "residual_blockers": residual_blockers,
    "READY_FOR_ADOPTION": ready_for_adoption,
    "dod": state.get("dod", {}),
    "workspace": workspace if workspace else None,
}

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

# ── Dispatch ─────────────────────────────────────────────────────────────

case "${1:-}" in
  start)              shift; cmd_start "$@" ;;
  dispatch)           shift; cmd_dispatch "$@" ;;
  ack)                shift; cmd_ack "$@" ;;
  collect)            shift; cmd_collect_v2 "$@" ;;
  status)             shift; cmd_status "$@" ;;
  close)              shift; cmd_close_v2 "$@" ;;
  preflight)          shift; cmd_preflight "$@" ;;
  receipt-validate)   shift; cmd_receipt_validate "$@" ;;
  -h|--help)          usage ;;
  "")                 usage ;;
  *)
    echo "Unknown wave subcommand: $1" >&2
    usage
    exit 1
    ;;
esac
