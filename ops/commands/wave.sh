#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops wave - Wave orchestration with lane-aware dispatch
# ═══════════════════════════════════════════════════════════════════════════
#
# Coordinates multi-terminal work across lanes with non-blocking preflight,
# background watcher for long checks, and unified status view.
#
# Usage:
#   ops wave start <WAVE_ID> --objective "<text>" [--worktree auto|off] [--repo <path>]
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

ts_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ── Subcommands ──────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
ops wave - Wave orchestration with lane-aware dispatch

Usage:
  ops wave start <WAVE_ID> --objective "<text>" [--worktree auto|off] [--repo <path>]
                                                    Create a new wave (default auto worktree)
  ops wave dispatch <WAVE_ID> --lane <L> --task "T" [--from-role <R>] [--to-role <R>] [--input-refs "k=v,..."] [--output-refs "k=v,..."]  Dispatch task to a lane
  ops wave ack <WAVE_ID> --lane <L> --result "text"  Acknowledge task completion
  ops wave collect <WAVE_ID>                         Collect results from lanes
  ops wave status [WAVE_ID]                          Show wave status (or all)
  ops wave close <WAVE_ID> [--force]                 Close a wave (enforces contract)
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
  local worktree_mode="auto"
  local workspace_repo="$SPINE_REPO"
  local workspace_enabled="false"
  local workspace_branch=""
  local workspace_worktree=""
  local workspace_note=""
  local default_role="researcher"
  local default_next_role="worker"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --objective) objective="${2:-}"; shift 2 ;;
      --worktree) worktree_mode="${2:-}"; shift 2 ;;
      --repo) workspace_repo="${2:-}"; shift 2 ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) wave_id="$1"; shift ;;
    esac
  done

  if [[ -z "$wave_id" ]]; then
    echo "Usage: ops wave start <WAVE_ID> --objective \"<text>\" [--worktree auto|off] [--repo <path>]" >&2
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
    default_role="$(yq e -r '.runtime_roles.default_role // "researcher"' "$ROLE_RUNTIME_CONTRACT" 2>/dev/null || echo researcher)"
    if [[ -n "$default_role" && "$default_role" != "null" ]]; then
      local resolved_next
      resolved_next="$(yq e -r ".promotion_gates.transitions[]? | select(.from == \"$default_role\") | .to" "$ROLE_RUNTIME_CONTRACT" 2>/dev/null | head -n1 || true)"
      if [[ -n "$resolved_next" && "$resolved_next" != "null" ]]; then
        default_next_role="$resolved_next"
      fi
    fi
  fi

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

  python3 - "$sf" "$wave_id" "$objective" "$workspace_enabled" "$workspace_repo" "$workspace_worktree" "$workspace_branch" "$workspace_note" "$default_role" "$default_next_role" <<'PYSTART'
import json, sys
from datetime import datetime, timezone

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

state = {
    "wave_id": wave_id,
    "status": "active",
    "objective": objective,
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
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
}

with open(sf, "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

print(f"Wave '{wave_id}' created.")
if objective:
    print(f"  Objective: {objective}")
print(f"  Status: active")
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
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) wave_id="$1"; shift ;;
    esac
  done

  if [[ -z "$wave_id" || -z "$lane" || -z "$task" ]]; then
    echo "Usage: ops wave dispatch <WAVE_ID> --lane <lane> --task \"<text>\" [--from-role <role>] [--to-role <role>] [--input-refs \"k=v,...\"] [--output-refs \"k=v,...\"]" >&2
    exit 1
  fi

  ensure_wave_exists "$wave_id"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local sd
  sd="$(wave_state_dir "$wave_id")"

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

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift ;;
      --lane) lane="${2:-}"; shift 2 ;;
      --result) result="${2:-}"; shift 2 ;;
      --run-key) run_key="${2:-}"; shift 2 ;;
      --dispatch) dispatch_id="${2:-}"; shift 2 ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) wave_id="$1"; shift ;;
    esac
  done

  if [[ -z "$wave_id" ]]; then
    echo "Usage: ops wave ack <WAVE_ID> --lane <lane> [--dispatch D<N>] --result \"<text>\" [--run-key <key>]" >&2
    exit 1
  fi
  if [[ -z "$lane" && -z "$dispatch_id" ]]; then
    echo "Must specify --lane <lane> or --dispatch D<N> to identify the task" >&2
    exit 1
  fi

  ensure_wave_exists "$wave_id"
  local sf
  sf="$(wave_state_file "$wave_id")"

  python3 - "$sf" "$lane" "$result" "$run_key" "$dispatch_id" <<'PYACK'
import json, sys, fcntl, os
from datetime import datetime, timezone

sf = sys.argv[1]
lane = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
result = sys.argv[3] if len(sys.argv) > 3 else ""
run_key = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else None
dispatch_id = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else None
lock_file = sf + ".lock"

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
                d["status"] = "done"
                d["completed_at"] = now
                d["result"] = result
                d["run_key"] = run_key
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
            d["status"] = "done"
            d["completed_at"] = now
            d["result"] = result
            d["run_key"] = run_key
            acked_idx = idx

    if acked_idx is None:
        print("No dispatch acked.")
        sys.exit(1)

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
PYACK
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
    echo "Usage: ops wave close <WAVE_ID> [--force]" >&2
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

  python3 - "$receipt_path" "$schema_path" <<'PYVALIDATE'
import json, sys, re, os

receipt_path = sys.argv[1]
schema_path = sys.argv[2]

errors = []

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
run_key_pattern = re.compile(r"^CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+$")
for i, rk in enumerate(receipt.get("run_keys", [])):
    if not isinstance(rk, str):
        errors.append(f"run_keys[{i}] must be a string")
    elif not run_key_pattern.match(rk):
        errors.append(f"run_keys[{i}] '{rk}' does not match CAP-XXXXXXXX-XXXXXX__cap.name__Rxxxx pattern")

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
        for i, h in enumerate(receipt["commit_hashes"]):
            if not isinstance(h, str) or not re.match(r"^[0-9a-f]{7,40}$", h):
                errors.append(f"commit_hashes[{i}] must be a 7-40 char hex string")

# additionalProperties check
allowed_keys = set(required + ["wave_id", "commit_hashes", "loop_id", "gap_ids"])
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

  python3 - "$sf" "$sd" "$receipts_dir" "$schema_path" "$sync_roadmap" "$SPINE_REPO" <<'PYCOLLECT2'
import json, sys, os, re, glob, fcntl
from datetime import datetime, timezone

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
    rk_pat = re.compile(r"^CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+$")
    for rk in receipt.get("run_keys", []):
        if isinstance(rk, str) and not rk_pat.match(rk):
            errors.append(f"bad run_key: {rk}")
    if receipt.get("status") == "blocked" and not receipt.get("blockers"):
        errors.append("blocked needs blockers[]")
    allowed = set(required + ["wave_id", "commit_hashes", "loop_id", "gap_ids"])
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
lock_file = sf + ".lock"

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
}

# ── Enhanced close with receipt gating ─────────────────────────────────

cmd_close_v2() {
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
    echo "Usage: ops wave close <WAVE_ID> [--force]" >&2
    exit 1
  fi

  ensure_wave_exists "$wave_id"
  local sf
  sf="$(wave_state_file "$wave_id")"
  local sd
  sd="$(wave_state_dir "$wave_id")"

  python3 - "$sf" "$sd" "$force" "$SPINE_REPO" <<'PYCLOSE2'
import json, sys, os, re, fcntl
from datetime import datetime, timezone

sf = sys.argv[1]
sd = sys.argv[2]
force = sys.argv[3] == "true"
spine_repo = sys.argv[4]
lock_file = sf + ".lock"
receipts_dir = os.path.join(sd, "receipts")

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
    contract_violations = []

    # 1. Watcher checks must be done/failed
    running = [c for c in checks if c["status"] in ("queued", "running")]
    if running:
        statuses = "/".join(sorted(set(c["status"] for c in running)))
        contract_violations.append(f"{len(running)} watcher check(s) still {statuses}")

    # 2. Preflight required
    if not pf:
        contract_violations.append("Preflight has not been run (required by wave.lifecycle contract)")

    # 3. All dispatches must be done or explicitly blocked
    pending = [d for d in dispatches if d["status"] == "dispatched"]
    if pending:
        contract_violations.append(f"{len(pending)} dispatch(es) still pending (not done/blocked)")

    # 4. Receipt validation: all receipt files must satisfy EXEC_RECEIPT contract
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

        rk_pat = re.compile(r"^CAP-\d{8}-\d{6}__[A-Za-z0-9._-]+__R[A-Za-z0-9]+$")
        for rk in receipt.get("run_keys", []):
            if not isinstance(rk, str):
                errors.append("run_key not string")
            elif not rk_pat.match(rk):
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
                for h in receipt["commit_hashes"]:
                    if not isinstance(h, str) or not re.match(r"^[0-9a-f]{7,40}$", h):
                        errors.append(f"bad commit_hash: {h}")

        allowed = set(required_fields + ["wave_id", "commit_hashes", "loop_id", "gap_ids"])
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
        contract_violations.append(f"{len(invalid_receipts)} invalid receipt(s) in receipts/")

    # 5. Verify/preflight checks present
    done_checks = [c for c in checks if c["status"] == "done"]
    if checks and not done_checks:
        contract_violations.append("No watcher checks completed successfully")

    # ── Gate decision ──
    if contract_violations and not force:
        print("BLOCKED: Wave close contract not met:")
        for v in contract_violations:
            print(f"  - {v}")
        if invalid_receipts:
            print()
            print("Invalid receipts:")
            for ir in invalid_receipts:
                print(f"  - {ir}")
        print()
        print("Options:")
        print(f"  1. Fix issues, then retry: ops wave close {state['wave_id']}")
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
for v in contract_violations:
    residual_blockers.append(f"Contract violation (force-closed): {v}")
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
    "force_closed": bool(contract_violations),
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
