#!/usr/bin/env bash
# ops start <issue> | ops start loop <loop_id> - create a per-scope worktree + session folder
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/git-lock.sh"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Prevent concurrent sessions from mutating git state (branches/worktrees).
acquire_git_lock || exit 1

scope_kind="${1:-}"
scope_id="${2:-}"
if [[ -z "$scope_kind" ]]; then
  echo "Usage:"
  echo "  ops start <issue-number>"
  echo "  ops start loop <loop_id>"
  exit 1
fi

is_issue=0
is_loop=0
ISSUE=""
LOOP_ID=""

if [[ "$scope_kind" =~ ^[0-9]+$ ]]; then
  is_issue=1
  ISSUE="$scope_kind"
elif [[ "$scope_kind" == "loop" ]]; then
  is_loop=1
  LOOP_ID="$scope_id"
else
  echo "Usage:"
  echo "  ops start <issue-number>"
  echo "  ops start loop <loop_id>"
  exit 1
fi

if (( is_loop == 1 )) && [[ -z "$LOOP_ID" ]]; then
  echo "Usage: ops start loop <loop_id>"
  exit 1
fi

WORKTREE_BASE="$REPO_ROOT/.worktrees"

sanitize_loop_slug() {
  # Turn a loop id into a stable, short-ish worktree basename.
  # Example: LOOP-UDR6-SHOP-CUTOVER-20260209 -> udr6-shop-cutover-20260209
  local s="$1"
  s="${s#LOOP-}"
  s="${s#OL_}"
  s="$(echo "$s" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')"
  s="${s%-}"
  echo "$s"
}

WORKTREE_DIR=""
BRANCH_NAME=""
SESSION_DIR=""

if (( is_issue == 1 )); then
  WORKTREE_DIR="$WORKTREE_BASE/issue-${ISSUE}"
  BRANCH_NAME="issue-${ISSUE}"
  SESSION_DIR="$WORKTREE_DIR/docs/sessions/$(date +%Y-%m-%d)-#${ISSUE}"
else
  loop_slug="$(sanitize_loop_slug "$LOOP_ID")"
  WORKTREE_DIR="$WORKTREE_BASE/codex-${loop_slug}"
  BRANCH_NAME="codex/${LOOP_ID}"
  SESSION_DIR="$WORKTREE_DIR/docs/sessions/$(date +%Y-%m-%d)-${LOOP_ID}"

  # Ensure a loop scope file exists for agents to anchor receipts/decisions.
  # Scope files are the canonical work tracker (see LOOP-MAILROOM-CONSOLIDATION-20260210).
  LOOP_SCOPE_DIR="$REPO_ROOT/mailroom/state/loop-scopes"
  LOOP_SCOPE_FILE="$LOOP_SCOPE_DIR/${LOOP_ID}.scope.md"
  mkdir -p "$LOOP_SCOPE_DIR"
  if [[ ! -f "$LOOP_SCOPE_FILE" ]]; then
    cat > "$LOOP_SCOPE_FILE" <<EOF
---
status: draft
owner: "@ronny"
last_verified: $(date +%Y-%m-%d)
scope: loop-scope
loop_id: ${LOOP_ID}
---

# Loop Scope: ${LOOP_ID}

## Goal

## Success Criteria

## Phases

## Receipts
- (link receipts here)

## Deferred / Follow-ups
EOF
  fi
fi

if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
  echo "Branch ${BRANCH_NAME} already exists"
else
  DEFAULT_BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
  DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
  # Canonical: fetch origin before branching (prevents stale base).
  git fetch --prune origin "$DEFAULT_BRANCH" >/dev/null 2>&1 || true
  # GitHub is mirror-only; divergence is WARN-only (D62 reports it).

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

mkdir -p "$SESSION_DIR"
if (( is_issue == 1 )); then
  cat <<SESSION > "$SESSION_DIR/SESSION_LOG.md"
---
status: ephemeral
owner: "@ronny"
last_verified: $(date +%Y-%m-%d)
scope: session-log
issue: ${ISSUE}
started_utc: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
worktree: ${WORKTREE_DIR}
branch: ${BRANCH_NAME}
---

# Session Log - Issue #${ISSUE}

## Intent

## Work Log

## Receipts (proof)

## Notes / Follow-ups
SESSION
else
  cat <<SESSION > "$SESSION_DIR/SESSION_LOG.md"
---
status: ephemeral
owner: "@ronny"
last_verified: $(date +%Y-%m-%d)
scope: session-log
loop_id: ${LOOP_ID}
started_utc: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
worktree: ${WORKTREE_DIR}
branch: ${BRANCH_NAME}
scope_doc: mailroom/state/loop-scopes/${LOOP_ID}.scope.md
---

# Session Log - Loop ${LOOP_ID}

## Scope
- Scope doc: mailroom/state/loop-scopes/${LOOP_ID}.scope.md

## Intent

## Work Log

## Receipts (proof)

## Decisions

## Notes / Follow-ups
SESSION
fi

if (( is_issue == 1 )); then
  ISSUE_TITLE="Unknown issue"
  if command -v gh >/dev/null 2>&1; then
    ISSUE_TITLE="$(gh issue view "$ISSUE" --json title -q '.title' 2>/dev/null || true)"
    ISSUE_TITLE="${ISSUE_TITLE:-Unknown issue}"
  fi

  cat <<ISSUE > "$SESSION_DIR/ISSUE.md"
# Issue #${ISSUE}
${ISSUE_TITLE}
ISSUE
fi

cat <<BOX

╔═══════════════════════════════════════════════════════════╗
║ Workspace ready                                    ║
║ Worktree: ${WORKTREE_DIR}                                  ║
║ Session:  ${SESSION_DIR}                                   ║
╚═══════════════════════════════════════════════════════════╝

Next: cd ${WORKTREE_DIR} && ops lane open control
BOX
