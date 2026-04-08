#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

command -v git >/dev/null 2>&1 || {
  echo "G16 FAIL: missing dependency: git" >&2
  exit 2
}

cd "$ROOT"

fail() {
  echo "G16 FAIL: $*" >&2
  exit 1
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not a git worktree"
head_sha="$(git rev-parse --verify HEAD 2>/dev/null || true)"
[[ -n "$head_sha" ]] || fail "HEAD unresolved"
git remote get-url origin >/dev/null 2>&1 || fail "origin remote missing"

git fsck --connectivity-only --no-dangling --no-progress >/dev/null 2>&1 || fail "git fsck connectivity failure"
git diff --check >/dev/null 2>&1 || fail "working tree has diff/check errors"
git diff --cached --check >/dev/null 2>&1 || fail "index has diff/check errors"

if [[ -n "$(git ls-files -u)" ]]; then
  fail "unmerged index entries present"
fi

echo "G16 PASS: git repo integrity healthy (HEAD=$head_sha)"
