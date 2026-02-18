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

# Resolve spine root (relative to this script)
SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BRANCH=$(git -C "$SPINE_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

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

# --- Non-main session isolation guard (GAP-OP-656) ---
WORKTREE_ISO_CONTRACT="$SPINE_ROOT/ops/bindings/worktree.session.isolation.yaml"
WSI_ENABLED=true
WSI_MAIN_BRANCH="main"
WSI_MANAGED_PREFIX="/Users/ronnyworks/code/agentic-spine-.worktrees/"
WSI_REQUIRE_NON_MAIN_IN_MANAGED=true
WSI_REQUIRE_IDENTITY=true
WSI_IDENTITY_ENV_VAR="OPS_WORKTREE_IDENTITY"
WSI_BYPASS_ENV_VAR="OPS_WORKTREE_ISOLATION_BYPASS"
WSI_BYPASS_ALLOWED="1"
WSI_ALLOW_DETACHED=false
WSI_REMEDIATION="Run ./bin/ops start loop <LOOP_ID> and export OPS_WORKTREE_IDENTITY=<LOOP_ID>."
WSI_BYPASS_WARNING="Emergency bypass only: export OPS_WORKTREE_ISOLATION_BYPASS=1"
WSI_IDENTITY_PATTERNS=()

if [[ -f "$WORKTREE_ISO_CONTRACT" ]] && command -v yq >/dev/null 2>&1; then
  WSI_ENABLED="$(yq e -r '.policy.enabled // true' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo true)"
  WSI_MAIN_BRANCH="$(yq e -r '.policy.main_branch // "main"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo main)"
  WSI_MANAGED_PREFIX="$(yq e -r '.policy.managed_worktree_prefix // "/Users/ronnyworks/code/agentic-spine-.worktrees/"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo /Users/ronnyworks/code/agentic-spine-.worktrees/)"
  WSI_REQUIRE_NON_MAIN_IN_MANAGED="$(yq e -r '.policy.require_non_main_in_managed_worktree // true' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo true)"
  WSI_REQUIRE_IDENTITY="$(yq e -r '.policy.require_explicit_identity_on_non_main // true' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo true)"
  WSI_IDENTITY_ENV_VAR="$(yq e -r '.policy.identity_env_var // "OPS_WORKTREE_IDENTITY"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo OPS_WORKTREE_IDENTITY)"
  WSI_BYPASS_ENV_VAR="$(yq e -r '.policy.bypass_env_var // "OPS_WORKTREE_ISOLATION_BYPASS"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo OPS_WORKTREE_ISOLATION_BYPASS)"
  WSI_BYPASS_ALLOWED="$(yq e -r '.policy.bypass_allowed_value // "1"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo 1)"
  WSI_ALLOW_DETACHED="$(yq e -r '.policy.allow_detached_head // false' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo false)"
  WSI_REMEDIATION="$(yq e -r '.messages.remediation // "Run ./bin/ops start loop <LOOP_ID> and export OPS_WORKTREE_IDENTITY=<LOOP_ID>."' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo "$WSI_REMEDIATION")"
  WSI_BYPASS_WARNING="$(yq e -r '.messages.bypass_warning // "Emergency bypass only: export OPS_WORKTREE_ISOLATION_BYPASS=1"' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || echo "$WSI_BYPASS_WARNING")"
  while IFS= read -r pat; do
    [[ -n "$pat" && "$pat" != "null" ]] && WSI_IDENTITY_PATTERNS+=("$pat")
  done < <(yq e -r '.policy.identity_patterns[]?' "$WORKTREE_ISO_CONTRACT" 2>/dev/null || true)
fi

if [[ "$WSI_ENABLED" == "true" ]]; then
  WSI_ISSUES=()
  WSI_ROOT="$(git -C "$SPINE_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$SPINE_ROOT")"
  WSI_IDENTITY_VALUE="${!WSI_IDENTITY_ENV_VAR-}"
  WSI_BYPASS_VALUE="${!WSI_BYPASS_ENV_VAR-}"

  if [[ "$BRANCH" == "HEAD" && "$WSI_ALLOW_DETACHED" != "true" ]]; then
    WSI_ISSUES+=("Detached HEAD is not allowed by isolation policy.")
  fi

  if [[ "$BRANCH" != "$WSI_MAIN_BRANCH" && "$BRANCH" != "unknown" ]]; then
    if [[ "$WSI_BYPASS_VALUE" != "$WSI_BYPASS_ALLOWED" ]]; then
      if [[ "$WSI_REQUIRE_NON_MAIN_IN_MANAGED" == "true" ]]; then
        case "$WSI_ROOT/" in
          "$WSI_MANAGED_PREFIX"*) ;;
          *) WSI_ISSUES+=("Non-main branch '$BRANCH' is outside managed worktree prefix '$WSI_MANAGED_PREFIX'.") ;;
        esac
      fi

      if [[ "$WSI_REQUIRE_IDENTITY" == "true" ]]; then
        if [[ -z "$WSI_IDENTITY_VALUE" ]]; then
          WSI_ISSUES+=("Non-main branch '$BRANCH' requires explicit identity env '$WSI_IDENTITY_ENV_VAR'.")
        elif [[ "${#WSI_IDENTITY_PATTERNS[@]}" -gt 0 ]]; then
          WSI_ID_OK=false
          for pat in "${WSI_IDENTITY_PATTERNS[@]}"; do
            if [[ "$WSI_IDENTITY_VALUE" =~ $pat ]]; then
              WSI_ID_OK=true
              break
            fi
          done
          if [[ "$WSI_ID_OK" != "true" ]]; then
            WSI_ISSUES+=("$WSI_IDENTITY_ENV_VAR='$WSI_IDENTITY_VALUE' does not match allowed identity patterns.")
          fi
        fi
      fi
    fi
  fi

  if [[ "${#WSI_ISSUES[@]}" -gt 0 ]]; then
    WSI_LINES=""
    for issue in "${WSI_ISSUES[@]}"; do
      WSI_LINES="${WSI_LINES}"$'\n'"- ${issue}"
    done
    BLOCK_MSG=$(cat <<EOF
## SESSION ENTRY BLOCKED (D140 Worktree Session Isolation)

Branch: \`${BRANCH}\`
Worktree: \`${WSI_ROOT}\`

Violations:${WSI_LINES}

Remediation: ${WSI_REMEDIATION}
${WSI_BYPASS_WARNING}
EOF
)
    jq -n --arg msg "$BLOCK_MSG" '{"systemMessage": $msg}'
    exit 0
  fi
fi

# Marker is written only after isolation checks pass.
touch "$MARKER"

# --- Dynamic context gathering (via spine.context capability) ---

# Use spine.context for governance brief delivery (Move 3: dynamic context)
CONTEXT_SCRIPT="$SPINE_ROOT/ops/plugins/context/bin/spine-context"

# Spine status (loops + gaps + inbox + proposals)
LOOPS="(none)"
if [[ -x "$SPINE_ROOT/bin/ops" ]]; then
  LOOPS=$(timeout 10 "$SPINE_ROOT/bin/ops" status --brief 2>/dev/null || echo "(unavailable)")
fi

# Proposal queue health (lightweight: count pending proposals)
PROPOSALS_HEALTH=""
PROPOSALS_DIR="$SPINE_ROOT/mailroom/outbox/proposals"
if [[ -d "$PROPOSALS_DIR" ]]; then
  pending=0
  held=0
  for cpdir in "$PROPOSALS_DIR"/CP-*/; do
    [[ -d "$cpdir" ]] || continue
    [[ -f "$cpdir/.applied" ]] && continue
    manifest="$cpdir/manifest.yaml"
    [[ -f "$manifest" ]] || continue
    st=$(grep -m1 '^status:' "$manifest" 2>/dev/null | sed 's/^status: *//' | tr -d '"' || echo "pending")
    case "$st" in
      draft_hold) held=$((held + 1)) ;;
      pending|draft|"") pending=$((pending + 1)) ;;
    esac
  done
  if [[ "$pending" -gt 5 ]]; then
    PROPOSALS_HEALTH="
> **Proposal queue: ${pending} pending** (threshold: 5). Run \`proposals.status\` and triage."
  fi
fi

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

# Read governance brief — prefer spine.context dynamic delivery, fallback to direct file read
BRIEF_FILE="$SPINE_ROOT/docs/governance/AGENT_GOVERNANCE_BRIEF.md"
if [[ -x "$CONTEXT_SCRIPT" ]]; then
  BRIEF=$("$CONTEXT_SCRIPT" --section brief 2>/dev/null || cat "$BRIEF_FILE" 2>/dev/null || echo "(governance brief unavailable)")
else
  BRIEF=$(cat "$BRIEF_FILE" 2>/dev/null || echo "(governance brief unavailable — expected at $BRIEF_FILE)")
fi

# Build the system message: dynamic state + canonical brief
MSG="## SESSION ENTRY PROTOCOL (governance hook)

You are working inside the agentic-spine repo (\`$SPINE_ROOT\`).
**Branch:** \`${BRANCH}\` | **Active worktrees:** ${WT_COUNT}/2 | **Active sessions:** ${ACTIVE_SESSIONS}
${DIRTY_WARNING}${MULTI_AGENT_WARNING}${PROPOSALS_HEALTH}

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
