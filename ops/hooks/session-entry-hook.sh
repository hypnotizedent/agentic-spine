#!/usr/bin/env bash
set -euo pipefail

# Session Entry Enforcement Hook (UserPromptSubmit)
# Injects governance context on the first user prompt per session.
# Subsequent prompts pass through (marker file prevents re-injection).

# Read hook input from stdin
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Marker: only inject once per session
MARKER="/tmp/claude-session-entry-${SESSION_ID}"
if [[ -f "$MARKER" ]]; then
  echo '{}'
  exit 0
fi
touch "$MARKER"

# Resolve spine root (relative to this script)
SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# --- Dynamic context gathering ---

# Spine status (loops + gaps + inbox)
LOOPS="(none)"
if [[ -x "$SPINE_ROOT/bin/ops" ]]; then
  LOOPS=$(timeout 10 "$SPINE_ROOT/bin/ops" status --brief 2>/dev/null || echo "(unavailable)")
fi

# Current branch
BRANCH=$(git -C "$SPINE_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Active worktree count (max allowed: 2)
WT_COUNT=$(git -C "$SPINE_ROOT" worktree list --porcelain 2>/dev/null | grep -c '^worktree' || echo 0)

# Branch status for the message
BRANCH_WARNING=""
if [[ "$BRANCH" == "main" ]]; then
  BRANCH_WARNING="
> **YOU ARE ON \`main\`.** Direct commits and mutating capabilities are BLOCKED.
> To do work: \`./bin/ops start loop <LOOP_ID>\` → creates a worktree branch.
> Only ledger-only commits (\`mailroom/state/ledger.csv\`) are allowed on main."
fi

# Read canonical governance brief (static rules from single source)
BRIEF_FILE="$SPINE_ROOT/docs/governance/AGENT_GOVERNANCE_BRIEF.md"
BRIEF=$(cat "$BRIEF_FILE" 2>/dev/null || echo "(governance brief unavailable — expected at $BRIEF_FILE)")

# Build the system message: dynamic state + canonical brief
MSG="## SESSION ENTRY PROTOCOL (governance hook)

You are working inside the agentic-spine repo (\`$SPINE_ROOT\`).
**Branch:** \`${BRANCH}\` | **Active worktrees:** ${WT_COUNT}/2
${BRANCH_WARNING}

### Spine Status
\`\`\`
${LOOPS}
\`\`\`

${BRIEF}"

# Output JSON with systemMessage
jq -n --arg msg "$MSG" '{"systemMessage": $msg}'
