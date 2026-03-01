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
FRICTION_INGEST="$REPO/ops/plugins/lifecycle/bin/friction-ingest"
FRICTION_STATUS="$REPO/ops/plugins/lifecycle/bin/friction-queue-status"

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

FRICTION_CAPTURED=0
FRICTION_CREATED=0
FRICTION_DEDUPED=0

if [[ -x "$FRICTION_INGEST" ]]; then
  echo ""
  echo "Capture structured friction items? (y/N)"
  read -r -p "FRICTION_CAPTURE: " FRICTION_CAPTURE

  while [[ "${FRICTION_CAPTURE,,}" == "y" || "${FRICTION_CAPTURE,,}" == "yes" ]]; do
    echo "Capability (required, e.g. verify.pack.run):"
    read -r -p "FRICTION_CAP: " FRICTION_CAP
    echo "Expected behavior (required):"
    read -r -p "FRICTION_EXPECTED: " FRICTION_EXPECTED
    echo "Actual behavior (required):"
    read -r -p "FRICTION_ACTUAL: " FRICTION_ACTUAL
    echo "Severity [low|medium|high|critical] (default: medium):"
    read -r -p "FRICTION_SEVERITY: " FRICTION_SEVERITY

    if [[ -z "$FRICTION_CAP" || -z "$FRICTION_EXPECTED" || -z "$FRICTION_ACTUAL" ]]; then
      echo "Skipped friction item (capability/expected/actual required)."
    else
      [[ -z "$FRICTION_SEVERITY" ]] && FRICTION_SEVERITY="medium"
      if FRICTION_JSON="$("$FRICTION_INGEST" \
        --source close-session \
        --capability "$FRICTION_CAP" \
        --expected "$FRICTION_EXPECTED" \
        --actual "$FRICTION_ACTUAL" \
        --severity "$FRICTION_SEVERITY" \
        --json 2>/dev/null)"; then
        ITEM_CREATED="$(printf '%s' "$FRICTION_JSON" | jq -r '.created // 0' 2>/dev/null || echo 0)"
        ITEM_DEDUPED="$(printf '%s' "$FRICTION_JSON" | jq -r '.deduped // 0' 2>/dev/null || echo 0)"
        FRICTION_CAPTURED=$((FRICTION_CAPTURED + 1))
        FRICTION_CREATED=$((FRICTION_CREATED + ITEM_CREATED))
        FRICTION_DEDUPED=$((FRICTION_DEDUPED + ITEM_DEDUPED))
        echo "Captured friction item: created=${ITEM_CREATED} deduped=${ITEM_DEDUPED}"
      else
        echo "WARN: friction-ingest failed for this item."
      fi
    fi

    echo ""
    echo "Capture another friction item? (y/N)"
    read -r -p "FRICTION_CAPTURE: " FRICTION_CAPTURE
  done
fi

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

# Add friction intake summary if captured
if [[ "$FRICTION_CAPTURED" -gt 0 ]]; then
  {
    echo ""
    echo "## Friction Intake"
    echo ""
    echo "- Captured items: ${FRICTION_CAPTURED}"
    echo "- Queue inserts: ${FRICTION_CREATED}"
    echo "- Dedupe hits: ${FRICTION_DEDUPED}"
    if [[ -x "$FRICTION_STATUS" ]]; then
      FR_STATUS="$("$FRICTION_STATUS" --json 2>/dev/null || true)"
      if [[ -n "$FR_STATUS" ]]; then
        Q_TOTAL="$(printf '%s' "$FR_STATUS" | jq -r '.summary.total // 0' 2>/dev/null || echo 0)"
        Q_QUEUED="$(printf '%s' "$FR_STATUS" | jq -r '.summary.queued // 0' 2>/dev/null || echo 0)"
        Q_STALE="$(printf '%s' "$FR_STATUS" | jq -r '.summary.stale // 0' 2>/dev/null || echo 0)"
        echo "- Queue summary: total=${Q_TOTAL} queued=${Q_QUEUED} stale=${Q_STALE}"
      fi
    fi
  } >> "$CLOSEOUT_FILE"
fi

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
