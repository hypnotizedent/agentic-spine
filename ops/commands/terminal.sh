#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops terminal - Minimal terminal launcher shim
# ═══════════════════════════════════════════════════════════════════════════
#
# Compatibility shim for the Hammerspoon Ctrl+Shift+P picker.
# Opens an iTerm window with the lean CLI entry path for the selected tool.
#
# The old heavyweight launcher ceremony (session.v3.attach, orchestration
# worktree lifecycle, heartbeat wiring) is retired. This shim exists only
# so the external Hammerspoon picker has a governed script target.
#
# Usage:
#   ops terminal launch --tool <tool> [--terminal <name>] [--role <mode>]
#
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

usage() {
    cat <<'EOF'
ops terminal - Terminal launcher

Usage:
  ops terminal launch [options]    Open an iTerm window with a tool

Options:
  --tool <tool>         Tool to run (claude|codex|opencode|verify)
  --terminal <name>     Terminal character name (informational)
  --role <mode>         Launch role mode (accepted, not enforced)
  --dry-run             Print the command without opening iTerm

Examples:
  ops terminal launch --tool claude --terminal SPINE-CONTROL-01
  ops terminal launch --tool codex
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
ROLE=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tool) TOOL="${2:-}"; shift 2 ;;
        --terminal) TERMINAL_NAME="${2:-}"; shift 2 ;;
        --role) ROLE="${2:-}"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --) shift; break ;;
        *) shift ;;  # Accept and ignore unknown flags for forward compat
    esac
done

[[ -n "$TOOL" ]] || fail "missing required --tool (claude|codex|opencode|verify)"

# Build the in-terminal command
build_entry_cmd() {
    local tool="$1"
    local terminal_name="${2:-}"
    local spine="$SPINE_ROOT"
    local parts=()

    parts+=("cd $(printf '%q' "$spine")")

    # Export terminal identity if provided (lean entry uses this for context)
    if [[ -n "$terminal_name" ]]; then
        parts+=("export OPS_TERMINAL_ROLE=$(printf '%q' "$terminal_name")")
    fi

    case "$tool" in
        claude)
            parts+=("claude")
            ;;
        codex)
            parts+=("codex")
            ;;
        opencode)
            parts+=("opencode")
            ;;
        verify)
            parts+=("./bin/ops cap run verify.run -- fast")
            ;;
        *)
            fail "unknown tool '$tool' (expected: claude|codex|opencode|verify)"
            ;;
    esac

    local result="${parts[0]}"
    local i
    for (( i=1; i<${#parts[@]}; i++ )); do
        result="$result && ${parts[$i]}"
    done
    echo "$result"
}

ENTRY_CMD="$(build_entry_cmd "$TOOL" "$TERMINAL_NAME")"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "$ENTRY_CMD"
    exit 0
fi

# Build iTerm title
TITLE=""
if [[ -n "$TERMINAL_NAME" ]]; then
    TITLE="$TERMINAL_NAME"
    [[ -n "$TOOL" ]] && TITLE="$TITLE — $TOOL"
else
    TITLE="spine — $TOOL"
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
