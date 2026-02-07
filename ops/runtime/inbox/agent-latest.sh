#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# agent-latest.sh - View the latest result from agent outbox
# ═══════════════════════════════════════════════════════════════════════════
#
# Usage:
#   agent-latest.sh           # Print path + tail of latest result
#   agent-latest.sh --open    # Open latest result in default editor
#   agent-latest.sh --full    # Print entire file (not truncated)
#   agent-latest.sh --path    # Print only the path (for scripting)
#
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

SPINE="${SPINE_REPO:-$HOME/code/agentic-spine}"
OUTBOX="${SPINE_OUTBOX:-$SPINE/mailroom/outbox}"
LINES="${AGENT_LATEST_LINES:-80}"

# ─────────────────────────────────────────────────────────────────────────────
# Find latest result
# ─────────────────────────────────────────────────────────────────────────────
latest="$(ls -1t "${OUTBOX}"/*_RESULT.md 2>/dev/null | head -1 || true)"

if [[ -z "$latest" ]]; then
    echo "No results in $OUTBOX"
    exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Handle flags
# ─────────────────────────────────────────────────────────────────────────────
case "${1:-}" in
    --open)
        "${EDITOR:-open}" "$latest"
        exit 0
        ;;
    --full)
        cat "$latest"
        exit 0
        ;;
    --path)
        echo "$latest"
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [--open|--full|--path|--help]"
        echo ""
        echo "  (no args)  Print path + last $LINES lines"
        echo "  --open     Open in \$EDITOR (default: open)"
        echo "  --full     Print entire file"
        echo "  --path     Print only path (for scripting)"
        echo ""
        echo "Environment:"
        echo "  AGENT_OUTBOX        Override outbox path (default: \$SPINE/mailroom/outbox)"
        echo "  AGENT_LATEST_LINES  Lines to show (default: 80)"
        exit 0
        ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
# Default: show info + tail
# ─────────────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  LATEST RESULT"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  File: $(basename "$latest")"
echo "  Path: $latest"
echo "  Time: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$latest" 2>/dev/null || stat -c '%y' "$latest" 2>/dev/null | cut -d. -f1)"
echo "  Size: $(wc -l < "$latest" | tr -d ' ') lines"
echo ""
echo "───────────────────────────────────────────────────────────────"
echo ""
tail -n "$LINES" "$latest"
