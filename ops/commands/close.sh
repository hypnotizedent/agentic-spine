#!/usr/bin/env bash
# ops close - verify, clean up worktree/branch/stashes, optionally close an issue
#
# Usage:
#   ops close loop <LOOP_ID>              — tear down codex worktree + branch + stashes
#   ops close <issue-number> --forge github — close GitHub issue after PR merge
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

source "$SCRIPT_DIR/lib/git-lock.sh" 2>/dev/null || true

usage() {
  cat <<'EOF'
ops close - verify, clean up worktree/branch/stashes, optionally close an issue

Usage:
  ops close loop <LOOP_ID>
  ops close <issue-number> --forge github
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

FORGE="none"
ISSUE_ARG=""
LOOP_ID=""
IS_LOOP=0

# Parse args
if [[ "${1:-}" == "loop" ]]; then
  IS_LOOP=1
  LOOP_ID="${2:-}"
  shift 2 || true
else
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
fi

# ── Loop close path ──────────────────────────────────────────────────────
if (( IS_LOOP == 1 )); then
  if [[ -z "$LOOP_ID" ]]; then
    echo "Usage: ops close loop <LOOP_ID>" >&2
    exit 1
  fi

  # Derive worktree/branch names (mirrors ops start loop convention)
  loop_slug="$(echo "${LOOP_ID#LOOP-}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')"
  loop_slug="${loop_slug%-}"
  WORKTREE_DIR="$REPO_ROOT/.worktrees/codex-${loop_slug}"
  BRANCH_NAME="codex/${LOOP_ID}"

  echo "=== ops close loop: ${LOOP_ID} ==="

  # 1. Remove worktree
  if [[ -d "$WORKTREE_DIR" ]]; then
    git -C "$REPO_ROOT" worktree remove --force "$WORKTREE_DIR" 2>/dev/null || true
    echo "  worktree removed: $WORKTREE_DIR"
  else
    echo "  worktree already gone: $WORKTREE_DIR"
  fi

  # 2. Delete branch (only if merged into main)
  if git -C "$REPO_ROOT" rev-parse --verify --quiet "refs/heads/$BRANCH_NAME" >/dev/null 2>&1; then
    if git -C "$REPO_ROOT" branch --merged main --list "$BRANCH_NAME" 2>/dev/null | grep -q .; then
      git -C "$REPO_ROOT" branch -d "$BRANCH_NAME" 2>/dev/null || true
      echo "  branch deleted (merged): $BRANCH_NAME"
    else
      echo "  WARN: branch exists but NOT merged into main — keeping: $BRANCH_NAME"
    fi
  else
    echo "  branch already gone: $BRANCH_NAME"
  fi

  # 3. Drop orphaned stashes referencing this branch
  dropped=0
  # Process in reverse so indices stay stable
  stash_indices=()
  idx=0
  while IFS= read -r stash_line; do
    [[ -z "$stash_line" ]] && continue
    branch_part="${stash_line#*On }"
    stash_branch="${branch_part%%:*}"
    if [[ "$stash_branch" == "$BRANCH_NAME" ]]; then
      stash_indices+=("$idx")
    fi
    idx=$((idx + 1))
  done < <(git -C "$REPO_ROOT" stash list 2>/dev/null)

  for (( i=${#stash_indices[@]}-1; i>=0; i-- )); do
    git -C "$REPO_ROOT" stash drop "stash@{${stash_indices[$i]}}" >/dev/null 2>&1 || true
    dropped=$((dropped + 1))
  done
  echo "  stashes dropped: $dropped"

  echo "Done."
  exit 0
fi

# ── Issue close path (existing behavior) ─────────────────────────────────
ISSUE="${CURRENT_ISSUE:-$ISSUE_ARG}"

# Run health checks first
"$REPO_ROOT/bin/ops" cap run spine.verify

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
