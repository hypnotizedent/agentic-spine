#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops wave - Wave orchestration with lane-aware dispatch
# ═══════════════════════════════════════════════════════════════════════════
#
# Coordinates multi-terminal work across lanes with non-blocking preflight,
# background watcher for long checks, and unified status view.
#
# Usage:
#   ops wave start <WAVE_ID> --objective "<text>"
#   ops wave dispatch <WAVE_ID> --lane <lane> --task "<text>"
#   ops wave collect <WAVE_ID>
#   ops wave status [WAVE_ID]
#   ops wave close <WAVE_ID>
#   ops wave preflight <domain>
#
# State: $RUNTIME_ROOT/waves/<WAVE_ID>/state.json (runtime-only)
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
RUNTIME_ROOT="${SPINE_RUNTIME_ROOT:-$HOME/code/.runtime/spine-mailroom}"
WAVES_DIR="$RUNTIME_ROOT/waves"
LANES_STATE="$RUNTIME_ROOT/lanes/state.json"

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
  ops wave start <WAVE_ID> --objective "<text>"      Create a new wave
  ops wave dispatch <WAVE_ID> --lane <L> --task "T"  Dispatch task to a lane
  ops wave ack <WAVE_ID> --lane <L> --result "text"  Acknowledge task completion
  ops wave collect <WAVE_ID>                         Collect results from lanes
  ops wave status [WAVE_ID]                          Show wave status (or all)
  ops wave close <WAVE_ID> [--force]                 Close a wave (enforces contract)
  ops wave preflight <domain>                        Fast non-blocking preflight

Wave IDs: use WAVE-YYYYMMDD-NN format (e.g. WAVE-20260222-01)

Background Watcher:
  The watcher lane auto-enqueues long checks (stability.control.snapshot,
  verify.core.run, verify.pack.run) and tracks them without blocking.
  Results appear in 'ops wave status' when complete.
EOF
}

cmd_start() {
  local wave_id=""
  local objective=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --objective) objective="${2:-}"; shift 2 ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) wave_id="$1"; shift ;;
    esac
  done

  if [[ -z "$wave_id" ]]; then
    echo "Usage: ops wave start <WAVE_ID> --objective \"<text>\"" >&2
    exit 1
  fi

  local sd
  sd="$(wave_state_dir "$wave_id")"
  local sf="$sd/state.json"

  if [[ -f "$sf" ]]; then
    echo "Wave '$wave_id' already exists." >&2
    exit 1
  fi

  mkdir -p "$sd"

  python3 - "$sf" "$wave_id" "$objective" <<'PYSTART'
import json, sys
from datetime import datetime, timezone

sf = sys.argv[1]
wave_id = sys.argv[2]
objective = sys.argv[3] if len(sys.argv) > 3 else ""

state = {
    "wave_id": wave_id,
    "status": "active",
    "objective": objective,
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "closed_at": None,
    "dispatches": [],
    "watcher_checks": [],
    "preflight": None,
    "results": []
}

with open(sf, "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

print(f"Wave '{wave_id}' created.")
if objective:
    print(f"  Objective: {objective}")
print(f"  Status: active")
print(f"  Next: ops wave preflight <domain>")
print(f"         ops wave dispatch {wave_id} --lane <lane> --task \"...\"")
PYSTART
}

cmd_dispatch() {
  local wave_id=""
  local lane=""
  local task=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --lane) lane="${2:-}"; shift 2 ;;
      --task) task="${2:-}"; shift 2 ;;
      -*) echo "Unknown flag: $1" >&2; exit 1 ;;
      *) wave_id="$1"; shift ;;
    esac
  done

  if [[ -z "$wave_id" || -z "$lane" || -z "$task" ]]; then
    echo "Usage: ops wave dispatch <WAVE_ID> --lane <lane> --task \"<text>\"" >&2
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

  python3 - "$sf" "$lane" "$task" <<'PYDISP'
import json, sys, fcntl, os
from datetime import datetime, timezone

sf = sys.argv[1]
lane = sys.argv[2]
task = sys.argv[3]
lock_file = sf + ".lock"

fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(sf) as f:
        state = json.load(f)

    dispatch = {
        "lane": lane,
        "task": task,
        "status": "dispatched",
        "dispatched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "completed_at": None,
        "result": None,
        "run_key": None
    }

    state["dispatches"].append(dispatch)

    with open(sf, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)

idx = len(state["dispatches"])
print(f"Dispatched task #{idx} to lane '{lane}':")
print(f"  Task: {task}")
print(f"  Dispatch ID: D{idx}")
print(f"  Status: dispatched")
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

  # Default long checks for the watcher
  local checks=("stability.control.snapshot" "verify.core.run" "verify.pack.run core-operator")

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
        {"cap": "verify.core.run", "status": "queued", "run_key": None, "pid": None, "exit_code": None},
        {"cap": "verify.pack.run core-operator", "status": "queued", "run_key": None, "pid": None, "exit_code": None}
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

  # ── 2. Git state check ──
  echo "[2/4] Git state..."
  local branch
  branch="$(git -C "$SPINE_REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
  local dirty
  dirty="$(git -C "$SPINE_REPO" status --porcelain 2>/dev/null | head -5 | wc -l | tr -d ' ')"
  echo "  Branch: $branch"
  echo "  Dirty files: $dirty"
  if [[ "$dirty" -gt 10 ]]; then
    blockers+=("Excessive dirty files ($dirty)")
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
        mh_out="$(curl -s --connect-timeout 5 --max-time 10 http://100.76.153.100:3100/health 2>/dev/null || echo 'unreachable')"
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
        ha_out="$(curl -s --connect-timeout 5 --max-time 10 http://10.0.0.100:8123/api/ 2>/dev/null || echo 'unreachable')"
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
  if [[ -n "$active_wave_sf" ]]; then
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

# ── Dispatch ─────────────────────────────────────────────────────────────

case "${1:-}" in
  start)      shift; cmd_start "$@" ;;
  dispatch)   shift; cmd_dispatch "$@" ;;
  ack)        shift; cmd_ack "$@" ;;
  collect)    cmd_collect "${2:-}" ;;
  status)     cmd_status "${2:-}" ;;
  close)      shift; cmd_close "$@" ;;
  preflight)  shift; cmd_preflight "$@" ;;
  -h|--help)  usage ;;
  "")         usage ;;
  *)
    echo "Unknown wave subcommand: $1" >&2
    usage
    exit 1
    ;;
esac
