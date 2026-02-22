#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops terminal-launch - Lane-aware terminal app launcher
# ═══════════════════════════════════════════════════════════════════════════
#
# Unified launcher that combines lane profiles + loops for terminal sessions.
# Used by Raycast/Hammerspoon to provide a picker UI.
#
# Usage:
#   ops terminal-launch list-lanes              List available lane profiles (JSON)
#   ops terminal-launch list-loops              List open loops (JSON)
#   ops terminal-launch launch <options>        Launch a terminal
#
# Launch options:
#   --lane <profile>        Lane profile (control|execution|audit|watcher)
#   --loop <loop_id>        Optional loop to attach
#   --tool <tool>           Tool to run (claude|codex|opencode|verify)
#   --terminal <name>       Terminal name (e.g. SPINE-CONTROL-01)
#
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-$HOME/code/workbench}"
LANE_PROFILES_YAML="$SPINE_REPO/ops/bindings/lane.profiles.yaml"
SCOPES_DIR="$SPINE_REPO/mailroom/state/loop-scopes"
LAUNCHER_SCRIPT="$WORKBENCH_ROOT/scripts/root/spine_terminal_entry.sh"

# ── Output helpers ─────────────────────────────────────────────────────────

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    echo "$s"
}

# ── Subcommands ────────────────────────────────────────────────────────────

usage() {
    cat <<'EOF'
ops terminal-launch - Lane-aware terminal app launcher

Usage:
  ops terminal-launch list-lanes              List available lane profiles (JSON)
  ops terminal-launch list-loops              List open loops (JSON)
  ops terminal-launch list-tools              List available tools (JSON)
  ops terminal-launch launch <options>        Launch a terminal

Launch options:
  --lane <profile>        Lane profile (control|execution|audit|watcher)
  --loop <loop_id>        Optional loop to attach (required for worker role)
  --tool <tool>           Tool to run (claude|codex|opencode|verify)
  --terminal <name>       Terminal name (e.g. SPINE-CONTROL-01)
  --role <role>           Role (solo|orchestrator|worker) - auto-derived if not set

Examples:
  ops terminal-launch launch --lane control --tool codex --terminal SPINE-CONTROL-01
  ops terminal-launch launch --lane execution --loop LOOP-MINT-AUTH-20260222 --tool opencode
EOF
}

cmd_list_lanes() {
    # Output JSON array of lane profiles for Raycast picker
    python3 - "$LANE_PROFILES_YAML" <<'PYLANES'
import sys, os, json

contract_file = sys.argv[1]
lanes = []

# Default profiles if YAML unavailable
default_profiles = {
    "control":   {"desc": "Writer for planning docs + governance. Can merge.", "mode": "read-write", "merge": True},
    "execution": {"desc": "Writer for domain repos (plugins, surfaces). No roadmap.", "mode": "read-write", "merge": False},
    "audit":     {"desc": "Read-only evidence collection.", "mode": "read-only", "merge": False},
    "watcher":   {"desc": "Read-only background checks.", "mode": "read-only", "merge": False},
}

profiles = default_profiles.copy()

# Override from contract YAML if available
if os.path.exists(contract_file):
    try:
        import yaml
        with open(contract_file) as f:
            doc = yaml.safe_load(f)
        for name, p in doc.get("profiles", {}).items():
            profiles[name] = {
                "desc": p.get("description", ""),
                "mode": p.get("mode", "read-only"),
                "merge": p.get("can_merge", False),
            }
    except ImportError:
        pass

for name, p in profiles.items():
    lanes.append({
        "id": name,
        "title": name.capitalize(),
        "subtitle": p["desc"],
        "mode": p["mode"],
        "canMerge": p["merge"],
        "accessory": {"text": p["mode"]},
        "actions": [{"title": f"Launch {name.capitalize()} Lane", "type": "run-command"}]
    })

print(json.dumps(lanes, indent=2))
PYLANES
}

cmd_list_loops() {
    # Output JSON array of open loops for Raycast picker
    local loops_json="[]"
    
    if [[ -d "$SCOPES_DIR" ]]; then
        loops_json=$(python3 - "$SCOPES_DIR" <<'PYLOOPS'
import sys, os, json, re
from datetime import datetime

scopes_dir = sys.argv[1]
loops = []

def parse_frontmatter(content):
    """Extract YAML frontmatter fields"""
    fm = {}
    in_fm = False
    for line in content.split('\n'):
        if line.strip() == '---':
            in_fm = not in_fm
            continue
        if in_fm:
            match = re.match(r'^(\w+):\s*(.*)$', line)
            if match:
                key, val = match.groups()
                val = val.strip().strip('"').strip("'")
                fm[key] = val
    return fm

def get_title(content):
    """Extract title from first markdown heading"""
    for line in content.split('\n'):
        if line.startswith('# '):
            return line[2:].replace('Loop Scope: ', '').strip()
    return None

for filename in sorted(os.listdir(scopes_dir), reverse=True):
    if not filename.endswith('.scope.md'):
        continue
    
    filepath = os.path.join(scopes_dir, filename)
    try:
        with open(filepath) as f:
            content = f.read()
        
        fm = parse_frontmatter(content)
        status = fm.get('status', 'unknown')
        
        # Only show open/active loops
        if status not in ('active', 'draft', 'open'):
            continue
        
        loop_id = fm.get('loop_id', filename.replace('.scope.md', ''))
        title = get_title(content) or loop_id
        priority = fm.get('priority', 'medium')
        scope = fm.get('scope', 'unknown')
        created = fm.get('created', '')
        owner = fm.get('owner', '@unknown')
        
        loops.append({
            "id": loop_id,
            "title": title,
            "subtitle": f"{scope} • {priority} • {owner}",
            "priority": priority,
            "scope": scope,
            "created": created,
            "owner": owner,
            "status": status,
            "accessory": {"text": priority[:3].upper()},
        })
    except Exception as e:
        continue

print(json.dumps(loops, indent=2))
PYLOOPS
)
    fi
    
    echo "$loops_json"
}

cmd_list_tools() {
    # Output JSON array of available tools
    cat <<'EOF'
[
  {"id": "opencode", "title": "OpenCode", "subtitle": "AI coding assistant (z.ai)", "icon": "🤖"},
  {"id": "codex", "title": "Codex", "subtitle": "OpenAI Codex CLI", "icon": "💻"},
  {"id": "claude", "title": "Claude Code", "subtitle": "Anthropic Claude CLI", "icon": "🧠"},
  {"id": "verify", "title": "Verify", "subtitle": "Run spine verification", "icon": "✅"}
]
EOF
}

cmd_launch() {
    local lane=""
    local loop_id=""
    local tool="opencode"
    local terminal_name=""
    local role="solo"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lane) lane="${2:-}"; shift 2 ;;
            --loop) loop_id="${2:-}"; shift 2 ;;
            --tool) tool="${2:-}"; shift 2 ;;
            --terminal) terminal_name="${2:-}"; shift 2 ;;
            --role) role="${2:-}"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done
    
    # Validate lane
    if [[ -z "$lane" ]]; then
        echo "ERROR: --lane is required" >&2
        exit 1
    fi
    
    # Validate tool
    case "$tool" in
        opencode|codex|claude|verify) ;;
        *) echo "ERROR: invalid tool: $tool" >&2; exit 1 ;;
    esac
    
    # Derive role from lane + loop
    if [[ -n "$loop_id" ]]; then
        role="orchestrator"
    fi
    
    # Derive terminal name if not provided
    if [[ -z "$terminal_name" ]]; then
        case "$lane" in
            control)   terminal_name="SPINE-CONTROL-01" ;;
            execution) terminal_name="SPINE-EXECUTION-01" ;;
            audit)     terminal_name="SPINE-AUDIT-01" ;;
            watcher)   terminal_name="SPINE-WATCHER-01" ;;
            *)         terminal_name="SPINE-${lane^^}-01" ;;
        esac
    fi
    
    # Check launcher script exists
    if [[ ! -x "$LAUNCHER_SCRIPT" ]]; then
        echo "ERROR: Launcher script not found: $LAUNCHER_SCRIPT" >&2
        echo "Falling back to direct iTerm launch..." >&2
        cmd_launch_direct "$lane" "$loop_id" "$tool" "$terminal_name" "$role"
        return
    fi
    
    # Build command
    local cmd_args=(
        "--role" "$role"
        "--tool" "$tool"
        "--terminal-name" "$terminal_name"
    )
    
    if [[ -n "$loop_id" ]]; then
        cmd_args+=("--loop-id" "$loop_id")
    fi
    
    # Launch via iTerm AppleScript
    local full_cmd="SPINE_HOTKEY_ORCH_MODE=capability SPINE_HOTKEY_ALLOW_FALLBACK=0 $LAUNCHER_SCRIPT ${cmd_args[*]}"
    
    osascript -e "tell application \"iTerm\"
        activate
        set newWindow to (create window with default profile)
        tell current session of newWindow
            write text \"$full_cmd\"
        end tell
    end tell" 2>/dev/null
    
    echo "Launched: lane=$lane tool=$tool terminal=$terminal_name loop=${loop_id:-none}"
}

cmd_launch_direct() {
    # Fallback direct launch without spine_terminal_entry.sh
    local lane="$1"
    local loop_id="$2"
    local tool="$3"
    local terminal_name="$4"
    local role="$5"
    
    local cd_cmd="cd $SPINE_REPO"
    local lane_cmd="export SPINE_LANE=$lane SPINE_TERMINAL_NAME=$terminal_name"
    local ops_cmd="./bin/ops lane open $lane"
    
    local tool_cmd=""
    case "$tool" in
        opencode)
            tool_cmd="source ~/.config/infisical/credentials 2>/dev/null || true; opencode -m openai/glm-5 ."
            ;;
        codex)
            tool_cmd="codex -C . --add-dir $WORKBENCH_ROOT --dangerously-bypass-approvals-and-sandbox"
            ;;
        claude)
            tool_cmd="claude --dangerously-skip-permissions --add-dir $WORKBENCH_ROOT"
            ;;
        verify)
            tool_cmd="./bin/ops cap run verify.pack.run core-operator"
            ;;
    esac
    
    local full_cmd="$cd_cmd && $lane_cmd && $ops_cmd && $tool_cmd"
    
    osascript -e "tell application \"iTerm\"
        activate
        set newWindow to (create window with default profile)
        tell current session of newWindow
            write text \"$full_cmd\"
        end tell
    end tell" 2>/dev/null
    
    echo "Launched (direct): lane=$lane tool=$tool terminal=$terminal_name"
}

# ── JSON combined output for Raycast ────────────────────────────────────────

cmd_status_json() {
    # Combined status for launcher UI - shows lanes, loops, and current state
    python3 - "$LANE_PROFILES_YAML" "$SCOPES_DIR" <<'PYSTATUS'
import sys, os, json, re

contract_file = sys.argv[1]
scopes_dir = sys.argv[2]

# Get lanes
default_profiles = {
    "control":   {"desc": "Planning + governance writer", "mode": "read-write"},
    "execution": {"desc": "Domain repos writer", "mode": "read-write"},
    "audit":     {"desc": "Read-only evidence", "mode": "read-only"},
    "watcher":   {"desc": "Read-only checks", "mode": "read-only"},
}
profiles = default_profiles.copy()

if os.path.exists(contract_file):
    try:
        import yaml
        with open(contract_file) as f:
            doc = yaml.safe_load(f)
        for name, p in doc.get("profiles", {}).items():
            profiles[name] = {
                "desc": p.get("description", ""),
                "mode": p.get("mode", "read-only"),
            }
    except:
        pass

# Get loops
loops = []
if os.path.isdir(scopes_dir):
    for filename in sorted(os.listdir(scopes_dir), reverse=True):
        if not filename.endswith('.scope.md'):
            continue
        filepath = os.path.join(scopes_dir, filename)
        try:
            with open(filepath) as f:
                content = f.read()
            # Parse frontmatter
            fm = {}
            in_fm = False
            for line in content.split('\n'):
                if line.strip() == '---':
                    in_fm = not in_fm
                    continue
                if in_fm:
                    match = re.match(r'^(\w+):\s*(.*)$', line)
                    if match:
                        fm[match.group(1)] = match.group(2).strip().strip('"')
            
            if fm.get('status') in ('active', 'draft', 'open'):
                loops.append({
                    "id": fm.get('loop_id', filename.replace('.scope.md', '')),
                    "title": fm.get('loop_id', '').replace('LOOP-', '').replace('-', ' '),
                    "priority": fm.get('priority', 'medium'),
                    "scope": fm.get('scope', 'unknown'),
                })
        except:
            pass

result = {
    "lanes": [{"id": k, **v} for k, v in profiles.items()],
    "loops": loops[:20],  # Limit to 20 most recent
    "tools": [
        {"id": "opencode", "title": "OpenCode"},
        {"id": "codex", "title": "Codex"},
        {"id": "claude", "title": "Claude Code"},
        {"id": "verify", "title": "Verify"},
    ],
}

print(json.dumps(result, indent=2))
PYSTATUS
}

# ── Dispatch ───────────────────────────────────────────────────────────────

case "${1:-}" in
    list-lanes)   cmd_list_lanes ;;
    list-loops)   cmd_list_loops ;;
    list-tools)   cmd_list_tools ;;
    status)       cmd_status_json ;;
    launch)       shift; cmd_launch "$@" ;;
    -h|--help)    usage ;;
    "")           usage ;;
    *)            echo "Unknown subcommand: $1" >&2; usage; exit 1 ;;
esac
