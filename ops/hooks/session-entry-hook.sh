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

parse_epoch_utc() {
  local ts="${1:-}"
  [[ -n "$ts" ]] || { echo 0; return; }

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$ts" <<'PY'
import sys
from datetime import datetime, timezone

ts = (sys.argv[1] or "").strip()
if not ts:
    print(0)
    raise SystemExit(0)

if ts.endswith("Z"):
    ts = ts[:-1] + "+00:00"

try:
    dt = datetime.fromisoformat(ts)
except Exception:
    print(0)
    raise SystemExit(0)

if dt.tzinfo is None:
    dt = dt.replace(tzinfo=timezone.utc)

print(int(dt.timestamp()))
PY
    return
  fi

  if date --version >/dev/null 2>&1; then
    date -d "$ts" "+%s" 2>/dev/null || echo 0
    return
  fi

  local clean_ts="${ts%%Z*}"
  clean_ts="${clean_ts%%+*}"
  date -j -f "%Y-%m-%dT%H:%M:%S" "$clean_ts" "+%s" 2>/dev/null || echo 0
}

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

# Dirty working tree warning (multi-terminal safety)
DIRTY_STATUS="$(git -C "$SPINE_ROOT" status --porcelain 2>/dev/null || true)"
DIRTY_COUNT="$(printf '%s\n' "$DIRTY_STATUS" | sed '/^$/d' | wc -l | tr -d ' ')"

DIRTY_WARNING=""
if [[ "${DIRTY_COUNT:-0}" != "0" ]]; then
  DIRTY_WARNING="
> **WORKTREE IS DIRTY (${DIRTY_COUNT} change(s)).**
> If you didn't make these changes, STOP. Another agent/terminal is in-flight.
> Default policy for multi-agent work: treat repo as read-only and submit a change proposal instead.
>
> Quick fix (operator only): commit/stash/clean before running verify or applying proposals.
"
fi

# ─── Multi-agent session detection ──────────────────────────
SESSIONS_DIR="$SPINE_ROOT/mailroom/state/sessions"
SESSION_TTL=${SPINE_SESSION_TTL:-14400}  # 4 hours
ACTIVE_SESSIONS=0
NOW=$(date +%s)

if [[ -d "$SESSIONS_DIR" ]]; then
  for sdir in "$SESSIONS_DIR"/SES-*/; do
    [[ -d "$sdir" ]] || continue
    manifest="$sdir/session.yaml"
    [[ -f "$manifest" ]] || continue

    created=$(grep '^created:' "$manifest" 2>/dev/null | sed 's/^created: *//' | tr -d '"' || echo "")
    pid=$(grep '^pid:' "$manifest" 2>/dev/null | sed 's/^pid: *//' | tr -d '"' || echo "")

    pid_alive=false
    if [[ -n "$pid" && "$pid" != "null" ]]; then
      if kill -0 "$pid" 2>/dev/null; then
        pid_alive=true
      fi
    fi

    epoch=$(parse_epoch_utc "$created")
    age=$((NOW - epoch))
    if [[ "$pid_alive" == "true" && $age -lt $SESSION_TTL ]]; then
      ACTIVE_SESSIONS=$((ACTIVE_SESSIONS + 1))
    fi
  done
fi

MULTI_AGENT_WARNING=""
if [[ "$ACTIVE_SESSIONS" -gt 1 ]]; then
  MULTI_AGENT_WARNING="
> **MULTI-AGENT MODE ACTIVE ($ACTIVE_SESSIONS sessions detected).**
> Proposal flow required — avoid direct commit.
> Use: \`./bin/ops cap run proposals.submit \"desc\"\` to submit changes.
> Apply-owner applies: \`./bin/ops cap run proposals.apply CP-...\`
> Direct commits are blocked by pre-commit hook unless apply-owner lock is held.
"
fi

# Read canonical governance brief (static rules from single source)
BRIEF_FILE="$SPINE_ROOT/docs/governance/AGENT_GOVERNANCE_BRIEF.md"
BRIEF=$(cat "$BRIEF_FILE" 2>/dev/null || echo "(governance brief unavailable — expected at $BRIEF_FILE)")

# Build the system message: dynamic state + canonical brief
MSG="## SESSION ENTRY PROTOCOL (governance hook)

You are working inside the agentic-spine repo (\`$SPINE_ROOT\`).
**Branch:** \`${BRANCH}\` | **Active worktrees:** ${WT_COUNT}/2 | **Active sessions:** ${ACTIVE_SESSIONS}
${DIRTY_WARNING}${MULTI_AGENT_WARNING}

### Multi-Agent Write Policy (Default)
- Agents: read-only on repo; write proposals to \`mailroom/outbox/proposals/\`
- Operator: apply via \`./bin/ops cap run proposals.apply <CP-...>\` (creates a commit)
- If you need isolation: \`./bin/ops start loop <LOOP_ID>\` (worktrees optional)

### Spine Status
\`\`\`
${LOOPS}
\`\`\`

${BRIEF}"

# Output JSON with systemMessage
jq -n --arg msg "$MSG" '{"systemMessage": $msg}'
