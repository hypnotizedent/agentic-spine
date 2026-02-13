#!/usr/bin/env bash
# TRIAGE: Push to both origin (Gitea) and github: git push origin main && git push github main.
# D62: Git remote authority lock (Gitea canonical, GitHub mirror-only)
#
# Purpose:
#   Eliminate "split brain" by enforcing a single canonical remote authority.
#   Canonical is `origin` (Gitea). `github` is mirror-only and MUST NOT block
#   canonical work. If github diverges, we WARN (no-fail) so the mirror can be
#   repaired, but we do not STOP.
#
# Policy:
#   - Hard FAIL if origin is missing or origin/<default> ref cannot be resolved.
#   - Best-effort fetch origin before comparing.
#   - If github remote exists, best-effort fetch and WARN if it diverges.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; }

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

# Fetch origin; ignore fetch failure (we will fail if ref is missing).
git fetch --prune origin "$DEFAULT_BRANCH" >/dev/null 2>&1 || true

o_ref="origin/${DEFAULT_BRANCH}"

o_sha="$(git rev-parse --verify --quiet "$o_ref" 2>/dev/null || true)"

[[ -n "$o_sha" ]] || fail "missing ref: $o_ref (fetch failed or remote misconfigured)"

# GitHub mirror parity is best-effort (WARN-only).
if git remote get-url github >/dev/null 2>&1; then
  git fetch --prune github "$DEFAULT_BRANCH" >/dev/null 2>&1 || true
  g_ref="github/${DEFAULT_BRANCH}"
  g_sha="$(git rev-parse --verify --quiet "$g_ref" 2>/dev/null || true)"
  if [[ -z "${g_sha:-}" ]]; then
    warn "github mirror ref missing: $g_ref (fetch failed or remote misconfigured)"
  elif [[ "$o_sha" != "$g_sha" ]]; then
    warn "github mirror drift: ${o_ref}=${o_sha} != ${g_ref}=${g_sha} (repair mirror; canonical is origin)"
  fi
fi

echo "PASS: D62 git remote authority lock (canonical ${o_ref}=${o_sha})"
