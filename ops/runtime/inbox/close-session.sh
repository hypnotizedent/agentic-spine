#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# close-session.sh - Generate session closeout packet
# ═══════════════════════════════════════════════════════════════
#
# Usage: close-session.sh
#
# Called by: Hammerspoon Ctrl+9
#
# Produces:
#   - Closeout packet to stdout
#   - Writes to receipts/sessions/SESSION_CLOSEOUT_<timestamp>.md
#   - Optionally appends learnings to docs/brain/memory.md
#
# Auto-captures:
#   - SESSION_ID
#   - git status
#   - last 5 commits
#   - agent pipeline counts
#
# Prompts for:
#   - Next action (required)
#   - Learnings (optional)
#
# ═══════════════════════════════════════════════════════════════

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '5,22p' "$0" | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

set -eo pipefail

REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
RECEIPTS_DIR="$REPO/receipts/sessions"
MEMORY_FILE="$REPO/docs/brain/memory.md"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)

INBOX="${SPINE_INBOX:-$REPO/mailroom/inbox}"

cd "$REPO"
mkdir -p "$RECEIPTS_DIR"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  SESSION CLOSEOUT                                         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────────────────────────
# Auto-capture: SESSION_ID
# ─────────────────────────────────────────────────────────────────
if [[ -z "${SESSION_ID:-}" ]]; then
  SESSION_ID="(not set)"
  echo "  Warning: SESSION_ID not set. Run Ctrl+7 first next time."
  echo ""
fi

# ─────────────────────────────────────────────────────────────────
# Auto-capture: git status
# ─────────────────────────────────────────────────────────────────
GIT_STATUS=$(git status --porcelain 2>/dev/null | head -10)
if [[ -z "$GIT_STATUS" ]]; then
  GIT_STATUS="(clean)"
fi
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

# ─────────────────────────────────────────────────────────────────
# Auto-capture: last 5 commits
# ─────────────────────────────────────────────────────────────────
RECENT_COMMITS=$(git log -n 5 --oneline 2>/dev/null || echo "(none)")

# ─────────────────────────────────────────────────────────────────
# Auto-capture: agent pipeline counts
# ─────────────────────────────────────────────────────────────────
QUEUED_COUNT=$(find "$INBOX/queued" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
RUNNING_COUNT=$(find "$INBOX/running" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
DONE_COUNT=$(find "$INBOX/done" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
FAILED_COUNT=$(find "$INBOX/failed" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
PARKED_COUNT=$(find "$INBOX/parked" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')

# ─────────────────────────────────────────────────────────────────
# Prompt: Next action (required)
# ─────────────────────────────────────────────────────────────────
echo "What's the next action? (required, one line)"
read -p "NEXT: " NEXT_ACTION

if [[ -z "$NEXT_ACTION" ]]; then
  NEXT_ACTION="(not specified)"
fi

# ─────────────────────────────────────────────────────────────────
# Prompt: Learnings (optional)
# ─────────────────────────────────────────────────────────────────
echo ""
echo "What did you learn? (optional, Enter to skip)"
read -p "LEARNED: " LEARNED

echo ""
echo "What didn't work? (optional, Enter to skip)"
read -p "MISTAKE: " MISTAKE

# ─────────────────────────────────────────────────────────────────
# Build closeout packet
# ─────────────────────────────────────────────────────────────────
CLOSEOUT_FILE="$RECEIPTS_DIR/SESSION_CLOSEOUT_${TIMESTAMP}.md"

cat > "$CLOSEOUT_FILE" <<EOF
# Session Closeout

| Field | Value |
|-------|-------|
| Session ID | \`${SESSION_ID}\` |
| Date | ${DATE} |
| Time | ${TIME} |
| Branch | \`${GIT_BRANCH}\` |

## Pipeline Status

| Queue | Count |
|-------|-------|
| Queued | ${QUEUED_COUNT} |
| Running | ${RUNNING_COUNT} |
| Done | ${DONE_COUNT} |
| Failed | ${FAILED_COUNT} |
| Parked | ${PARKED_COUNT} |

## Git Status

\`\`\`
${GIT_STATUS}
\`\`\`

## Recent Commits

\`\`\`
${RECENT_COMMITS}
\`\`\`

## Next Action

${NEXT_ACTION}
EOF

# Add learnings if provided
if [[ -n "$LEARNED" ]] || [[ -n "$MISTAKE" ]]; then
  cat >> "$CLOSEOUT_FILE" <<EOF

## Learnings

EOF
  [[ -n "$LEARNED" ]] && echo "- **Learned:** ${LEARNED}" >> "$CLOSEOUT_FILE"
  [[ -n "$MISTAKE" ]] && echo "- **Mistake:** ${MISTAKE}" >> "$CLOSEOUT_FILE"
fi

# ─────────────────────────────────────────────────────────────────
# Append learnings to memory (if any)
# ─────────────────────────────────────────────────────────────────
if [[ -n "$LEARNED" ]]; then
  MEMORY_ENTRY="
## $DATE Session (${SESSION_ID})
- LEARNED: $LEARNED"
  [[ -n "$MISTAKE" ]] && MEMORY_ENTRY="$MEMORY_ENTRY
- MISTAKE: $MISTAKE"
  echo "$MEMORY_ENTRY" >> "$MEMORY_FILE"
fi

# ─────────────────────────────────────────────────────────────────
# Append to session index (rolling log of all sessions)
# ─────────────────────────────────────────────────────────────────
SESSION_INDEX="$RECEIPTS_DIR/INDEX.md"

# Create header if index doesn't exist
if [[ ! -f "$SESSION_INDEX" ]]; then
  cat > "$SESSION_INDEX" <<'HEADER'
# Session Index

| Date | Session ID | Closeout | Next Action |
|------|------------|----------|-------------|
HEADER
fi

# Get latest outbox result
OUTBOX="${SPINE_OUTBOX:-$REPO/mailroom/outbox}"
LATEST_RESULT=$(ls -1t "$OUTBOX"/*_RESULT.md 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "(none)")

# Append row
echo "| ${DATE} | \`${SESSION_ID}\` | [closeout](SESSION_CLOSEOUT_${TIMESTAMP}.md) | ${NEXT_ACTION} |" >> "$SESSION_INDEX"

# ─────────────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
cat "$CLOSEOUT_FILE"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Saved to: $CLOSEOUT_FILE"
echo "Indexed in: $SESSION_INDEX"
[[ -n "$LEARNED" ]] && echo "Learnings appended to: $MEMORY_FILE"
echo ""
