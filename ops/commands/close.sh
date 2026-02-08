#!/usr/bin/env bash
# ops close - verify, ensure PR merged, update state, close issue
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

ISSUE_ARG="${1:-}"
ISSUE="${CURRENT_ISSUE:-$ISSUE_ARG}"
if [[ -z "$ISSUE" ]]; then
  echo "Usage: ops close [issue-number]" >&2
  exit 1
fi

# Run health checks first
"$SCRIPT_DIR/verify.sh"

# Confirm PR merged
PR_JSON=$(gh pr list --search "#${ISSUE}" --state merged --json number,state,title | jq -r '.[0]')
if [[ -z "$PR_JSON" || "$PR_JSON" == "null" ]]; then
  echo "No merged PR found for issue #${ISSUE}. Merge the PR before closing." >&2
  exit 1
fi

PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number')
PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')

# Legacy: clerk-watcher.sh wrote to deprecated infrastructure paths and is quarantined under ops/legacy/.
# Spine-era closures use loops + receipts, not CURRENT_STATE.md.

# Close the GitHub issue
gh issue close "$ISSUE" --comment "Closed via ops close after PR #${PR_NUMBER}: ${PR_TITLE}"

echo "Issue #${ISSUE} closed (PR #${PR_NUMBER})."

# Clean up worktree
WORKTREE_DIR="$REPO_ROOT/.worktrees/issue-${ISSUE}"
if [[ -d "$WORKTREE_DIR" ]]; then
  git worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || true
  echo "Removed worktree: $WORKTREE_DIR"
fi
