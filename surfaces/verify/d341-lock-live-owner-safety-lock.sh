#!/usr/bin/env bash
# TRIAGE: Prevent TTL reclaim of a live git lock owner.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LOCK_LIB="$ROOT/ops/lib/git-lock.sh"

fail() {
  echo "D341 FAIL: $*" >&2
  exit 1
}

[[ -f "$LOCK_LIB" ]] || fail "missing lock library: $LOCK_LIB"
command -v bash >/dev/null 2>&1 || fail "missing dependency: bash"

tmp_root="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_root" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

mkdir -p "$tmp_root/mailroom/state/locks"

set +e
ROOT_ENV="$ROOT" SPINE_REPO="$tmp_root" GIT_LOCK_TTL=1 bash <<'OUTER'
set -euo pipefail
source "$ROOT_ENV/ops/lib/git-lock.sh"

acquire_git_lock live-owner

# Force an old lock age while owner is still alive.
printf '%s\n' "$(( $(date +%s) - 1000 ))" > "$_GIT_LOCK_DIR/created_at_epoch"

# Attempt to reclaim from a second process. This must fail while owner PID is alive.
if ROOT_ENV="$ROOT_ENV" SPINE_REPO="$SPINE_REPO" GIT_LOCK_TTL=1 bash <<'INNER' >/dev/null 2>&1
set -euo pipefail
source "$ROOT_ENV/ops/lib/git-lock.sh"
acquire_git_lock live-owner
INNER
then
  exit 44
fi

release_git_lock
OUTER
rc=$?
set -e

if [[ "$rc" -eq 44 ]]; then
  fail "lock was reclaimed after TTL even though owner PID was alive"
fi
if [[ "$rc" -ne 0 ]]; then
  fail "lock safety scenario errored (rc=$rc)"
fi

echo "D341 PASS: live lock owner cannot be reclaimed by TTL"
