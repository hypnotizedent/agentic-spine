#!/usr/bin/env bash
set -euo pipefail

CODEX_WORKTREE_MAX=${CODEX_WORKTREE_MAX:-2}
SPINE_CODE=${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
SPINE_REPO=${SPINE_REPO:-$(git -C "$SPINE_CODE" rev-parse --show-toplevel)}

worktree_list=()
declare -A worktree_branch
current_path=""

while IFS= read -r line; do
  key=${line%% *}
  value=${line#* }
  if [[ $key == "worktree" ]]; then
    current_path=$value
    worktree_list+=("$value")
  elif [[ $key == "branch" && -n $current_path ]]; then
    worktree_branch["$current_path"]="$value"
  fi
done < <(git -C "$SPINE_REPO" worktree list --porcelain)

codex_paths=()
for path in "${worktree_list[@]}"; do
  [[ $path == "$SPINE_REPO" ]] && continue
  basename=$(basename "$path")
  [[ $basename == codex-* ]] || continue
  codex_paths+=("$path")
done

failures=()
codex_count=${#codex_paths[@]}

for path in "${codex_paths[@]}"; do
  branch=${worktree_branch["$path"]}
  # Porcelain gives refs/heads/...; strip to short name for git branch --list / rev-parse
  branch="${branch#refs/heads/}"
  if [[ -z $branch ]]; then
    branch=$(git -C "$path" symbolic-ref --short HEAD 2>/dev/null || echo "<detached>")
  fi

  status_msgs=()
  if [[ $branch != "<detached>" ]]; then
    if git -C "$SPINE_REPO" branch --merged main --list "$branch" 2>/dev/null | grep -q .; then
      status_msgs+=("stale (merged into main)")
    fi
    # rev-parse prints the resolved SHA to stdout; silence it since this is a gate script.
    if ! git -C "$SPINE_REPO" rev-parse --verify --quiet "origin/$branch" >/dev/null 2>&1; then
      status_msgs+=("orphaned (no remote origin/$branch)")
    fi
  else
    status_msgs+=("detached HEAD")
  fi

  if [[ -n $(git -C "$path" status --porcelain) ]]; then
    status_msgs+=("dirty (uncommitted changes)")
  fi

  if [[ ${#status_msgs[@]} -gt 0 ]]; then
    failures+=("$(basename "$path"): ${branch:-unknown} -> ${status_msgs[*]}")
  fi
done

if (( codex_count > CODEX_WORKTREE_MAX )); then
  failures+=("threshold breach: $codex_count codex worktrees (max $CODEX_WORKTREE_MAX)")
fi

if (( ${#failures[@]} > 0 )); then
  echo "Detected codex worktree issues (max=$CODEX_WORKTREE_MAX):"
  for entry in "${failures[@]}"; do
    echo "  - $entry"
  done
  exit 1
fi

# ── Stash audit ───────────────────────────────────────────────────────────
# Flag stashes whose parent branch is merged into main or no longer exists.
stash_count=0
orphaned_stashes=()
while IFS= read -r stash_line; do
  [[ -z "$stash_line" ]] && continue
  stash_count=$((stash_count + 1))
  # Extract branch name from "stash@{N}: On <branch>: <message>" or "stash@{N}: WIP on <branch>: <sha> <msg>"
  stash_ref="${stash_line%%:*}"
  branch_part="${stash_line#*On }"
  stash_branch="${branch_part%%:*}"
  [[ -z "$stash_branch" ]] && continue

  reason=""
  if ! git -C "$SPINE_REPO" rev-parse --verify --quiet "refs/heads/$stash_branch" >/dev/null 2>&1; then
    reason="branch gone"
  elif git -C "$SPINE_REPO" branch --merged main --list "$stash_branch" 2>/dev/null | grep -q .; then
    reason="branch merged"
  fi

  if [[ -n "$reason" ]]; then
    orphaned_stashes+=("$stash_ref ($stash_branch): $reason")
  fi
done < <(git -C "$SPINE_REPO" stash list 2>/dev/null)

if (( ${#orphaned_stashes[@]} > 0 )); then
  echo "Orphaned stashes detected (${#orphaned_stashes[@]} of $stash_count):"
  for entry in "${orphaned_stashes[@]}"; do
    echo "  - $entry"
  done
  echo "Fix: git stash drop <ref> for each orphaned entry"
  exit 1
fi

echo "Codex worktrees clean (count=$codex_count, max=$CODEX_WORKTREE_MAX). Stashes: $stash_count (0 orphaned)."
