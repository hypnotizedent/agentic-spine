#!/usr/bin/env bash
# D62: Git remote parity lock
#
# Purpose:
#   Eliminate "split brain" by enforcing that BOTH remotes track the same main tip.
#   If origin/main and github/main diverge, agents will drift (different histories,
#   different loop/ledger states, and inconsistent releases).
#
# Policy:
#   - Hard FAIL if either remote is missing.
#   - Hard FAIL if origin/main != github/main.
#   - Best-effort fetch before comparing.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }

if ! command -v git >/dev/null 2>&1; then
  fail "git missing"
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "not a git worktree"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  fail "missing remote: origin"
fi
if ! git remote get-url github >/dev/null 2>&1; then
  fail "missing remote: github"
fi

DEFAULT_BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

# Fetch both remotes; ignore fetch failures (we will fail if refs are missing or diverged).
git fetch --prune origin "$DEFAULT_BRANCH" >/dev/null 2>&1 || true
git fetch --prune github "$DEFAULT_BRANCH" >/dev/null 2>&1 || true

o_ref="origin/${DEFAULT_BRANCH}"
g_ref="github/${DEFAULT_BRANCH}"

o_sha="$(git rev-parse --verify --quiet "$o_ref" 2>/dev/null || true)"
g_sha="$(git rev-parse --verify --quiet "$g_ref" 2>/dev/null || true)"

[[ -n "$o_sha" ]] || fail "missing ref: $o_ref (fetch failed or remote misconfigured)"
[[ -n "$g_sha" ]] || fail "missing ref: $g_ref (fetch failed or remote misconfigured)"

if [[ "$o_sha" != "$g_sha" ]]; then
  fail "remote split brain: ${o_ref}=${o_sha} != ${g_ref}=${g_sha}"
fi

echo "PASS: D62 git remote parity lock (${DEFAULT_BRANCH}=${o_sha})"

