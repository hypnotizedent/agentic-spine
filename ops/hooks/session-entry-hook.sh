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

# Open loops
LOOPS="(none)"
if [[ -x "$SPINE_ROOT/bin/ops" ]]; then
  LOOPS=$(timeout 10 "$SPINE_ROOT/bin/ops" loops list --open 2>/dev/null || echo "(unavailable)")
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

# Build the system message
MSG="## SESSION ENTRY PROTOCOL (governance hook)

You are working inside the agentic-spine repo (\`$SPINE_ROOT\`).
**Branch:** \`${BRANCH}\` | **Active worktrees:** ${WT_COUNT}/2
${BRANCH_WARNING}

### Open Loops
\`\`\`
${LOOPS}
\`\`\`

### Commit & Branch Rules (enforced by pre-commit hook + D48)
- **Main branch is commit-locked.** A pre-commit hook rejects all commits on \`main\` except ledger-only changes. Override: \`OPS_ALLOW_MAIN_COMMIT=1\` (discouraged).
- **Mutating capabilities blocked on main.** \`./bin/ops cap run\` refuses \`safety: mutating\` caps on the \`main\` branch. Override: \`OPS_ALLOW_MAIN_MUTATION=1\` (discouraged).
- **Worktree flow is mandatory.** Use \`./bin/ops start loop <LOOP_ID>\` to create a worktree branch. Work inside it. Merge with fast-forward back to main.
- **Max 2 active worktrees** (D48). After merging, immediately \`git worktree remove .worktrees/codex-<slug>/\`. Stale/merged/orphaned worktrees fail \`spine.verify\`.
- **Gitea is canonical** (origin). GitHub is a mirror. D62 enforces.

### Capability Gotchas
- **\`approval: manual\`** caps prompt for stdin \`yes\`. In scripts: \`echo \"yes\" | ./bin/ops cap run <cap>\`. No \`--\` separator for args.
- **Preconditions are enforced.** Some caps require \`secrets.binding\` + \`secrets.auth.status\` first. If a cap fails with \"precondition failed\", run the listed precondition cap first.
- **\`touches_api: true\`** caps always need secrets preconditions — no exceptions (D63 enforces).

### Path & Reference Constraints (active drift gates)
- **D30:** No \`ronny-ops\` references anywhere. \`~/code/\` is the only source tree.
- **D42:** No uppercase \`Code\` in paths — must be lowercase \`code\`.
- **D46:** \`~/.claude/CLAUDE.md\` is a redirect shim only. Governance lives in \`docs/brain/\`, not \`.brain/\` (D47).
- **D31:** No log/output files in home root (\`~/*.log\`, \`~/*.out\`). Use project paths.
- **D54/D59:** SSOT bindings must match live infrastructure. Adding VMs/hosts requires updates in multiple SSOTs simultaneously.
- **D58:** SSOTs with stale \`last_reviewed\` dates (>2 weeks) fail verify.

### Verify & Receipts
- Run \`./bin/ops cap run spine.verify\` before committing — 50+ drift gates check everything.
- Every capability execution auto-generates a receipt. Ledger is append-only.
- D61 enforces session closeout every 48h: \`./bin/ops cap run agent.session.closeout\`.

### Quick Commands
- \`./bin/ops cap list\` — discover capabilities
- \`./bin/ops loops list --open\` — check open work
- \`./bin/ops start loop <LOOP_ID>\` — start worktree for a loop
- \`./bin/ops cap run spine.verify\` — full drift check
- \`/ctx\` — load full governance context"

# Output JSON with systemMessage
jq -n --arg msg "$MSG" '{"systemMessage": $msg}'
