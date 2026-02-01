#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# agent-enqueue.sh - Enqueue a prompt into the agent dispatch pipeline
# ═══════════════════════════════════════════════════════════════════════════
#
# Usage:
#   echo "Your prompt here" | agent-enqueue.sh [slug] [run-id]
#   cat prompt.txt | agent-enqueue.sh gap-scan R002
#   agent-enqueue.sh verify R003 <<< "Verify the login flow works"
#
# Environment:
#   SESSION_ID   If set, prefixes filename (else generates timestamp-based)
#
# Output:
#   Creates: $SPINE/mailroom/inbox/queued/<session>__<slug>__R<id>.md
#   Prints: path to created file
#
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────
SPINE="${SPINE_REPO:-$HOME/Code/agentic-spine}"
QUEUED="${SPINE_INBOX:-$SPINE/mailroom/inbox}/queued"
SESSION="${SESSION_ID:-S$(date +%Y%m%d-%H%M%S)}"
SLUG="${1:-task}"
RID="${2:-R$(printf '%03d' $((RANDOM % 1000)))}"

# ─────────────────────────────────────────────────────────────────────────────
# Validate
# ─────────────────────────────────────────────────────────────────────────────
mkdir -p "$QUEUED"

# Sanitize slug (alphanumeric, dash, underscore only)
SLUG_CLEAN="$(echo "$SLUG" | tr -cd 'a-zA-Z0-9_-')"
[[ -z "$SLUG_CLEAN" ]] && SLUG_CLEAN="task"

# ─────────────────────────────────────────────────────────────────────────────
# Build filename
# ─────────────────────────────────────────────────────────────────────────────
FILENAME="${SESSION}__${SLUG_CLEAN}__${RID}.md"
FILEPATH="${QUEUED}/${FILENAME}"

# ─────────────────────────────────────────────────────────────────────────────
# Read prompt from stdin and write
# ─────────────────────────────────────────────────────────────────────────────
if [[ -t 0 ]]; then
    echo "ERROR: No input provided. Pipe or redirect prompt content to this script."
    echo ""
    echo "Usage:"
    echo "  echo 'Your prompt' | $0 [slug] [run-id]"
    echo "  cat prompt.txt | $0 gap-scan R002"
    echo ""
    echo "Environment:"
    echo "  SESSION_ID - prefix for file grouping (default: timestamp)"
    exit 1
fi

cat > "$FILEPATH"

# ─────────────────────────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────────────────────────
echo "ENQUEUED: $FILEPATH"
echo "  Session: $SESSION"
echo "  Slug:    $SLUG_CLEAN"
echo "  Run ID:  $RID"
