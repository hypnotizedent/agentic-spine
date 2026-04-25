#!/usr/bin/env bash
set -euo pipefail

# Canonical path resolver shim for plugin/runtime scripts.
# Standard usage:
#   source "$SPINE_ROOT/ops/lib/spine-paths.sh"
#   spine_paths_init
#   # SPINE_* runtime/evidence/data roots now exported

_SP_PATHS_LIB_DIR="${BASH_SOURCE%/*}"
[[ "$_SP_PATHS_LIB_DIR" == "${BASH_SOURCE}" ]] && _SP_PATHS_LIB_DIR="$(pwd)"
source "$_SP_PATHS_LIB_DIR/runtime-paths.sh"

spine_paths_init() {
  spine_runtime_resolve_paths
  export \
    SPINE_TARGET_REPO \
    SPINE_WORKSPACE_ROOT \
    SPINE_RUNTIME_ROOT \
    SPINE_MAILROOM_ROOT \
    SPINE_INBOX \
    SPINE_OUTBOX \
    SPINE_STATE \
    SPINE_LOCKS \
    SPINE_LOGS \
    SPINE_TMP \
    SPINE_EVIDENCE_ROOT \
    SPINE_RECEIPTS \
    SPINE_VERIFY_ROOT \
    SPINE_CAP_RUNS_ROOT \
    SPINE_DATA_ROOT \
    SPINE_BACKUPS_ROOT \
    SPINE_FOUNDATION_ROOT \
    SPINE_DOMAIN_STATE
}

spine_expand_home() {
  local raw="${1:-}"
  case "$raw" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${raw#~/}" ;;
    *) printf '%s\n' "$raw" ;;
  esac
}

spine_git_common_dir() {
  local path="${1:-$PWD}"
  local common_dir=""
  if git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    common_dir="$(git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  fi
  if [[ -n "$common_dir" ]]; then
    printf '%s\n' "$common_dir"
    return 0
  fi
  git -C "$path" rev-parse --path-format=absolute --git-dir 2>/dev/null || true
}

spine_git_common_root() {
  local path="${1:-$PWD}"
  local common_dir=""
  common_dir="$(spine_git_common_dir "$path")"
  if [[ -n "$common_dir" ]]; then
    dirname "$common_dir"
    return 0
  fi
  git -C "$path" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$path"
}

spine_same_git_family() {
  local left="${1:-}"
  local right="${2:-}"
  local left_common="" right_common=""
  [[ -n "$left" && -n "$right" ]] || return 1
  left_common="$(spine_git_common_dir "$left")"
  right_common="$(spine_git_common_dir "$right")"
  [[ -n "$left_common" && "$left_common" == "$right_common" ]]
}

spine_preferred_governed_checkout() {
  local repo_root="${1:-}"
  local candidate="${2:-$PWD}"
  local candidate_top=""
  if [[ -n "$candidate" ]]; then
    candidate_top="$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  if [[ -n "$repo_root" && -n "$candidate_top" ]] && spine_same_git_family "$repo_root" "$candidate_top"; then
    printf '%s\n' "$candidate_top"
    return 0
  fi
  printf '%s\n' "$repo_root"
}

spine_canonical_worktree_root() {
  local repo_path="${1:-$PWD}"
  local contract_path="${2:-}"
  local canonical_root="$SPINE_RUNTIME/spine/tmp/worktrees"
  if [[ -z "$contract_path" ]]; then
    contract_path="$(spine_git_common_root "$repo_path")/ops/bindings/worktree.lifecycle.contract.yaml"
  fi
  if command -v yq >/dev/null 2>&1 && [[ -f "$contract_path" ]]; then
    canonical_root="$(yq e -r '.policy.canonical_worktree_root // "$SPINE_RUNTIME/spine/tmp/worktrees"' "$contract_path" 2>/dev/null || echo "$canonical_root")"
  fi
  spine_expand_home "$canonical_root"
}

spine_canonical_worktree_prefix() {
  local repo_path="${1:-$PWD}"
  local contract_path="${2:-}"
  local canonical_root=""
  local repo_root=""
  local repo_name=""
  canonical_root="$(spine_canonical_worktree_root "$repo_path" "$contract_path")"
  repo_root="$(spine_git_common_root "$repo_path")"
  repo_name="$(basename "$repo_root")"
  [[ -n "$repo_name" ]] || repo_name="agentic-spine"
  printf '%s/%s/\n' "${canonical_root%/}" "$repo_name"
}

spine_ensure_git_exclude() {
  local worktree_path="${1:-}"
  local pattern="${2:-}"
  local git_dir="" exclude_file=""
  [[ -n "$worktree_path" && -n "$pattern" ]] || return 0
  git_dir="$(git -C "$worktree_path" rev-parse --path-format=absolute --git-dir 2>/dev/null || true)"
  [[ -n "$git_dir" ]] || return 0
  exclude_file="$git_dir/info/exclude"
  mkdir -p "$(dirname "$exclude_file")"
  touch "$exclude_file"
  grep -Fqx -- "$pattern" "$exclude_file" 2>/dev/null && return 0
  printf '\n%s\n' "$pattern" >> "$exclude_file"
}
