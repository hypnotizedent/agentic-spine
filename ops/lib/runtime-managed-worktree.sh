#!/usr/bin/env bash
set -euo pipefail

# Resolve or create managed runtime worktree for scheduled projection apply jobs.
# This prevents launchd jobs from writing tracked bindings in the operator main checkout.
spine_runtime_resolve_control_root() {
  local script_path="${1:-}"
  local cwd_root=""
  local script_root=""
  local env_name=""
  local value=""
  local probe=""

  cwd_root="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$cwd_root" && -f "$cwd_root/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$cwd_root"
    return 0
  fi

  if [[ -n "$script_path" ]]; then
    if [[ -d "$script_path" ]]; then
      probe="$script_path"
    else
      probe="$(dirname "$script_path")"
    fi
    script_root="$(git -C "$probe" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$script_root" && -f "$script_root/ops/capabilities.yaml" ]]; then
      printf '%s\n' "$script_root"
      return 0
    fi
  fi

  for env_name in SPINE_TARGET_REPO SPINE_ROOT SPINE_REPO SPINE_CODE; do
    value="${!env_name:-}"
    if [[ -z "$value" ]]; then
      continue
    fi
    if value="$(cd "$value" 2>/dev/null && pwd -P)"; then
      if [[ -f "$value/ops/capabilities.yaml" ]]; then
        printf '%s\n' "$value"
        return 0
      fi
    fi
  done

  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

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
  printf '%s\n' "$runtime_root"
}

spine_runtime_activate_managed_worktree() {
  local control_root="$1"
  local runtime_root=""

  runtime_root="$(spine_runtime_prepare_managed_worktree "$control_root")" || return 1

  export SPINE_CONTROL_ROOT="${SPINE_CONTROL_ROOT:-$control_root}"
  export SPINE_RUNTIME_ACTIVE_ROOT="$runtime_root"
  export SPINE_ROOT="$runtime_root"
  export SPINE_TARGET_REPO="$runtime_root"
  export SPINE_REPO="$runtime_root"
  export SPINE_CODE="$runtime_root"

  cd "$runtime_root"
}

spine_runtime_refresh_managed_worktree() {
  local control_root="$1"
  local runtime_root="${SPINE_RUNTIME_ACTIVE_ROOT:-}"
  local runtime_branch="${SPINE_RUNTIME_WORKTREE_BRANCH:-runtime/scheduler-projection}"
  local contract="$control_root/ops/bindings/worktree.lifecycle.contract.yaml"
  local main_branch="main"
  local target_ref=""

  if [[ -f "$contract" ]] && command -v yq >/dev/null 2>&1; then
    main_branch="$(yq e -r '.policy.main_branch // "main"' "$contract" 2>/dev/null || echo "$main_branch")"
  fi

  if [[ -z "$runtime_root" ]]; then
    runtime_root="$(spine_runtime_prepare_managed_worktree "$control_root")" || return 1
  fi

  target_ref="origin/${main_branch}"
  if ! git -C "$runtime_root" rev-parse -q --verify "${target_ref}^{commit}" >/dev/null 2>&1; then
    target_ref="$main_branch"
  fi

  git -C "$runtime_root" checkout --force -B "$runtime_branch" "$target_ref" >/dev/null 2>&1 || return 1
  git -C "$runtime_root" clean -fdx >/dev/null 2>&1 || true
  printf '%s\n' "$runtime_root"
}
