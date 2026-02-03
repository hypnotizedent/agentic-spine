#!/usr/bin/env bash
# ops start <issue> - create a per-issue worktree and session folder
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

ISSUE="${1:-}"
if [[ -z "$ISSUE" ]]; then
  echo "Usage: ops start <issue-number>"
  exit 1
fi

WORKTREE_BASE="$REPO_ROOT/.worktrees"
WORKTREE_DIR="$WORKTREE_BASE/issue-${ISSUE}"
BRANCH_NAME="issue-${ISSUE}"

if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
  echo "Branch ${BRANCH_NAME} already exists"
else
  DEFAULT_BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
  DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
  git fetch origin "$DEFAULT_BRANCH" >/dev/null 2>&1 || true

  if git show-ref --verify --quiet "refs/remotes/origin/${DEFAULT_BRANCH}"; then
    git branch "$BRANCH_NAME" "origin/${DEFAULT_BRANCH}"
  else
    git branch "$BRANCH_NAME" "$DEFAULT_BRANCH"
  fi
fi

if [[ ! -d "$WORKTREE_DIR" ]]; then
  mkdir -p "$WORKTREE_BASE"
  git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"
  echo "Worktree created: $WORKTREE_DIR"
else
  echo "Worktree already exists: $WORKTREE_DIR"
fi

SESSION_DIR="$WORKTREE_DIR/docs/sessions/$(date +%Y-%m-%d)-#${ISSUE}"
mkdir -p "$SESSION_DIR"
cat <<SESSION > "$SESSION_DIR/SESSION_LOG.md"
# Session Log - Issue #${ISSUE}

**Started:** $(date -u)
**Issue:** ${ISSUE}
SESSION

ISSUE_TITLE="Unknown issue"
if command -v gh >/dev/null 2>&1; then
  ISSUE_TITLE="$(gh issue view "$ISSUE" --json title -q '.title' 2>/dev/null || true)"
  ISSUE_TITLE="${ISSUE_TITLE:-Unknown issue}"
fi

cat <<ISSUE > "$SESSION_DIR/ISSUE.md"
# Issue #${ISSUE}
${ISSUE_TITLE}
ISSUE

cat <<BOX

╔═══════════════════════════════════════════════════════════╗
║ Workspace ready for Issue #${ISSUE}                        ║
║ Worktree: ${WORKTREE_DIR}                                  ║
║ Session:  ${SESSION_DIR}                                   ║
╚═══════════════════════════════════════════════════════════╝

Next: cd ${WORKTREE_DIR} && ops lane builder
BOX
