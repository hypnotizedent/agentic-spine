#!/usr/bin/env bash
set -euo pipefail

# D439: Execution Host Deploy Posture
# Purpose: execution_host carries runtime execution, not local development.
# The remote checkout is a deploy target: on main, clean, and protected by a
# pre-commit guard that blocks local commits unless explicitly overridden.

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TARGET_ID="${D439_TARGET_ID:-ai-consolidation}"
REMOTE_REPO="${D439_REMOTE_REPO:-/home/ubuntu/code/agentic-spine}"

fail() {
  echo "D439 FAIL: $*" >&2
  exit 1
}

command -v ssh >/dev/null 2>&1 || fail "missing dependency: ssh"
command -v git >/dev/null 2>&1 || fail "missing dependency: git"

source "$ROOT/ops/lib/ssh-resolve.sh"

resolve_result="$(ssh_resolve_ssh_host_with_fallback "$TARGET_ID" 6 2>/dev/null || true)"
ssh_host="$(awk '{print $1}' <<<"$resolve_result")"
ssh_user="$(ssh_resolve_user "$TARGET_ID" "ubuntu")"
identity_opts="$(ssh_resolve_machine_identity_opts "$TARGET_ID" 2>/dev/null)" || true

[[ -n "$ssh_host" ]] || fail "missing ssh host for $TARGET_ID"

ssh_target="${ssh_user}@${ssh_host}"

# shellcheck disable=SC2086
remote_report="$(
  ssh -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=accept-new $identity_opts "$ssh_target" \
    "REMOTE_REPO='$REMOTE_REPO' bash -s" <<'REMOTE'
set -euo pipefail

repo="${REMOTE_REPO:?REMOTE_REPO required}"
hook="$repo/.git/hooks/pre-commit"

if [[ ! -d "$repo/.git" ]]; then
  echo "status=fail"
  echo "reason=missing_repo"
  echo "repo=$repo"
  exit 0
fi

branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
dirty="$(git -C "$repo" status --porcelain=v1 2>/dev/null || true)"
head="$(git -C "$repo" rev-parse --verify HEAD 2>/dev/null || true)"

hook_exists=false
hook_executable=false
hook_blocks=false
hook_names_deploy_target=false
hook_names_override=false

if [[ -f "$hook" ]]; then
  hook_exists=true
  [[ -x "$hook" ]] && hook_executable=true
  grep -q 'exit 1' "$hook" && hook_blocks=true
  grep -qi 'deploy target\\|deploy-target' "$hook" && hook_names_deploy_target=true
  grep -q 'SPINE_DEPLOY_TARGET_OVERRIDE' "$hook" && hook_names_override=true
fi

echo "status=ok"
echo "repo=$repo"
echo "branch=$branch"
echo "head=$head"
echo "dirty_count=$(printf '%s\n' "$dirty" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "hook_exists=$hook_exists"
echo "hook_executable=$hook_executable"
echo "hook_blocks=$hook_blocks"
echo "hook_names_deploy_target=$hook_names_deploy_target"
echo "hook_names_override=$hook_names_override"
if [[ -n "$dirty" ]]; then
  echo "dirty_begin"
  printf '%s\n' "$dirty"
  echo "dirty_end"
fi
REMOTE
)" || fail "unable to read remote deploy posture from $TARGET_ID"

value_for() {
  local key="$1"
  printf '%s\n' "$remote_report" | awk -F= -v key="$key" '$1 == key {sub("^[^=]*=", ""); print; exit}'
}

status="$(value_for status)"
repo="$(value_for repo)"
branch="$(value_for branch)"
dirty_count="$(value_for dirty_count)"
hook_exists="$(value_for hook_exists)"
hook_executable="$(value_for hook_executable)"
hook_blocks="$(value_for hook_blocks)"
hook_names_deploy_target="$(value_for hook_names_deploy_target)"
hook_names_override="$(value_for hook_names_override)"

[[ "$status" == "ok" ]] || fail "$TARGET_ID deploy checkout missing or unreadable: $remote_report"
[[ "$branch" == "main" ]] || fail "$TARGET_ID deploy checkout must be on main (repo=$repo branch=${branch:-<none>})"
[[ "$dirty_count" == "0" ]] || fail "$TARGET_ID deploy checkout dirty (repo=$repo dirty_count=$dirty_count): $(printf '%s\n' "$remote_report" | sed -n '/dirty_begin/,/dirty_end/p' | tr '\n' '; ')"
[[ "$hook_exists" == "true" ]] || fail "$TARGET_ID deploy checkout missing pre-commit deploy-target guard ($repo/.git/hooks/pre-commit)"
[[ "$hook_executable" == "true" ]] || fail "$TARGET_ID pre-commit deploy-target guard is not executable"
[[ "$hook_blocks" == "true" ]] || fail "$TARGET_ID pre-commit deploy-target guard must block local commits"
[[ "$hook_names_deploy_target" == "true" ]] || fail "$TARGET_ID pre-commit guard must name deploy-target posture"
[[ "$hook_names_override" == "true" ]] || fail "$TARGET_ID pre-commit guard must require explicit SPINE_DEPLOY_TARGET_OVERRIDE for emergency local commit"

echo "D439 PASS: execution_host deploy checkout is clean, on main, and guarded against local commits"
