#!/usr/bin/env bash
# ops close - verify, ensure PR merged, update state, optionally close an issue
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

FORGE="none"
ISSUE_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --forge)
      FORGE="${2:-}"
      shift 2
      ;;
    *)
      ISSUE_ARG="${ISSUE_ARG:-$1}"
      shift
      ;;
  esac
done

ISSUE="${CURRENT_ISSUE:-$ISSUE_ARG}"

# Run health checks first
"$SCRIPT_DIR/verify.sh"

if [[ "$FORGE" == "github" ]]; then
  if [[ -z "${ISSUE:-}" ]]; then
    echo "Usage: ops close [issue-number] --forge github" >&2
    exit 1
  fi

  # Confirm PR merged (GitHub-only helper)
  PR_JSON=$(gh pr list --search "#${ISSUE}" --state merged --json number,state,title | jq -r '.[0]')
  if [[ -z "$PR_JSON" || "$PR_JSON" == "null" ]]; then
    echo "No merged PR found for issue #${ISSUE}. Merge the PR before closing." >&2
    exit 1
  fi

  PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number')
  PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')

  gh issue close "$ISSUE" --comment "Closed via ops close after PR #${PR_NUMBER}: ${PR_TITLE}"
  echo "Issue #${ISSUE} closed (PR #${PR_NUMBER})."
else
  echo "Verify complete."
  echo "Note: loops + receipts are canonical; issue closure is optional."
  echo "To close a GitHub issue: ops close <issue> --forge github"
fi

# Clean up worktree
if [[ -n "${ISSUE:-}" ]]; then
  WORKTREE_DIR="$REPO_ROOT/.worktrees/issue-${ISSUE}"
  if [[ -d "$WORKTREE_DIR" ]]; then
    git worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || true
    echo "Removed worktree: $WORKTREE_DIR"
  fi
fi
