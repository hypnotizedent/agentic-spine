#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops terminal - Canonical governed admission surface
# ═══════════════════════════════════════════════════════════════════════════
#
# The ONE public admitting surface for governed human terminal sessions.
# Opens an iTerm window with truthful runtime identity:
#   - SPINE_TERMINAL_ID     (canonical terminal identity)
#   - SPINE_EXECUTION_CLASS (canonical mutation policy class from contract)
#   - SPINE_LOOP_ID         (explicitly requested, or auto-attached when exactly
#                            one live loop exists)
#   - Claude launcher preserves legacy bypass-permissions behavior for
#     picker-launched interactive terminals
#
# Stale old-model env vars are explicitly unset so there is only one
# startup model.
#
# Usage:
#   ops terminal launch --tool <tool> [--terminal <name>] [--loop <id>]
#
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROLE_CONTRACT="$SPINE_ROOT/ops/bindings/terminal.role.contract.yaml"

# Resolve runtime paths canonically before any path usage
RUNTIME_PATHS_LIB="$SPINE_ROOT/ops/lib/runtime-paths.sh"
# shellcheck source=/dev/null
[[ -f "$RUNTIME_PATHS_LIB" ]] && . "$RUNTIME_PATHS_LIB" && spine_runtime_resolve_paths

POSTURE_HELPER="$SPINE_ROOT/ops/plugins/core/lifecycle/lib/session_posture.sh"
# shellcheck source=/dev/null
[[ -f "$POSTURE_HELPER" ]] && . "$POSTURE_HELPER"

usage() {
    cat <<'EOF'
ops terminal - Terminal launcher with runtime identity

Usage:
  ops terminal launch [options]    Open an iTerm window with a tool

Options:
  --role <solo|control|lane-worker>  Launch mode (solo disables implicit loop attach)
  --tool <tool>         Tool to run (claude|codex|opencode|verify)
  --terminal <name>     Terminal character name (sets SPINE_TERMINAL_ID)
  --loop <loop_id>      Explicitly attach a loop (otherwise one live loop auto-attaches)
  --session-posture <controller|membrane|worker|translator>  Explicit session posture (validated by node type)
  --dry-run             Print the command without opening iTerm

Runtime identity:
  SPINE_TERMINAL_ID   = canonical terminal identity (from --terminal)
  SPINE_EXECUTION_CLASS = canonical execution class (resolved from contract by terminal type)
  SPINE_LOOP_ID       = explicit loop, or auto-attached when exactly one live loop exists
  Legacy mirrors: OPS_TERMINAL_ID, OPS_TERMINAL_ROLE, SPINE_RUNTIME_ROLE
  SPINE_NODE_TYPE, SPINE_SESSION_POSTURE (resolved at birth from terminal type / explicit flag)

Examples:
  ops terminal launch --tool claude --terminal SPINE-CONTROL-01
  ops terminal launch --tool codex --terminal MINT-MORPHEUS-01 --loop LOOP-MINT-DAILY-20260408
  ops terminal launch --tool verify
EOF
}

fail() { echo "ops terminal: $*" >&2; exit 1; }

SUBCMD="${1:-}"
shift || true

case "$SUBCMD" in
    launch) ;;
    -h|--help|"") usage; exit 0 ;;
    *) fail "unknown subcommand '$SUBCMD' (expected: launch)" ;;
esac

# Parse launch options
TOOL=""
TERMINAL_NAME=""
LOOP_ID=""
SESSION_POSTURE=""
LAUNCH_MODE=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tool) TOOL="${2:-}"; shift 2 ;;
        --terminal) TERMINAL_NAME="${2:-}"; shift 2 ;;
        --loop) LOOP_ID="${2:-}"; shift 2 ;;
        --session-posture) SESSION_POSTURE="${2:-}"; shift 2 ;;
        --role) LAUNCH_MODE="${2:-}"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --) shift; break ;;
        *) shift ;;  # Accept and ignore unknown flags for forward compat
    esac
done

[[ -n "$TOOL" ]] || fail "missing required --tool (claude|codex|opencode|verify)"

resolve_launch_mode() {
    local raw="${1:-}"
    case "$raw" in
        ""|auto) echo "auto" ;;
        solo) echo "solo" ;;
        control|orchestrator) echo "control" ;;
        lane-worker|worker) echo "lane-worker" ;;
        *)
            fail "unknown --role '$raw' (expected: solo|control|lane-worker; compat: orchestrator|worker)"
            ;;
    esac
}

LAUNCH_MODE="$(resolve_launch_mode "$LAUNCH_MODE")"

# ── Resolve execution class from contract ─────────────────────────────────
# Reads terminal.role.contract.yaml to map terminal name → type → execution class.
# Falls back to "researcher" (read-only) if no terminal or contract missing.
resolve_runtime_role() {
    local terminal_name="${1:-}"
    local default_role="researcher"

    # No terminal name → ad hoc read-only
    [[ -n "$terminal_name" ]] || { echo "$default_role"; return; }

    # Contract missing → safe default
    [[ -f "$ROLE_CONTRACT" ]] || { echo "$default_role"; return; }
    command -v yq >/dev/null 2>&1 || { echo "$default_role"; return; }

    # Check by_terminal_id first (explicit override)
    local id_role
    id_role="$(yq e ".runtime_role_defaults.by_terminal_id.\"$terminal_name\" // \"\"" "$ROLE_CONTRACT" 2>/dev/null || true)"
    if [[ -n "$id_role" && "$id_role" != "null" ]]; then
        echo "$id_role"
        return
    fi

    # Look up terminal type from roles list
    local terminal_type
    terminal_type="$(yq e ".roles[] | select(.id == \"$terminal_name\") | .type" "$ROLE_CONTRACT" 2>/dev/null || true)"
    if [[ -z "$terminal_type" || "$terminal_type" == "null" ]]; then
        echo "$default_role"
        return
    fi

    # Map type → runtime role
    local type_role
    type_role="$(yq e ".runtime_role_defaults.by_terminal_type.\"$terminal_type\" // \"\"" "$ROLE_CONTRACT" 2>/dev/null || true)"
    if [[ -n "$type_role" && "$type_role" != "null" ]]; then
        echo "$type_role"
    else
        echo "$default_role"
    fi
}

resolve_terminal_type() {
    local terminal_name="${1:-}"
    [[ -n "$terminal_name" ]] || return 0
    [[ -f "$ROLE_CONTRACT" ]] || return 0
    command -v yq >/dev/null 2>&1 || return 0

    yq e ".roles[] | select(.id == \"$terminal_name\") | .type" "$ROLE_CONTRACT" 2>/dev/null || true
}

TERMINAL_TYPE="$(resolve_terminal_type "$TERMINAL_NAME")"
[[ -n "$TERMINAL_TYPE" && "$TERMINAL_TYPE" != "null" ]] || TERMINAL_TYPE=""
RUNTIME_ROLE="$(resolve_runtime_role "$TERMINAL_NAME")"

# ── Resolve session posture (node type + posture + source) ─────────��─────
# Pass execution class so posture derives from canonical execution identity.
# This prevents split-identity (e.g. worker role with controller posture).
if command -v session_posture_resolve >/dev/null 2>&1; then
    if ! session_posture_resolve "$TERMINAL_NAME" "$SESSION_POSTURE" "$RUNTIME_ROLE"; then
        fail "session posture resolution failed (see message above)"
    fi
fi

# ── Auto-resolve loop when none explicitly passed ────────────────────────
# Reuses entry-compile (existing truth) to find the active loop.
# Rules:
#   - Explicit --loop takes absolute precedence
#   - Exactly one active loop → auto-attach
#   - Zero active loops → keep empty (clean start)
#   - Multiple active loops → keep empty (ambiguous, do not guess)
#   - entry-compile failure → keep empty (degraded truth, no silent attach)
if [[ -z "$LOOP_ID" && "$LAUNCH_MODE" != "solo" ]]; then
    ENTRY_COMPILE_BIN="$SPINE_ROOT/ops/plugins/core/lifecycle/bin/entry-compile"
    _STATE_ROOT="$SPINE_STATE"
    if [[ -f "$ENTRY_COMPILE_BIN" && -d "$_STATE_ROOT/loop-scopes" ]]; then
        AUTO_LOOP="$(python3 "$ENTRY_COMPILE_BIN" --state-root "$_STATE_ROOT" 2>/dev/null \
            | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    cs = d.get('compilation_state', '')
    if cs in ('compiled', 'partial', 'loop_only'):
        lid = d.get('loop_id')
        if lid and lid != 'None':
            print(lid)
except Exception:
    pass
" 2>/dev/null)" || true
        if [[ -n "$AUTO_LOOP" ]]; then
            LOOP_ID="$AUTO_LOOP"
        fi
    fi
    unset _STATE_ROOT
fi

resolve_loop_workspace_for_repo() {
    local loop_id="${1:-}"
    local repo_root="${2:-}"
    local runtime_root="${SPINE_RUNTIME_ROOT:-}"
    [[ -n "$loop_id" && -n "$repo_root" && -n "$runtime_root" ]] || return 0

    python3 - "$runtime_root" "$loop_id" "$repo_root" <<'PY'
import json, os, pathlib, subprocess, sys

runtime_root = pathlib.Path(sys.argv[1])
loop_id = sys.argv[2]
repo_root = os.path.realpath(sys.argv[3])
waves_dir = runtime_root / "waves"
if not waves_dir.is_dir():
    sys.exit(0)

def git_common_dir(repo_path: str) -> str:
    try:
        proc = subprocess.run(
            ["git", "-C", repo_path, "rev-parse", "--git-common-dir"],
            check=True,
            capture_output=True,
            text=True,
        )
    except Exception:
        return ""
    value = proc.stdout.strip()
    if not value:
        return ""
    if not os.path.isabs(value):
        value = os.path.join(repo_path, value)
    return os.path.realpath(value)

repo_identity = git_common_dir(repo_root)
if not repo_identity:
    sys.exit(0)

candidates = []
for state_path in sorted(waves_dir.glob("WAVE-*/state.json")):
    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except Exception:
        continue
    if not isinstance(state, dict):
        continue
    status = str(state.get("status") or "").strip().lower()
    if status in {"", "closed", "superseded"}:
        continue
    packet = state.get("packet") if isinstance(state.get("packet"), dict) else {}
    workspace = state.get("workspace") if isinstance(state.get("workspace"), dict) else {}
    wave_loop_id = str(state.get("loop_id") or packet.get("loop_id") or "").strip()
    if wave_loop_id != loop_id:
        continue
    workspace_path = str(workspace.get("worktree") or "").strip()
    workspace_repo = str(workspace.get("repo") or "").strip()
    workspace_branch = str(workspace.get("branch") or "").strip()
    lifecycle_state = str(workspace.get("lifecycle_state") or "").strip().lower()
    if not workspace_path or lifecycle_state == "cleaned":
        continue
    if not workspace_repo:
        continue
    workspace_identity = git_common_dir(workspace_repo)
    if not workspace_identity or workspace_identity != repo_identity:
        continue
    if not os.path.isdir(workspace_path):
        continue
    candidates.append(
        {
            "wave_id": str(state.get("wave_id") or state_path.parent.name).strip(),
            "worktree": workspace_path,
            "branch": workspace_branch,
        }
    )

unique = {}
for candidate in candidates:
    unique[(candidate["wave_id"], candidate["worktree"], candidate["branch"])] = candidate
candidates = list(unique.values())

if len(candidates) == 1:
    candidate = candidates[0]
    print("ok")
    print(candidate["worktree"])
    print(candidate["wave_id"])
    print(candidate["branch"])
elif len(candidates) > 1:
    print("ambiguous")
    for candidate in candidates:
        print(f'{candidate["wave_id"]}|{candidate["worktree"]}|{candidate["branch"]}')
else:
    print("missing")
PY
}

LAUNCH_CWD="$SPINE_ROOT"
LAUNCH_WAVE_ID=""
LAUNCH_BRANCH=""
if [[ "$TOOL" != "verify" && -n "$LOOP_ID" ]]; then
    mapfile -t _WORKTREE_RESOLUTION < <(resolve_loop_workspace_for_repo "$LOOP_ID" "$SPINE_ROOT" || true)
    _resolution_status="${_WORKTREE_RESOLUTION[0]:-}"
    case "$_resolution_status" in
        ok)
            LAUNCH_CWD="${_WORKTREE_RESOLUTION[1]:-$SPINE_ROOT}"
            LAUNCH_WAVE_ID="${_WORKTREE_RESOLUTION[2]:-}"
            LAUNCH_BRANCH="${_WORKTREE_RESOLUTION[3]:-}"
            ;;
        ambiguous)
            fail "loop '$LOOP_ID' has multiple active governed worktrees for this repo; launch from the intended wave worktree explicitly"
            ;;
        missing)
            fail "loop '$LOOP_ID' has no active governed worktree for this repo; start or rehydrate a wave worktree before launching a mutating terminal"
            ;;
        *)
            ;;
    esac
fi

# ── Build the in-terminal command ────────────────────────────────────────
build_entry_cmd() {
    local tool="$1"
    local terminal_name="${2:-}"
    local execution_class="${3:-researcher}"
    local loop_id="${4:-}"
    local posture_exports="${5:-}"
    local launch_cwd="${6:-$SPINE_ROOT}"
    local launch_wave_id="${7:-}"
    local launch_branch="${8:-}"
    local parts=()

    parts+=("cd $(printf '%q' "$launch_cwd")")

    # Unset stale old-model env and inherited loop identity so birth state is explicit.
    parts+=("unset SPINE_ENTRY_PACKET_PATH SPINE_ENTRY_PACKET_HASH SPINE_POLICY_PRESET SPINE_TERMINAL_NAME SPINE_LOOP_ID OPS_WORKTREE_IDENTITY 2>/dev/null; true")

    # Set terminal birth identity and compatibility aliases.
    if [[ -n "$terminal_name" ]]; then
        parts+=("export SPINE_TERMINAL_ID=$(printf '%q' "$terminal_name")")
        parts+=("export OPS_TERMINAL_ID=$(printf '%q' "$terminal_name")")
        parts+=("export OPS_TERMINAL_ROLE=$(printf '%q' "$terminal_name")")
        parts+=("export SPINE_TERMINAL_NAME=$(printf '%q' "$terminal_name")")
        parts+=("export SPINE_HEARTBEAT_FILE=$(printf '%q' "$SPINE_STATE/terminal-heartbeats/${terminal_name}.yaml")")
    fi
    if [[ -n "$TERMINAL_TYPE" ]]; then
        parts+=("export SPINE_TERMINAL_TYPE=$(printf '%q' "$TERMINAL_TYPE")")
    fi
    parts+=("export SPINE_EXECUTION_CLASS=$(printf '%q' "$execution_class")")
    parts+=("export SPINE_RUNTIME_ROLE=$(printf '%q' "$execution_class")")

    # Session posture exports (one export line per part, verbatim)
    if [[ -n "$posture_exports" ]]; then
        local line
        while IFS= read -r line; do
            [[ -n "$line" ]] || continue
            parts+=("$line")
        done <<POSTURE_EOF
$posture_exports
POSTURE_EOF
    fi

    # Attach the resolved loop identity, whether explicit or auto-resolved.
    if [[ -n "$loop_id" ]]; then
        parts+=("export SPINE_LOOP_ID=$(printf '%q' "$loop_id")")
        parts+=("export OPS_WORKTREE_IDENTITY=$(printf '%q' "$loop_id")")
        parts+=("export SPINE_LOOP_HEARTBEAT_FILE=$(printf '%q' "$SPINE_STATE/loop-heartbeats/${loop_id}.yaml")")
    fi
    if [[ -n "$launch_wave_id" ]]; then
        parts+=("export SPINE_ACTIVE_WAVE_ID=$(printf '%q' "$launch_wave_id")")
    fi
    if [[ -n "$launch_branch" ]]; then
        parts+=("export SPINE_TARGET_BRANCH=$(printf '%q' "$launch_branch")")
    fi
    if [[ "$launch_cwd" != "$SPINE_ROOT" ]]; then
        parts+=("export SPINE_WORKTREE=$(printf '%q' "$launch_cwd")")
    fi

    # Public session entry at terminal birth (best-effort, never blocks).
    # Expert attach remains available through:
    #   ./bin/ops cap run session.v3.attach -- --expert
    parts+=("{ $(printf '%q' "$SPINE_ROOT/ops/plugins/core/lifecycle/bin/session-v3-attach") --public || true; }")

    case "$tool" in
        claude)  parts+=("claude --dangerously-skip-permissions") ;;
        codex)   parts+=("codex --dangerously-bypass-approvals-and-sandbox") ;;
        opencode) parts+=("opencode") ;;
        verify)  parts+=("./bin/ops cap run spine.verify") ;;
        *)       fail "unknown tool '$tool' (expected: claude|codex|opencode|verify)" ;;
    esac

    local result="${parts[0]}"
    local i
    for (( i=1; i<${#parts[@]}; i++ )); do
        result="$result && ${parts[$i]}"
    done
    echo "$result"
}

POSTURE_EXPORTS=""
if command -v session_posture_emit_env >/dev/null 2>&1; then
    POSTURE_EXPORTS="$(session_posture_emit_env)"
fi

ENTRY_CMD="$(build_entry_cmd "$TOOL" "$TERMINAL_NAME" "$RUNTIME_ROLE" "$LOOP_ID" "$POSTURE_EXPORTS" "$LAUNCH_CWD" "$LAUNCH_WAVE_ID" "$LAUNCH_BRANCH")"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "# Terminal: ${TERMINAL_NAME:-ad-hoc}"
    echo "# Execution class: $RUNTIME_ROLE"
    echo "# Launch mode: $LAUNCH_MODE"
    echo "# Node type: ${__SP_NODE_TYPE:-unknown}"
    echo "# Session posture: ${__SP_POSTURE:-unknown} (source: ${__SP_SOURCE:-unknown})"
    [[ -z "$LOOP_ID" ]] || echo "# Loop: $LOOP_ID"
    echo "# Launch cwd: $LAUNCH_CWD"
    [[ -z "$LAUNCH_WAVE_ID" ]] || echo "# Launch wave: $LAUNCH_WAVE_ID"
    [[ -z "$LAUNCH_BRANCH" ]] || echo "# Launch branch: $LAUNCH_BRANCH"
    echo "$ENTRY_CMD"
    exit 0
fi

write_entry_script() {
    local entry_cmd="$1"
    local launch_script
    launch_script="$(mktemp -t spine-terminal-entry.XXXXXX.sh)"
    chmod 700 "$launch_script"

    # iTerm AppleScript can clip long inline commands; hand off via temp script.
    {
        printf '#!/usr/bin/env bash\n'
        printf 'set -euo pipefail\n'
        printf 'rm -f -- %q\n' "$launch_script"
        printf '%s\n' "$entry_cmd"
    } >"$launch_script"

    printf '%s\n' "$launch_script"
}

LAUNCH_SCRIPT="$(write_entry_script "$ENTRY_CMD")"
EXEC_CMD="/bin/bash $(printf '%q' "$LAUNCH_SCRIPT")"

# Build iTerm title
TITLE=""
if [[ -n "$TERMINAL_NAME" ]]; then
    TITLE="$TERMINAL_NAME"
    [[ -n "$TOOL" ]] && TITLE="$TITLE — $TOOL"
    TITLE="$TITLE [$RUNTIME_ROLE]"
else
    TITLE="spine — $TOOL [ad-hoc]"
fi

# Open iTerm window via AppleScript
ESCAPED_CMD="${EXEC_CMD//\\/\\\\}"
ESCAPED_CMD="${ESCAPED_CMD//\"/\\\"}"
ESCAPED_TITLE="${TITLE//\\/\\\\}"
ESCAPED_TITLE="${ESCAPED_TITLE//\"/\\\"}"

osascript <<APPLESCRIPT
tell application "iTerm"
    activate
    set newWindow to (create window with default profile)
    tell current session of newWindow
        set name to "$ESCAPED_TITLE"
        write text "$ESCAPED_CMD"
    end tell
end tell
APPLESCRIPT
