#!/usr/bin/env bash
set -euo pipefail

# Resolve or create managed runtime worktree for scheduled projection apply jobs.
# This prevents launchd jobs from writing tracked bindings in the operator main checkout.
spine_runtime_prepare_managed_worktree() {
  local control_root="$1"
  local runtime_root="${SPINE_RUNTIME_WORKTREE:-$HOME/.wt/agentic-spine/runtime-scheduler}"
  local runtime_branch="${SPINE_RUNTIME_WORKTREE_BRANCH:-runtime/scheduler-projection}"
  local managed_prefix="${SPINE_RUNTIME_MANAGED_PREFIX:-$HOME/.wt/agentic-spine/}"

  if [[ "$managed_prefix" != */ ]]; then
    managed_prefix="${managed_prefix}/"
  fi

  if [[ -z "$control_root" || ! -e "$control_root/.git" ]]; then
    echo "runtime-managed-worktree FAIL: invalid control root: $control_root" >&2
    return 1
  fi

  if [[ "$runtime_root" == "$control_root" ]]; then
    echo "runtime-managed-worktree FAIL: runtime worktree cannot be operator main checkout: $runtime_root" >&2
    return 1
  fi

  case "$runtime_root" in
    "$managed_prefix"*) ;;
    *)
      echo "runtime-managed-worktree FAIL: runtime worktree must be under managed prefix $managed_prefix (got: $runtime_root)" >&2
      return 1
      ;;
  esac

  mkdir -p "$(dirname "$runtime_root")"
  if [[ ! -e "$runtime_root/.git" ]]; then
    if git -C "$control_root" show-ref --verify --quiet "refs/heads/$runtime_branch"; then
      git -C "$control_root" worktree add "$runtime_root" "$runtime_branch" >/dev/null
    else
      git -C "$control_root" worktree add -b "$runtime_branch" "$runtime_root" main >/dev/null
    fi
  fi

  if [[ ! -x "$runtime_root/bin/ops" ]]; then
    echo "runtime-managed-worktree FAIL: missing runtime ops runner at $runtime_root/bin/ops" >&2
    return 1
  fi

  export OPS_WORKTREE_IDENTITY="${OPS_WORKTREE_IDENTITY:-CP-RUNTIME-SCHEDULER}"
  export SPINE_ROOT="$runtime_root"
  printf '%s\n' "$runtime_root"
}
