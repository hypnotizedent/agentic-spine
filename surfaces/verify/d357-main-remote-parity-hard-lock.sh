#!/usr/bin/env bash
# TRIAGE: align mirror deterministically from canonical origin main.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail() { echo "D357 FAIL: $*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || fail "git missing"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not a git worktree"

git remote get-url origin >/dev/null 2>&1 || fail "missing required remote: origin"
git remote get-url github >/dev/null 2>&1 || fail "missing required remote: github"

default_branch="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || true)"
default_branch="${default_branch:-main}"

git fetch --prune origin "$default_branch" >/dev/null 2>&1 || fail "failed to fetch origin/$default_branch"
git fetch --prune github "$default_branch" >/dev/null 2>&1 || fail "failed to fetch github/$default_branch"

origin_ref="origin/${default_branch}"
github_ref="github/${default_branch}"

origin_sha="$(git rev-parse --verify --quiet "$origin_ref" 2>/dev/null || true)"
github_sha="$(git rev-parse --verify --quiet "$github_ref" 2>/dev/null || true)"

[[ -n "$origin_sha" ]] || fail "unresolvable ref: $origin_ref"
[[ -n "$github_sha" ]] || fail "unresolvable ref: $github_ref"

if [[ "$origin_sha" != "$github_sha" ]]; then
  fail "mainline parity mismatch: $origin_ref=$origin_sha != $github_ref=$github_sha; remediate mirror parity before closeout"
fi

echo "D357 PASS: remote mainline parity holds ($origin_ref == $github_ref == $origin_sha)"
