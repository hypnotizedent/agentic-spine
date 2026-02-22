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
#   ops terminal-launch list-roles              List terminal roles (JSON, from generated view)
#   ops terminal-launch --check-source          Validate launcher view source (no launch)
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
LAUNCHER_VIEW_YAML="$SPINE_REPO/ops/bindings/terminal.launcher.view.yaml"

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

# ── View helpers ──────────────────────────────────────────────────────────

warn() {
    echo "WARNING: $*" >&2
}

_view_file_exists() {
    [[ -f "$LAUNCHER_VIEW_YAML" && -r "$LAUNCHER_VIEW_YAML" ]]
}

_check_source_impl() {
    if ! _view_file_exists; then
        echo "launcher view missing or unreadable: $LAUNCHER_VIEW_YAML" >&2
        return 1
    fi

    if ! command -v yq >/dev/null 2>&1; then
        echo "missing dependency: yq" >&2
        return 1
    fi

    if ! yq e '.terminals' "$LAUNCHER_VIEW_YAML" >/dev/null 2>&1; then
        echo "launcher view parse error: $LAUNCHER_VIEW_YAML" >&2
        return 1
    fi

    local terminals_tag
    terminals_tag="$(yq e '.terminals | tag' "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
    if [[ "$terminals_tag" != "!!map" ]]; then
        echo "launcher view schema error: .terminals must be a map" >&2
        return 1
    fi

    local id required terminal_id field_value label_value description_value sort_value lane_value
    while IFS= read -r id; do
        [[ -n "$id" ]] || continue

        terminal_id="$(yq e ".terminals.\"${id}\".terminal_id // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
        if [[ -z "$terminal_id" ]]; then
            echo "launcher view schema error: terminals.$id.terminal_id is required" >&2
            return 1
        fi
        if [[ "$terminal_id" != "$id" ]]; then
            echo "launcher view schema error: terminals.$id.terminal_id must equal key ($id)" >&2
            return 1
        fi

        label_value="$(yq e ".terminals.\"${id}\".label // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
        description_value="$(yq e ".terminals.\"${id}\".description // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
        if [[ -z "$label_value" && -z "$description_value" ]]; then
            echo "launcher view schema error: terminals.$id requires label or description" >&2
            return 1
        fi

        for required in default_tool status picker_group sort_order lane_profile; do
            field_value="$(yq e ".terminals.\"${id}\".${required} // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
            if [[ -z "$field_value" ]]; then
                echo "launcher view schema error: terminals.$id.$required is required" >&2
                return 1
            fi
        done

        sort_value="$(yq e ".terminals.\"${id}\".sort_order // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
        if ! [[ "$sort_value" =~ ^[0-9]+$ ]]; then
            echo "launcher view schema error: terminals.$id.sort_order must be numeric" >&2
            return 1
        fi

        lane_value="$(yq e ".terminals.\"${id}\".lane_profile // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
        case "$lane_value" in
            control|execution|audit|watcher) ;;
            *)
                echo "launcher view schema error: terminals.$id.lane_profile invalid ($lane_value)" >&2
                return 1
                ;;
        esac
    done < <(yq e '.terminals | keys | .[]' "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)

    return 0
}

cmd_check_source() {
    if _check_source_impl; then
        local terminal_count
        terminal_count="$(yq e '.terminals | keys | length' "$LAUNCHER_VIEW_YAML" 2>/dev/null || echo "0")"
        echo "launcher source check PASS: terminals=${terminal_count}"
        return 0
    fi
    echo "launcher source check FAIL" >&2
    return 1
}

_resolve_from_view() {
    local terminal_id="$1"
    _view_file_exists || return 1
    command -v yq >/dev/null 2>&1 || return 1

    local entry
    entry="$(yq e ".terminals.\"${terminal_id}\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
    [[ "$entry" != "null" && -n "$entry" ]] || return 1

    local mapped_terminal_id label description default_tool status picker_group sort_order lane_profile
    mapped_terminal_id="$(yq e ".terminals.\"${terminal_id}\".terminal_id // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
    label="$(yq e ".terminals.\"${terminal_id}\".label // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
    description="$(yq e ".terminals.\"${terminal_id}\".description // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
    default_tool="$(yq e ".terminals.\"${terminal_id}\".default_tool // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
    status="$(yq e ".terminals.\"${terminal_id}\".status // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
    picker_group="$(yq e ".terminals.\"${terminal_id}\".picker_group // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
    sort_order="$(yq e ".terminals.\"${terminal_id}\".sort_order // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"
    lane_profile="$(yq e ".terminals.\"${terminal_id}\".lane_profile // \"\"" "$LAUNCHER_VIEW_YAML" 2>/dev/null || true)"

    if [[ -z "$mapped_terminal_id" || "$mapped_terminal_id" != "$terminal_id" ]]; then
        return 2
    fi
    if [[ -z "$label" && -z "$description" ]]; then
        return 2
    fi
    if [[ -z "$default_tool" || -z "$status" || -z "$picker_group" || -z "$sort_order" || -z "$lane_profile" ]]; then
        return 2
    fi
    if ! [[ "$sort_order" =~ ^[0-9]+$ ]]; then
        return 2
    fi

    # Deterministic launcher mapping from generated view.
    cat <<EOF
terminal_id=$mapped_terminal_id
terminal_role_binding=$mapped_terminal_id
label=$label
description=$description
default_tool=$default_tool
status=$status
picker_group=$picker_group
sort_order=$sort_order
lane_profile=$lane_profile
EOF
}

# ── Subcommands ────────────────────────────────────────────────────────────

usage() {
    cat <<'EOF'
ops terminal-launch - Lane-aware terminal app launcher

Usage:
  ops terminal-launch list-lanes              List available lane profiles (JSON)
  ops terminal-launch list-loops              List open loops (JSON)
  ops terminal-launch list-roles              List terminal roles (JSON, from generated view)
  ops terminal-launch --check-source          Validate launcher view source (no launch)
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

cmd_list_roles() {
    if ! _view_file_exists; then
        echo "[]"
        return
    fi
    if ! _check_source_impl >/dev/null 2>&1; then
        echo "[]"
        return
    fi
    yq e -o=json '.terminals | to_entries | [.[] | {
        "id": .key,
        "terminal_id": .value.terminal_id,
        "terminal_role_binding": .value.terminal_id,
        "label": .value.label,
        "description": .value.description,
        "status": .value.status,
        "default_tool": .value.default_tool,
        "picker_group": .value.picker_group,
        "sort_order": .value.sort_order,
        "domain": .value.domain,
        "lane_profile": .value.lane_profile
    }] | sort_by(.sort_order, .terminal_id)' "$LAUNCHER_VIEW_YAML" 2>/dev/null || echo "[]"
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
    local tool=""
    local terminal_name=""
    local role="solo"
    local lane_explicit=0
    local tool_explicit=0
    local terminal_explicit=0
    local terminal_binding=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lane) lane="${2:-}"; lane_explicit=1; shift 2 ;;
            --loop) loop_id="${2:-}"; shift 2 ;;
            --tool) tool="${2:-}"; tool_explicit=1; shift 2 ;;
            --terminal) terminal_name="${2:-}"; terminal_explicit=1; shift 2 ;;
            --role) role="${2:-}"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    # ── View-first defaults (explicit flags always win) ──────────────────
    if [[ -n "$terminal_name" ]]; then
        local _view_output _key _val
        if _view_output="$(_resolve_from_view "$terminal_name" 2>/dev/null)"; then
            while IFS='=' read -r _key _val; do
                case "$_key" in
                    terminal_role_binding) terminal_binding="$_val" ;;
                    lane_profile)  [[ $lane_explicit -eq 0 && -n "$_val" ]] && lane="$_val" ;;
                    default_tool)  [[ $tool_explicit -eq 0 && -n "$_val" ]] && tool="$_val" ;;
                esac
            done <<< "$_view_output"
            [[ -n "$terminal_binding" ]] && terminal_name="$terminal_binding"
        else
            case "$?" in
                1) warn "launcher view unavailable or terminal '${terminal_name}' not found; using legacy launch resolution" ;;
                2) warn "launcher view entry for '${terminal_name}' invalid; using legacy launch resolution" ;;
                *) warn "launcher view lookup failed for '${terminal_name}'; using legacy launch resolution" ;;
            esac
        fi
    fi

    # Apply hardcoded default only if still empty after view lookup
    [[ -z "$tool" ]] && tool="opencode"

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

    if [[ "${TERMINAL_LAUNCH_DRY_RUN:-0}" == "1" ]]; then
        echo "DRY_RUN: lane=$lane tool=$tool terminal=$terminal_name loop=${loop_id:-none} role=$role"
        return
    fi

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
            tool_cmd="./bin/ops cap run verify.core.run"
            ;;
    esac
    
    local full_cmd="$cd_cmd && $lane_cmd && $ops_cmd && $tool_cmd"

    if [[ "${TERMINAL_LAUNCH_DRY_RUN:-0}" == "1" ]]; then
        echo "DRY_RUN: lane=$lane tool=$tool terminal=$terminal_name loop=${loop_id:-none} role=$role"
        return
    fi

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
    --check-source) cmd_check_source ;;
    check-source) cmd_check_source ;;
    list-lanes)   cmd_list_lanes ;;
    list-loops)   cmd_list_loops ;;
    list-roles)   cmd_list_roles ;;
    list-tools)   cmd_list_tools ;;
    status)       cmd_status_json ;;
    launch)       shift; cmd_launch "$@" ;;
    -h|--help)    usage ;;
    "")           usage ;;
    *)            echo "Unknown subcommand: $1" >&2; usage; exit 1 ;;
esac
