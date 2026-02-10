#!/usr/bin/env bash
# ops pr - stage, commit, push, and open PR for the current issue
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/git-lock.sh"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

DRY_RUN=0
ISSUE_ARG=""
DESCRIPTION="$(git config --get user.name || echo "ops update")"
PR_TITLE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n)
      DRY_RUN=1
      shift
      ;;
    --description|-d)
      DESCRIPTION="$2"
      shift 2
      ;;
    --title|-t)
      PR_TITLE="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      if [[ -z "$ISSUE_ARG" ]]; then
        ISSUE_ARG="$1"
      else
        DESCRIPTION="$1"
      fi
      shift
      ;;
  esac
done

ISSUE="${CURRENT_ISSUE:-$ISSUE_ARG}"
if [[ -z "$ISSUE" ]]; then
  echo "Usage: ops pr [issue-number]" >&2
  echo "  Set CURRENT_ISSUE or pass the issue as the first argument"
  exit 1
fi

# Prevent concurrent sessions from mutating git state (branches, commits, pushes).
acquire_git_lock || exit 1

DESCRIPTION="${DESCRIPTION:-ops update}"
COMMIT_MSG="feat(ops): ${DESCRIPTION} (#${ISSUE})"
PR_TITLE="${PR_TITLE:-Issue #${ISSUE}: ${DESCRIPTION}}"
PR_BODY="Closes #${ISSUE}"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "DRY RUN: git add -A"
  echo "DRY RUN: git commit -m '${COMMIT_MSG}'"
  echo "DRY RUN: git push -u origin HEAD"
  echo "DRY RUN: gh pr create --title '${PR_TITLE}' --body '${PR_BODY}'"
  exit 0
fi

git add -A
if git diff --cached --quiet; then
  echo "No staged changes to commit" >&2
  exit 1
fi

git commit -m "$COMMIT_MSG"

# Canonical: push to BOTH remotes to prevent origin/github divergence.
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "STOP: missing remote 'origin' (required)" >&2
  exit 1
fi
if ! git remote get-url github >/dev/null 2>&1; then
  echo "STOP: missing remote 'github' (required)" >&2
  exit 1
fi

git push -u origin HEAD
git push -u github HEAD

PR_URL=$(gh pr create --title "$PR_TITLE" --body "$PR_BODY" --json url | jq -r '.url')

if [[ -n "$PR_URL" ]]; then
  echo "PR created: $PR_URL"
else
  echo "PR created (URL unavailable)"
fi
