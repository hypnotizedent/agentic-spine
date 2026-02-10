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

# Gather open loops (timeout after 10s to avoid blocking)
LOOPS="(none)"
if [[ -x "$SPINE_ROOT/bin/ops" ]]; then
  LOOPS=$(timeout 10 "$SPINE_ROOT/bin/ops" loops list --open 2>/dev/null || echo "(unavailable)")
fi

# Build the system message
MSG="## SESSION ENTRY PROTOCOL (governance hook)

You are working inside the agentic-spine repo. Follow the session protocol.

### Open Loops
\`\`\`
${LOOPS}
\`\`\`

### Hard Rules
1. Execute mutations via \`./bin/ops cap run <capability>\` — never raw shell mutations.
2. **No ronny-ops references** — \`~/code/\` is the only source tree (D30).
3. Query SSOT docs + \`rg\` before guessing. \`mint ask\` is deprecated.
4. Use worktree flow for changes: \`./bin/ops start loop <LOOP_ID>\`
5. Close loops with receipts as proof.
6. Run \`/ctx\` for full governance context if needed.

### Quick Commands
- \`./bin/ops cap list\` — discover capabilities
- \`./bin/ops loops list --open\` — check open work
- \`./bin/ops cap run spine.verify\` — drift check"

# Output JSON with systemMessage
jq -n --arg msg "$MSG" '{"systemMessage": $msg}'
