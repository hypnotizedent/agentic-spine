#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops terminal - Terminal birth with runtime identity
# ═══════════════════════════════════════════════════════════════════════════
#
# Canonical launcher for the Hammerspoon Ctrl+Shift+P picker.
# Opens an iTerm window with truthful runtime identity:
#   - OPS_TERMINAL_ROLE     (terminal character name)
#   - SPINE_RUNTIME_ROLE    (mutation policy role from contract)
#   - SPINE_LOOP_ID         (only if explicitly requested)
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

POSTURE_HELPER="$SPINE_ROOT/ops/plugins/core/lifecycle/lib/session_posture.sh"
# shellcheck source=/dev/null
[[ -f "$POSTURE_HELPER" ]] && . "$POSTURE_HELPER"

usage() {
    cat <<'EOF'
ops terminal - Terminal launcher with runtime identity

Usage:
  ops terminal launch [options]    Open an iTerm window with a tool

Options:
  --tool <tool>         Tool to run (claude|codex|opencode|verify)
  --terminal <name>     Terminal character name (sets OPS_TERMINAL_ROLE)
  --loop <loop_id>      Explicitly attach a loop (sets SPINE_LOOP_ID)
  --session-posture <controller|membrane|worker|translator>  Explicit session posture (validated by node type)
  --dry-run             Print the command without opening iTerm

Runtime identity:
  OPS_TERMINAL_ROLE   = terminal character name (from --terminal)
  SPINE_RUNTIME_ROLE  = mutation policy role (resolved from contract by terminal type)
  SPINE_LOOP_ID       = active loop (only when --loop is passed)
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
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tool) TOOL="${2:-}"; shift 2 ;;
        --terminal) TERMINAL_NAME="${2:-}"; shift 2 ;;
        --loop) LOOP_ID="${2:-}"; shift 2 ;;
        --session-posture) SESSION_POSTURE="${2:-}"; shift 2 ;;
        --role) shift 2 ;;  # Accepted for compat, ignored (role comes from contract)
        --dry-run) DRY_RUN=1; shift ;;
        --) shift; break ;;
        *) shift ;;  # Accept and ignore unknown flags for forward compat
    esac
done

[[ -n "$TOOL" ]] || fail "missing required --tool (claude|codex|opencode|verify)"

# ── Resolve runtime role from contract ───────────────────────────────────
# Reads terminal.role.contract.yaml to map terminal name → type → runtime role.
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

RUNTIME_ROLE="$(resolve_runtime_role "$TERMINAL_NAME")"

# ── Resolve session posture (node type + posture + source) ───────────────
if command -v session_posture_resolve >/dev/null 2>&1; then
    if ! session_posture_resolve "$TERMINAL_NAME" "$SESSION_POSTURE"; then
        fail "session posture resolution failed (see message above)"
    fi
fi

# ── Build the in-terminal command ────────────────────────────────────────
build_entry_cmd() {
    local tool="$1"
    local terminal_name="${2:-}"
    local runtime_role="${3:-researcher}"
    local loop_id="${4:-}"
    local posture_exports="${5:-}"
    local spine="$SPINE_ROOT"
    local parts=()

    parts+=("cd $(printf '%q' "$spine")")

    # Unset stale old-model env so there is only one startup model
    parts+=("unset SPINE_ENTRY_PACKET_PATH SPINE_ENTRY_PACKET_HASH SPINE_POLICY_PRESET SPINE_TERMINAL_NAME 2>/dev/null; true")

    # Set terminal birth identity
    if [[ -n "$terminal_name" ]]; then
        parts+=("export OPS_TERMINAL_ROLE=$(printf '%q' "$terminal_name")")
    fi
    parts+=("export SPINE_RUNTIME_ROLE=$(printf '%q' "$runtime_role")")

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

    # Explicit loop attachment only
    if [[ -n "$loop_id" ]]; then
        parts+=("export SPINE_LOOP_ID=$(printf '%q' "$loop_id")")
        parts+=("export OPS_WORKTREE_IDENTITY=$(printf '%q' "$loop_id")")
    fi

    # Session attach at terminal birth (best-effort, never blocks)
    parts+=("{ ./bin/ops cap run session.v3.attach || true; }")

    case "$tool" in
        claude)  parts+=("claude --dangerously-skip-permissions") ;;
        codex)   parts+=("codex --dangerously-bypass-approvals-and-sandbox") ;;
        opencode) parts+=("opencode") ;;
        verify)  parts+=("./bin/ops cap run verify.run -- fast") ;;
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

ENTRY_CMD="$(build_entry_cmd "$TOOL" "$TERMINAL_NAME" "$RUNTIME_ROLE" "$LOOP_ID" "$POSTURE_EXPORTS")"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "# Terminal: ${TERMINAL_NAME:-ad-hoc}"
    echo "# Runtime role: $RUNTIME_ROLE"
    echo "# Node type: ${__SP_NODE_TYPE:-unknown}"
    echo "# Session posture: ${__SP_POSTURE:-unknown} (source: ${__SP_SOURCE:-unknown})"
    [[ -z "$LOOP_ID" ]] || echo "# Loop: $LOOP_ID"
    echo "$ENTRY_CMD"
    exit 0
fi

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
ESCAPED_CMD="${ENTRY_CMD//\\/\\\\}"
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
