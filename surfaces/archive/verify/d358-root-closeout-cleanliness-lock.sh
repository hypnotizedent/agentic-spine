#!/usr/bin/env bash
# TRIAGE: keep root mainline tracked changes limited to explicit runtime/session allowlist.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/nightly.closeout.contract.yaml"

fail() { echo "D358 FAIL: $*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || fail "git missing"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"

resolve_root_repo() {
  local explicit contract_root wt_path wt_branch

  explicit="${D358_ROOT_REPO:-}"
  if [[ -n "$explicit" ]]; then
    echo "$explicit"
    return 0
  fi

  if command -v yq >/dev/null 2>&1; then
    contract_root="$(yq e -r '.clean_root_guard.root_repo_path // ""' "$CONTRACT" 2>/dev/null || true)"
    if [[ -n "$contract_root" && "$contract_root" != "null" ]]; then
      echo "$contract_root"
      return 0
    fi
  fi

  if git -C "$ROOT" worktree list --porcelain >/dev/null 2>&1; then
    while IFS= read -r line; do
      case "$line" in
        worktree\ *)
          wt_path="${line#worktree }"
          ;;
        branch\ refs/heads/*)
          wt_branch="${line#branch refs/heads/}"
          if [[ "$wt_branch" == "main" && -n "$wt_path" ]]; then
            echo "$wt_path"
            return 0
          fi
          ;;
      esac
    done < <(git -C "$ROOT" worktree list --porcelain)
  fi

  echo "$ROOT"
}

target_repo="$(resolve_root_repo)"
[[ -n "$target_repo" && -d "$target_repo" ]] || fail "resolved root repo path does not exist: $target_repo"
git -C "$target_repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "target root is not a git worktree: $target_repo"

declare -a allow_exact=()
declare -a allow_glob=()
while IFS= read -r row; do
  [[ -n "$row" && "$row" != "null" ]] && allow_exact+=("$row")
done < <(yq e -r '.clean_root_guard.tracked_dirty_allowlist[]?' "$CONTRACT" 2>/dev/null || true)
while IFS= read -r row; do
  [[ -n "$row" && "$row" != "null" ]] && allow_glob+=("$row")
done < <(yq e -r '.clean_root_guard.tracked_dirty_allowlist_globs[]?' "$CONTRACT" 2>/dev/null || true)

declare -a dirty_paths=()
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  path="${line:3}"
  if [[ "$path" == *" -> "* ]]; then
    path="${path##* -> }"
  fi
  [[ -n "$path" ]] || continue
  dirty_paths+=("$path")
done < <(git -C "$target_repo" status --porcelain --untracked-files=no 2>/dev/null | sort -u)

if (( ${#dirty_paths[@]} == 0 )); then
  echo "D358 PASS: root closeout cleanliness lock (root repo clean: $target_repo)"
  exit 0
fi

is_allowlisted() {
  local candidate="$1"
  local item
  for item in "${allow_exact[@]}"; do
    [[ "$candidate" == "$item" ]] && return 0
  done
  for item in "${allow_glob[@]}"; do
    [[ "$candidate" == $item ]] && return 0
  done
  return 1
}

declare -a violations=()
for candidate in "${dirty_paths[@]}"; do
  if ! is_allowlisted "$candidate"; then
    violations+=("$candidate")
  fi
done

if (( ${#violations[@]} > 0 )); then
  echo "D358 FAIL: root closeout cleanliness lock" >&2
  echo "  root_repo: $target_repo" >&2
  echo "  offending_tracked_paths:" >&2
  for path in "${violations[@]}"; do
    echo "    - $path" >&2
  done
  echo "  allowlisted_tracked_dirty_paths:" >&2
  if (( ${#allow_exact[@]} > 0 )); then
    for path in "${allow_exact[@]}"; do
      echo "    - $path" >&2
    done
  fi
  if (( ${#allow_glob[@]} > 0 )); then
    for path in "${allow_glob[@]}"; do
      echo "    - $path" >&2
    done
  fi
  exit 1
fi

echo "D358 PASS: root closeout cleanliness lock (allowlisted tracked dirt only: ${#dirty_paths[@]} path(s))"
