#!/usr/bin/env bash
set -euo pipefail

spine_launcher_archive_control_worktree_state() {
  local control_root="$1"
  local control_path="$2"
  local reason="$3"
  local runtime_paths="$control_root/ops/lib/runtime-paths.sh"
  local archive_root=""
  local archive_dir=""
  local stamp=""

  [[ -e "$control_path/.git" || -f "$control_path/.git" ]] || return 0
  [[ -r "$runtime_paths" ]] || return 0

  # shellcheck disable=SC1090
  source "$runtime_paths"
  export SPINE_TARGET_REPO="${SPINE_TARGET_REPO:-$control_root}"
  export SPINE_REPO="${SPINE_REPO:-$control_root}"
  export SPINE_CODE="${SPINE_CODE:-$control_root}"
  spine_runtime_resolve_paths >/dev/null 2>&1 || true

  archive_root="$(spine_resolve_mailroom_path 'mailroom/state/quarantine/launcher-control-worktree')"
  stamp="$(date -u +%Y%m%d-%H%M%S)"
  archive_dir="${archive_root}/$(basename "$control_path")-${stamp}-$$-${reason}"
  mkdir -p "$archive_dir"

  git -C "$control_path" status --short --branch >"$archive_dir/status.txt" 2>&1 || true
  git -C "$control_path" diff --binary >"$archive_dir/worktree.diff" 2>&1 || true
  git -C "$control_path" diff --binary --cached >"$archive_dir/index.diff" 2>&1 || true
  git -C "$control_path" ls-files --others --exclude-standard >"$archive_dir/untracked.txt" 2>&1 || true
  git -C "$control_path" ls-files --others -i --exclude-standard >"$archive_dir/ignored.txt" 2>&1 || true
}

spine_launcher_refresh_control_worktree() {
  local control_root="$1"
  local control_path="$2"
  local control_branch="$3"
  local target_ref="$4"
  local reason="$5"

  spine_launcher_archive_control_worktree_state "$control_root" "$control_path" "$reason" || true
  git -C "$control_path" checkout --force -B "$control_branch" "$target_ref" >/dev/null 2>&1 || return 1
  git -C "$control_path" clean -fdx >/dev/null 2>&1 || true
}

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
  local branch=""
  local dirty=""
  local target_ref=""
  local target_head=""
  local current_head=""
  local refresh_reason=""

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

  branch="$(git -C "$control_path" symbolic-ref --short HEAD 2>/dev/null || true)"
  target_ref="$control_base_ref"
  target_head="$(git -C "$control_root" rev-parse -q --verify "${target_ref}^{commit}" 2>/dev/null || true)"
  if [[ -z "$target_head" ]]; then
    target_ref="$main_branch"
    target_head="$(git -C "$control_root" rev-parse -q --verify "${target_ref}^{commit}" 2>/dev/null || true)"
  fi

  dirty="$(git -C "$control_path" status --porcelain 2>/dev/null || true)"
  current_head="$(git -C "$control_path" rev-parse HEAD 2>/dev/null || true)"
  if [[ -z "$branch" ]]; then
    refresh_reason="detached_head"
  elif [[ "$branch" != "$control_branch" ]]; then
    refresh_reason="branch_drift"
  elif [[ -n "$dirty" ]]; then
    refresh_reason="dirty"
  elif [[ -n "$target_head" && -n "$current_head" && "$current_head" != "$target_head" ]]; then
    refresh_reason="stale"
  fi

  if [[ -n "$refresh_reason" ]]; then
    spine_launcher_refresh_control_worktree "$control_root" "$control_path" "$control_branch" "$target_ref" "$refresh_reason" || {
      echo "launcher-control-worktree FAIL: unable to refresh control worktree ($refresh_reason): $control_path" >&2
      return 1
    }
    branch="$(git -C "$control_path" symbolic-ref --short HEAD 2>/dev/null || true)"
    dirty="$(git -C "$control_path" status --porcelain 2>/dev/null || true)"
    current_head="$(git -C "$control_path" rev-parse HEAD 2>/dev/null || true)"
  fi

  [[ -n "$branch" && "$branch" == "$control_branch" ]] || {
    echo "launcher-control-worktree FAIL: control worktree branch drift (expected $control_branch, found ${branch:-<detached>})" >&2
    return 1
  }

  [[ -z "$dirty" ]] || {
    echo "launcher-control-worktree FAIL: control worktree is dirty after refresh: $control_path" >&2
    return 1
  }

  if [[ -n "$target_head" ]]; then
    [[ -n "$current_head" && "$current_head" == "$target_head" ]] || {
      echo "launcher-control-worktree FAIL: control worktree did not converge to $target_ref" >&2
      return 1
    }
  fi

  [[ -x "$control_path/bin/ops" ]] || {
    echo "launcher-control-worktree FAIL: missing ops runner at $control_path/bin/ops" >&2
    return 1
  }

  printf '%s\n' "$control_path"
}
