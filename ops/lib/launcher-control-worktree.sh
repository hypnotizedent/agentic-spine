#!/usr/bin/env bash
set -euo pipefail

spine_runtime_prepare_launcher_control_worktree() {
  local control_root="$1"
  local contract="$control_root/ops/bindings/worktree.lifecycle.contract.yaml"
  local main_branch="main"
  local control_path="${SPINE_LAUNCHER_CONTROL_WORKTREE:-}"
  local control_branch="${SPINE_LAUNCHER_CONTROL_BRANCH:-}"
  local control_base_ref="${SPINE_LAUNCHER_CONTROL_BASE_REF:-}"
  local configured_path=""
  local configured_branch=""
  local configured_base_ref=""

  [[ -n "$control_root" && -e "$control_root/.git" ]] || {
    echo "launcher-control-worktree FAIL: invalid control root: $control_root" >&2
    return 1
  }

  if [[ -f "$contract" ]] && command -v yq >/dev/null 2>&1; then
    main_branch="$(yq e -r '.policy.main_branch // "main"' "$contract" 2>/dev/null || echo "$main_branch")"
    configured_path="$(yq e -r '.policy.launcher_control_worktree_path // ""' "$contract" 2>/dev/null || true)"
    configured_branch="$(yq e -r '.policy.launcher_control_worktree_branch // ""' "$contract" 2>/dev/null || true)"
    configured_base_ref="$(yq e -r '.policy.launcher_control_worktree_base_ref // ""' "$contract" 2>/dev/null || true)"
  fi

  [[ -n "$control_path" ]] || control_path="$configured_path"
  [[ -n "$control_branch" ]] || control_branch="$configured_branch"
  [[ -n "$control_base_ref" ]] || control_base_ref="$configured_base_ref"

  [[ -n "$control_path" ]] || {
    printf '%s\n' "$control_root"
    return 0
  }

  [[ -n "$control_branch" ]] || control_branch="runtime/control-plane"
  [[ -n "$control_base_ref" ]] || control_base_ref="origin/${main_branch}"

  if [[ "$control_path" == "$control_root" ]]; then
    printf '%s\n' "$control_root"
    return 0
  fi

  mkdir -p "$(dirname "$control_path")"

  if [[ ! -e "$control_path/.git" ]]; then
    local add_ref="$control_base_ref"
    if ! git -C "$control_root" rev-parse -q --verify "${add_ref}^{commit}" >/dev/null 2>&1; then
      add_ref="$main_branch"
    fi
    if git -C "$control_root" show-ref --verify --quiet "refs/heads/$control_branch"; then
      git -C "$control_root" worktree add "$control_path" "$control_branch" >/dev/null
    else
      git -C "$control_root" worktree add -b "$control_branch" "$control_path" "$add_ref" >/dev/null
    fi
  fi

  git -C "$control_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "launcher-control-worktree FAIL: resolved control worktree is not a git checkout: $control_path" >&2
    return 1
  }

  local branch
  branch="$(git -C "$control_path" symbolic-ref --short HEAD 2>/dev/null || true)"
  if [[ -n "$branch" && "$branch" != "$control_branch" ]]; then
    echo "launcher-control-worktree FAIL: control worktree branch drift (expected $control_branch, found $branch)" >&2
    return 1
  fi

  if [[ -n "$(git -C "$control_path" status --porcelain 2>/dev/null || true)" ]]; then
    echo "launcher-control-worktree FAIL: control worktree is dirty: $control_path" >&2
    return 1
  fi

  local target_ref="$control_base_ref"
  local target_head=""
  target_head="$(git -C "$control_root" rev-parse -q --verify "${target_ref}^{commit}" 2>/dev/null || true)"
  if [[ -z "$target_head" ]]; then
    target_ref="$main_branch"
    target_head="$(git -C "$control_root" rev-parse -q --verify "${target_ref}^{commit}" 2>/dev/null || true)"
  fi

  if [[ -n "$target_head" ]]; then
    local current_head=""
    current_head="$(git -C "$control_path" rev-parse HEAD 2>/dev/null || true)"
    if [[ -n "$current_head" && "$current_head" != "$target_head" ]]; then
      if git -C "$control_path" merge-base --is-ancestor "$current_head" "$target_head" >/dev/null 2>&1; then
        git -C "$control_path" merge --ff-only "$target_head" >/dev/null
      else
        echo "launcher-control-worktree FAIL: control worktree is not fast-forwardable to $target_ref" >&2
        return 1
      fi
    fi
  fi

  [[ -x "$control_path/bin/ops" ]] || {
    echo "launcher-control-worktree FAIL: missing ops runner at $control_path/bin/ops" >&2
    return 1
  }

  printf '%s\n' "$control_path"
}
