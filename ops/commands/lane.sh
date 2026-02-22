#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops lane - Lane-aware terminal orchestrator
# ═══════════════════════════════════════════════════════════════════════════
#
# Manages terminal lanes with write-scope enforcement. Each lane profile
# defines what a terminal is allowed to write, preventing cross-lane
# collision in multi-terminal sessions.
#
# Usage:
#   ops lane list                  List available lane profiles
#   ops lane open <profile>        Open a lane (sets write scope)
#   ops lane status                Show all open lanes
#   ops lane close [profile]       Close a lane (or current lane)
#
# Profiles:
#   control    - Writer for docs/planning/*, governance surfaces
#   execution  - Writer for domain repos (e.g. mint-modules), no roadmap
#   audit      - Read-only evidence collection
#   watcher    - Read-only long-running checks only
#
# State: $RUNTIME_ROOT/lanes/state.json (runtime-only, not committed)
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
RUNTIME_ROOT="${SPINE_RUNTIME_ROOT:-$HOME/code/.runtime/spine-mailroom}"
LANES_DIR="$RUNTIME_ROOT/lanes"
LANES_STATE="$LANES_DIR/state.json"

# Ensure state directory exists
mkdir -p "$LANES_DIR"

# Initialize state file if missing
if [[ ! -f "$LANES_STATE" ]]; then
  cat > "$LANES_STATE" <<'INIT'
{
  "lanes": {},
  "version": 1
}
INIT
fi

# ── Lane profile loader (reads from contract YAML, fallback to hardcoded) ──

LANE_PROFILES_YAML="$SPINE_REPO/ops/bindings/lane.profiles.yaml"

# ── Subcommands ──────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
ops lane - Lane-aware terminal orchestrator

Usage:
  ops lane list                  List available lane profiles
  ops lane open <profile>        Open a lane (sets write scope)
  ops lane status                Show all open lanes
  ops lane close [profile]       Close a lane (or current lane)
  ops lane check <path>          Check if a path is writable in current lane

Profiles:
  control    Writer for docs/planning/*, governance surfaces, can merge
  execution  Writer for domain repos (plugins, surfaces), no roadmap edits
  audit      Read-only evidence collection
  watcher    Read-only long-running checks only
EOF
}

cmd_list() {
  python3 - "$LANE_PROFILES_YAML" <<'PYLIST'
import sys, os

contract_file = sys.argv[1]
profiles = {}

# Load from contract YAML (authoritative source)
if os.path.exists(contract_file):
    try:
        import yaml
        with open(contract_file) as f:
            doc = yaml.safe_load(f)
        for name, p in doc.get("profiles", {}).items():
            ws = p.get("write_surfaces", [])
            profiles[name] = {
                "desc": p.get("description", ""),
                "write": ", ".join(ws) if ws else "(none)",
                "mode": p.get("mode", "read-only"),
                "merge": "Y" if p.get("can_merge") else "N"
            }
    except ImportError:
        pass  # fall through to fallback

# Fallback if YAML not loaded
if not profiles:
    profiles = {
        "control":   {"desc": "Writer for planning docs + governance. Can merge.", "write": "docs/planning/*, docs/governance/*, mailroom/state/*", "mode": "read-write", "merge": "Y"},
        "execution": {"desc": "Writer for domain repos (plugins, surfaces). No roadmap.", "write": "ops/plugins/*, surfaces/*", "mode": "read-write", "merge": "N"},
        "audit":     {"desc": "Read-only evidence collection.", "write": "(none)", "mode": "read-only", "merge": "N"},
        "watcher":   {"desc": "Read-only background checks.", "write": "(none)", "mode": "read-only", "merge": "N"},
    }

source = "contract" if os.path.exists(contract_file) else "fallback"
print("=" * 72)
print(f"  LANE PROFILES (source: {source})")
print("=" * 72)
print()
for name, p in profiles.items():
    print(f"  {name:12s}  {p['mode']:12s}  merge={p['merge']}  {p['desc']}")
    print(f"  {'':12s}  {'':12s}         write: {p['write']}")
    print()
print("=" * 72)
print("  Open a lane:  ops lane open <profile>")
print("=" * 72)
PYLIST
}

cmd_open() {
  local profile="${1:-}"
  if [[ -z "$profile" ]]; then
    echo "Usage: ops lane open <profile>" >&2
    echo "Profiles: control, execution, audit, watcher" >&2
    exit 1
  fi

  # Validate profile name against contract YAML (or fallback list)
  local valid_profiles
  valid_profiles="$(python3 -c "
import os
try:
    import yaml
    cf = '$LANE_PROFILES_YAML'
    if os.path.exists(cf):
        with open(cf) as f:
            doc = yaml.safe_load(f)
        print(' '.join(doc.get('profiles', {}).keys()))
    else:
        print('control execution audit watcher')
except ImportError:
    print('control execution audit watcher')
" 2>/dev/null || echo 'control execution audit watcher')"

  local found=false
  for vp in $valid_profiles; do
    if [[ "$vp" == "$profile" ]]; then
      found=true
      break
    fi
  done
  if [[ "$found" != "true" ]]; then
    echo "Unknown lane profile: $profile" >&2
    echo "Valid profiles: $valid_profiles" >&2
    exit 1
  fi

  local terminal_id="${SPINE_TERMINAL_ID:-$$}"

  python3 - "$LANES_STATE" "$profile" "$terminal_id" <<'PYOPEN'
import json, sys, os, fcntl
from datetime import datetime, timezone

state_file = sys.argv[1]
profile = sys.argv[2]
terminal_id = sys.argv[3]
lock_file = state_file + ".lock"

fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    with open(state_file) as f:
        state = json.load(f)

    lanes = state.get("lanes", {})

    # Check if this profile is already open
    if profile in lanes:
        existing = lanes[profile]
        print(f"Lane '{profile}' is already open (terminal {existing['terminal_id']}, since {existing['opened_at']})")
        sys.exit(1)

    # Check for conflicting lanes (control + execution can coexist, but warn)
    if profile == "execution" and "control" in lanes:
        print("NOTE: control lane is already open. execution lane will be deny-scoped from docs/planning/*")
    elif profile == "control" and "execution" in lanes:
        print("NOTE: execution lane is already open. control lane can merge handoffs from it.")

    lanes[profile] = {
        "terminal_id": terminal_id,
        "opened_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "profile": profile
    }

    state["lanes"] = lanes

    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)

# Set environment hint (outside lock — only writes to a per-profile file, no contention)
env_file = os.path.join(os.path.dirname(state_file), f".lane-{profile}.env")
with open(env_file, "w") as f:
    f.write(f"export SPINE_LANE={profile}\n")
    f.write(f"export SPINE_TERMINAL_ID={terminal_id}\n")

print(f"Lane '{profile}' opened for terminal {terminal_id}")
print(f"  Env hint: source {env_file}")
print(f"  Or set: export SPINE_LANE={profile}")
PYOPEN
}

cmd_status() {
  python3 - "$LANES_STATE" "$LANE_PROFILES_YAML" <<'PYSTATUS'
import json, sys, os

state_file = sys.argv[1]
contract_file = sys.argv[2]

try:
    with open(state_file) as f:
        state = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    print("No lanes open.")
    sys.exit(0)

lanes = state.get("lanes", {})

if not lanes:
    print("No lanes open.")
    sys.exit(0)

# Load profile metadata from contract YAML (authoritative)
profiles_meta = None
if os.path.exists(contract_file):
    try:
        import yaml
        with open(contract_file) as f:
            doc = yaml.safe_load(f)
        profiles_meta = {}
        for name, p in doc.get("profiles", {}).items():
            profiles_meta[name] = {
                "mode": p.get("mode", "read-only"),
                "merge": p.get("can_merge", False),
                "dispatch": p.get("can_dispatch", False),
            }
    except ImportError:
        pass

# Fallback if YAML not loaded
if not profiles_meta:
    profiles_meta = {
        "control":   {"mode": "read-write", "merge": True,  "dispatch": True},
        "execution": {"mode": "read-write", "merge": False, "dispatch": False},
        "audit":     {"mode": "read-only",  "merge": False, "dispatch": False},
        "watcher":   {"mode": "read-only",  "merge": False, "dispatch": False},
    }

source = "contract" if os.path.exists(contract_file) else "fallback"
print("=" * 72)
print(f"  OPEN LANES (source: {source})")
print("=" * 72)
print()

for name, info in sorted(lanes.items()):
    meta = profiles_meta.get(name, {})
    mode = meta.get("mode", "unknown")
    merge = "yes" if meta.get("merge") else "no"
    dispatch = "yes" if meta.get("dispatch") else "no"
    print(f"  {name:12s}  terminal={info['terminal_id']}  since={info['opened_at']}")
    print(f"  {'':12s}  mode={mode}  merge={merge}  dispatch={dispatch}")
    print()

print("=" * 72)
print(f"  {len(lanes)} lane(s) open")
print("=" * 72)
PYSTATUS
}

cmd_close() {
  local profile="${1:-${SPINE_LANE:-}}"
  if [[ -z "$profile" ]]; then
    echo "Usage: ops lane close <profile>" >&2
    echo "Or set SPINE_LANE to close the current lane." >&2
    exit 1
  fi

  python3 - "$LANES_STATE" "$profile" <<'PYCLOSE'
import json, sys, os, fcntl

state_file = sys.argv[1]
profile = sys.argv[2]
lock_file = state_file + ".lock"

info = None
fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    try:
        with open(state_file) as f:
            state = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        print(f"No lanes state found.")
        sys.exit(1)

    lanes = state.get("lanes", {})

    if profile not in lanes:
        print(f"Lane '{profile}' is not open.")
        sys.exit(1)

    info = lanes.pop(profile)
    state["lanes"] = lanes

    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)

# Remove env hint file (outside lock — per-profile file, no contention)
env_file = os.path.join(os.path.dirname(state_file), f".lane-{profile}.env")
if os.path.exists(env_file):
    os.remove(env_file)

print(f"Lane '{profile}' closed (was terminal {info['terminal_id']}, opened {info['opened_at']})")
PYCLOSE
}

cmd_check() {
  local target_path="${1:-}"
  local current_lane="${SPINE_LANE:-}"

  if [[ -z "$target_path" ]]; then
    echo "Usage: ops lane check <path>" >&2
    exit 1
  fi
  if [[ -z "$current_lane" ]]; then
    echo "No lane active (set SPINE_LANE or run: ops lane open <profile>)" >&2
    exit 1
  fi

  python3 - "$current_lane" "$target_path" "$LANE_PROFILES_YAML" <<'PYCHECK'
import sys, fnmatch, os

profile = sys.argv[1]
target = sys.argv[2]
contract_file = sys.argv[3]

# Load profiles from contract YAML (authoritative), fallback to hardcoded
profiles = None
if os.path.exists(contract_file):
    try:
        import yaml
        with open(contract_file) as f:
            doc = yaml.safe_load(f)
        raw = doc.get("profiles", {})
        profiles = {}
        for name, p in raw.items():
            profiles[name] = {
                "write_scope": p.get("write_surfaces", []),
                "deny_scope": p.get("deny_surfaces", [])
            }
    except ImportError:
        pass

if not profiles:
    profiles = {
        "control":   {"write_scope": ["docs/planning/*", "docs/governance/*", "mailroom/state/*"], "deny_scope": []},
        "execution": {"write_scope": ["ops/plugins/*", "surfaces/*"], "deny_scope": ["docs/planning/*", "docs/governance/*"]},
        "audit":     {"write_scope": [], "deny_scope": ["*"]},
        "watcher":   {"write_scope": [], "deny_scope": ["*"]},
    }

p = profiles.get(profile)
if not p:
    print(f"DENY: unknown profile '{profile}'")
    sys.exit(1)

# Check deny first
for pattern in p["deny_scope"]:
    if fnmatch.fnmatch(target, pattern):
        print(f"DENY: '{target}' is denied in lane '{profile}' (matches deny: {pattern})")
        sys.exit(1)

# Check allow
for pattern in p["write_scope"]:
    if fnmatch.fnmatch(target, pattern):
        print(f"ALLOW: '{target}' is writable in lane '{profile}' (matches: {pattern})")
        sys.exit(0)

# Default: deny if not matched
if p["write_scope"]:
    print(f"DENY: '{target}' is not in write scope for lane '{profile}'")
    sys.exit(1)
else:
    print(f"DENY: lane '{profile}' is read-only")
    sys.exit(1)
PYCHECK
}

# ── Dispatch ─────────────────────────────────────────────────────────────

case "${1:-}" in
  list)       cmd_list ;;
  open)       cmd_open "${2:-}" ;;
  status)     cmd_status ;;
  close)      cmd_close "${2:-}" ;;
  check)      cmd_check "${2:-}" ;;
  -h|--help)  usage ;;
  "")         usage ;;
  # Legacy compat: builder/runner/clerk still work
  builder|1)
    source "$SPINE_REPO/ops/commands/preflight.sh"
    cat <<BUILDER
  LANE 1: BUILDER (legacy — use 'ops lane open control' instead)
  Issue: ${CURRENT_ISSUE:-none}
  Worktree: ${CURRENT_WORKTREE:-main}
BUILDER
    ;;
  runner|2)
    echo "  LANE 2: RUNNER (legacy — use 'ops lane open execution' instead)"
    ;;
  clerk|3)
    echo "  LANE 3: CLERK (legacy — use 'ops lane open watcher' instead)"
    ;;
  *)
    echo "Unknown lane subcommand: $1" >&2
    usage
    exit 1
    ;;
esac
