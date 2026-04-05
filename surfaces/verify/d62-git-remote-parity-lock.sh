#!/usr/bin/env bash
# D62: Publication-only GitHub mirror status surface
#
# Operational truth is `origin` on Gitea. GitHub is publication-only and is not
# part of normal drift-gate semantics. This surface exists for explicit
# publication review only.
#
# Policy:
#   - Hard FAIL if canonical origin is missing or origin/<default> cannot resolve.
#   - Best-effort fetch origin before comparing.
#   - If github remote exists, best-effort fetch and print publication status.
#   - GitHub divergence is informational here; it must not read as operational drift.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }
status() { echo "$*"; }

if ! command -v git >/dev/null 2>&1; then
  fail "git missing"
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "not a git worktree"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  fail "missing remote: origin"
fi

DEFAULT_BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

git fetch --prune origin "$DEFAULT_BRANCH" >/dev/null 2>&1 || true

o_ref="origin/${DEFAULT_BRANCH}"
o_sha="$(git rev-parse --verify --quiet "$o_ref" 2>/dev/null || true)"

[[ -n "$o_sha" ]] || fail "missing ref: $o_ref (fetch failed or remote misconfigured)"

if git remote get-url github >/dev/null 2>&1; then
  git fetch --prune github "$DEFAULT_BRANCH" >/dev/null 2>&1 || true
  g_ref="github/${DEFAULT_BRANCH}"
  g_sha="$(git rev-parse --verify --quiet "$g_ref" 2>/dev/null || true)"
  if [[ -z "${g_sha:-}" ]]; then
    status "PUBLICATION: github mirror ref missing: $g_ref (review only during explicit publication or repository-admin mirror maintenance)"
  elif [[ "$o_sha" != "$g_sha" ]]; then
    status "PUBLICATION ADVISORY: github/main stale relative to origin/main (${o_ref}=${o_sha}; ${g_ref}=${g_sha}). Canonical operational truth remains origin; repair only during explicit publication review or repository-admin mirror maintenance."
  else
    status "PUBLICATION: github/main aligned with origin/main (${g_ref}=${g_sha})"
  fi
else
  status "PUBLICATION: github remote not configured; origin remains the only operational authority"
fi

echo "PASS: D62 canonical origin authority confirmed (${o_ref}=${o_sha})"
