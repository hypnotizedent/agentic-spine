#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/nightly.closeout.contract.yaml"
MODE=""

usage() {
  cat <<'USAGE'
Usage: nightly-closeout.sh [--mode dry-run|apply]

Modes:
  --mode dry-run   Classify only, no destructive changes.
  --mode apply     Snapshot first, then prune only non-protected candidates.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --) shift ;;
    --mode) MODE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

DEFAULT_MODE="dry-run"
REQUIRE_DRY_RUN_BEFORE_APPLY="true"
if command -v yq >/dev/null 2>&1 && [[ -f "$CONTRACT" ]]; then
  DEFAULT_MODE="$(yq e -r '.entrypoint.mode_default // "dry-run"' "$CONTRACT" 2>/dev/null || echo "dry-run")"
  REQUIRE_DRY_RUN_BEFORE_APPLY="$(yq e -r '.safety.require_dry_run_before_apply // true' "$CONTRACT" 2>/dev/null || echo "true")"
fi
[[ -n "$MODE" ]] || MODE="$DEFAULT_MODE"
case "$MODE" in
  dry-run|apply) ;;
  *) echo "FAIL: --mode must be dry-run or apply (got '$MODE')" >&2; exit 2 ;;
esac

RUN_UTC="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_ID="NIGHTLY-CLOSEOUT-${RUN_UTC}-${$}"
ARTIFACT_DIR="$ROOT/receipts/nightly-closeout/$RUN_ID"
mkdir -p "$ARTIFACT_DIR"

if [[ "$MODE" == "apply" && "$REQUIRE_DRY_RUN_BEFORE_APPLY" == "true" ]]; then
  found_dry_run=0
  if [[ -d "$ROOT/receipts/nightly-closeout" ]]; then
    while IFS= read -r env_file; do
      if grep -q '^mode=dry-run$' "$env_file" 2>/dev/null; then
        found_dry_run=1
      fi
    done < <(find "$ROOT/receipts/nightly-closeout" -type f -name summary.env 2>/dev/null | sort)
  fi
  if [[ "$found_dry_run" -ne 1 ]]; then
    echo "FAIL: apply mode requires a prior dry-run receipt (none found under receipts/nightly-closeout)" >&2
    exit 1
  fi
fi

PROTECTED_LOOPS=("LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226")
PROTECTED_GAPS=("GAP-OP-973")
PROTECTED_RUNTIME_LANES=("ews-import" "md1400-rsync")
PROTECTED_BRANCH_REGEXES=("^main$" "^codex/cleanup-night-snapshot-.*$")
PROTECTED_WORKTREE_GLOBS=("mailroom/state/loop-scopes/LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226.scope.md" "docs/planning/MD1400_*")
SNAPSHOT_ROOT="/Users/ronnyworks/code/_closeout_backups"

if command -v yq >/dev/null 2>&1 && [[ -f "$CONTRACT" ]]; then
  PROTECTED_LOOPS=()
  while IFS= read -r row; do
    [[ -n "$row" && "$row" != "null" ]] && PROTECTED_LOOPS+=("$row")
  done < <(yq e -r '.protected_scope.loops[]?' "$CONTRACT" 2>/dev/null || true)

  PROTECTED_GAPS=()
  while IFS= read -r row; do
    [[ -n "$row" && "$row" != "null" ]] && PROTECTED_GAPS+=("$row")
  done < <(yq e -r '.protected_scope.gaps[]?' "$CONTRACT" 2>/dev/null || true)

  PROTECTED_RUNTIME_LANES=()
  while IFS= read -r row; do
    [[ -n "$row" && "$row" != "null" ]] && PROTECTED_RUNTIME_LANES+=("$row")
  done < <(yq e -r '.protected_scope.runtime_lanes[]?' "$CONTRACT" 2>/dev/null || true)

  PROTECTED_BRANCH_REGEXES=()
  while IFS= read -r row; do
    [[ -n "$row" && "$row" != "null" ]] && PROTECTED_BRANCH_REGEXES+=("$row")
  done < <(yq e -r '.protected_scope.branch_regexes[]?' "$CONTRACT" 2>/dev/null || true)

  PROTECTED_WORKTREE_GLOBS=()
  while IFS= read -r row; do
    [[ -n "$row" && "$row" != "null" ]] && PROTECTED_WORKTREE_GLOBS+=("$row")
  done < <(yq e -r '.protected_scope.file_globs[]?' "$CONTRACT" 2>/dev/null || true)

  SNAPSHOT_ROOT="$(yq e -r '.snapshot_policy.output_root // "/Users/ronnyworks/code/_closeout_backups"' "$CONTRACT" 2>/dev/null || echo "/Users/ronnyworks/code/_closeout_backups")"
fi

# Conservative fallback if contract parsing produced empty lists.
[[ "${#PROTECTED_BRANCH_REGEXES[@]}" -gt 0 ]] || PROTECTED_BRANCH_REGEXES=("^main$" "^codex/cleanup-night-snapshot-.*$")
[[ "${#PROTECTED_RUNTIME_LANES[@]}" -gt 0 ]] || PROTECTED_RUNTIME_LANES=("ews-import" "md1400-rsync")

OPEN_LOOP_IDS=()
if [[ -d "$ROOT/mailroom/state/loop-scopes" ]]; then
  while IFS= read -r scope_file; do
    [[ -f "$scope_file" ]] || continue
    loop_id="$(sed -nE 's/^loop_id:[[:space:]]*"?([^"]+)"?/\1/p' "$scope_file" | head -1)"
    [[ -n "$loop_id" ]] || loop_id="$(basename "$scope_file" .scope.md)"
    loop_status="$(sed -nE 's/^status:[[:space:]]*"?([^"]+)"?/\1/p' "$scope_file" | head -1 | tr '[:upper:]' '[:lower:]')"
    [[ -n "$loop_status" ]] || loop_status="unknown"
    if [[ "$loop_status" != "closed" ]]; then
      OPEN_LOOP_IDS+=("$loop_id")
    fi
  done < <(find "$ROOT/mailroom/state/loop-scopes" -maxdepth 1 -type f -name 'LOOP-*.scope.md' | sort)
fi

PROTECTED_TOKENS=()
for item in "${PROTECTED_LOOPS[@]}" "${PROTECTED_GAPS[@]}" "${PROTECTED_RUNTIME_LANES[@]}"; do
  [[ -n "$item" ]] && PROTECTED_TOKENS+=("$item")
done
for item in "${OPEN_LOOP_IDS[@]}"; do
  [[ -n "$item" ]] && PROTECTED_TOKENS+=("$item")
done
PROTECTED_TOKENS+=("ews" "md1400")

INVENTORY_MD="$ARTIFACT_DIR/inventory.md"
CLASSIFICATION_MD="$ARTIFACT_DIR/classification.md"
ACTIONS_LOG="$ARTIFACT_DIR/actions.log"
SUMMARY_MD="$ARTIFACT_DIR/summary.md"
SUMMARY_ENV="$ARTIFACT_DIR/summary.env"

LOCAL_BRANCHES_FILE="$ARTIFACT_DIR/local_branches.txt"
ORIGIN_CODEX_FILE="$ARTIFACT_DIR/remote_origin_codex.txt"
GITHUB_CODEX_FILE="$ARTIFACT_DIR/remote_github_codex.txt"
WORKTREE_PORCELAIN_FILE="$ARTIFACT_DIR/worktrees.porcelain.txt"

git -C "$ROOT" for-each-ref refs/heads --format='%(refname:short)' > "$LOCAL_BRANCHES_FILE"
git -C "$ROOT" for-each-ref refs/remotes/origin/codex --format='%(refname:short)' 2>/dev/null | sed 's#^origin/##' > "$ORIGIN_CODEX_FILE" || true
git -C "$ROOT" for-each-ref refs/remotes/github/codex --format='%(refname:short)' 2>/dev/null | sed 's#^github/##' > "$GITHUB_CODEX_FILE" || true
git -C "$ROOT" worktree list --porcelain > "$WORKTREE_PORCELAIN_FILE"

count_nonempty_file_lines() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo 0
    return
  fi
  sed '/^[[:space:]]*$/d' "$file" | wc -l | tr -d ' '
}

to_lower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

matches_protected_token() {
  local raw="$1"
  local text
  text="$(to_lower "$raw")"
  local token token_lc
  for token in "${PROTECTED_TOKENS[@]}"; do
    token_lc="$(to_lower "$token")"
    [[ -z "$token_lc" ]] && continue
    if [[ "$text" == *"$token_lc"* ]]; then
      return 0
    fi
  done
  return 1
}

matches_protected_branch_regex() {
  local branch="$1"
  local regex
  for regex in "${PROTECTED_BRANCH_REGEXES[@]}"; do
    if [[ "$branch" =~ $regex ]]; then
      return 0
    fi
  done
  return 1
}

CURRENT_BRANCH="$(git -C "$ROOT" branch --show-current)"
ROOT_WORKTREE_COUNT="$(grep -c '^worktree ' "$WORKTREE_PORCELAIN_FILE" || true)"
LOCAL_BRANCH_COUNT_BEFORE="$(count_nonempty_file_lines "$LOCAL_BRANCHES_FILE")"
ORIGIN_CODEX_COUNT_BEFORE="$(count_nonempty_file_lines "$ORIGIN_CODEX_FILE")"
GITHUB_CODEX_COUNT_BEFORE="$(count_nonempty_file_lines "$GITHUB_CODEX_FILE")"

WORKTREE_PATHS=()
WORKTREE_BRANCHES=()
CHECKED_OUT_BRANCHES=()
{
  current_path=""
  current_branch=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" ]]; then
      if [[ -n "$current_path" ]]; then
        WORKTREE_PATHS+=("$current_path")
        WORKTREE_BRANCHES+=("${current_branch:-<detached>}")
        if [[ -n "$current_branch" && "$current_branch" != "<detached>" ]]; then
          CHECKED_OUT_BRANCHES+=("$current_branch")
        fi
      fi
      current_path=""
      current_branch=""
      continue
    fi
    case "$line" in
      worktree\ *)
        current_path="${line#worktree }"
        ;;
      branch\ refs/heads/*)
        current_branch="${line#branch refs/heads/}"
        ;;
      branch\ *)
        current_branch="${line#branch }"
        ;;
    esac
  done
  if [[ -n "$current_path" ]]; then
    WORKTREE_PATHS+=("$current_path")
    WORKTREE_BRANCHES+=("${current_branch:-<detached>}")
    if [[ -n "$current_branch" && "$current_branch" != "<detached>" ]]; then
      CHECKED_OUT_BRANCHES+=("$current_branch")
    fi
  fi
} < "$WORKTREE_PORCELAIN_FILE"

branch_checked_out_anywhere() {
  local branch="$1"
  local item
  for item in "${CHECKED_OUT_BRANCHES[@]}"; do
    [[ "$item" == "$branch" ]] && return 0
  done
  return 1
}

branch_is_protected() {
  local branch="$1"
  matches_protected_branch_regex "$branch" && return 0
  branch_checked_out_anywhere "$branch" && return 0
  matches_protected_token "$branch" && return 0
  return 1
}

worktree_matches_protected_glob() {
  local path="$1"
  local rel="$path"
  if [[ "$path" == "$ROOT/"* ]]; then
    rel="${path#"$ROOT"/}"
  fi
  local glob
  for glob in "${PROTECTED_WORKTREE_GLOBS[@]}"; do
    [[ -z "$glob" ]] && continue
    if [[ "$rel" == $glob ]]; then
      return 0
    fi
  done
  return 1
}

LOCAL_BRANCH_PROTECTED=()
LOCAL_BRANCH_CANDIDATES=()
LOCAL_BRANCH_HELD=()

while IFS= read -r branch; do
  [[ -z "$branch" ]] && continue
  if branch_is_protected "$branch"; then
    LOCAL_BRANCH_PROTECTED+=("$branch|protected-scope")
    continue
  fi
  if [[ "$branch" != codex/* && "$branch" != orchestration/* ]]; then
    LOCAL_BRANCH_HELD+=("$branch|non-lifecycle-branch")
    continue
  fi
  if git -C "$ROOT" merge-base --is-ancestor "$branch" main >/dev/null 2>&1; then
    LOCAL_BRANCH_CANDIDATES+=("$branch|merged-into-main")
  else
    LOCAL_BRANCH_HELD+=("$branch|not-merged-into-main")
  fi
done < "$LOCAL_BRANCHES_FILE"

REMOTE_ORIGIN_PROTECTED=()
REMOTE_ORIGIN_CANDIDATES=()
REMOTE_ORIGIN_HELD=()
REMOTE_GITHUB_PROTECTED=()
REMOTE_GITHUB_CANDIDATES=()
REMOTE_GITHUB_HELD=()

classify_remote_codex() {
  local remote="$1"
  local file="$2"
  local branch
  while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    if branch_is_protected "$branch"; then
      if [[ "$remote" == "origin" ]]; then
        REMOTE_ORIGIN_PROTECTED+=("$branch|protected-scope")
      else
        REMOTE_GITHUB_PROTECTED+=("$branch|protected-scope")
      fi
      continue
    fi
    if [[ "$branch" != codex/* ]]; then
      if [[ "$remote" == "origin" ]]; then
        REMOTE_ORIGIN_HELD+=("$branch|non-codex-remote")
      else
        REMOTE_GITHUB_HELD+=("$branch|non-codex-remote")
      fi
      continue
    fi
    if git -C "$ROOT" merge-base --is-ancestor "refs/remotes/$remote/$branch" main >/dev/null 2>&1; then
      if [[ "$remote" == "origin" ]]; then
        REMOTE_ORIGIN_CANDIDATES+=("$branch|merged-into-main")
      else
        REMOTE_GITHUB_CANDIDATES+=("$branch|merged-into-main")
      fi
    else
      if [[ "$remote" == "origin" ]]; then
        REMOTE_ORIGIN_HELD+=("$branch|not-merged-into-main")
      else
        REMOTE_GITHUB_HELD+=("$branch|not-merged-into-main")
      fi
    fi
  done < "$file"
}

classify_remote_codex origin "$ORIGIN_CODEX_FILE"
classify_remote_codex github "$GITHUB_CODEX_FILE"

WORKTREE_PROTECTED=()
WORKTREE_CANDIDATES=()
WORKTREE_HELD=()
REGISTERED_PATHS=()

idx=0
while [[ "$idx" -lt "${#WORKTREE_PATHS[@]}" ]]; do
  wt_path="${WORKTREE_PATHS[$idx]}"
  wt_branch="${WORKTREE_BRANCHES[$idx]}"
  REGISTERED_PATHS+=("$wt_path")

  if [[ "$wt_path" == "$ROOT" ]]; then
    idx=$((idx + 1))
    continue
  fi

  if worktree_matches_protected_glob "$wt_path" || matches_protected_token "$wt_path" || matches_protected_token "$wt_branch"; then
    WORKTREE_PROTECTED+=("$wt_path|$wt_branch|protected-scope")
    idx=$((idx + 1))
    continue
  fi

  if [[ "$wt_branch" == "<detached>" ]]; then
    WORKTREE_HELD+=("$wt_path|$wt_branch|detached-head")
    idx=$((idx + 1))
    continue
  fi

  wt_dirty=0
  if [[ -d "$wt_path" ]] && [[ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null || true)" ]]; then
    wt_dirty=1
  fi
  if [[ "$wt_dirty" -eq 1 ]]; then
    WORKTREE_HELD+=("$wt_path|$wt_branch|dirty")
    idx=$((idx + 1))
    continue
  fi

  if git -C "$ROOT" merge-base --is-ancestor "$wt_branch" main >/dev/null 2>&1; then
    WORKTREE_CANDIDATES+=("$wt_path|$wt_branch|merged-into-main")
  else
    WORKTREE_HELD+=("$wt_path|$wt_branch|not-merged-into-main")
  fi
  idx=$((idx + 1))
done

STALE_PATHS_CANDIDATES=()
STALE_PATHS_PROTECTED=()
if [[ -d "$ROOT/.worktrees" ]]; then
  while IFS= read -r stale_path; do
    [[ -z "$stale_path" ]] && continue
    registered=0
    for reg in "${REGISTERED_PATHS[@]}"; do
      if [[ "$reg" == "$stale_path" ]]; then
        registered=1
        break
      fi
    done
    if [[ "$registered" -eq 1 ]]; then
      continue
    fi
    if matches_protected_token "$stale_path"; then
      STALE_PATHS_PROTECTED+=("$stale_path|protected-scope")
    else
      STALE_PATHS_CANDIDATES+=("$stale_path|unregistered-path")
    fi
  done < <(find "$ROOT/.worktrees" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
fi

{
  echo "# Nightly Closeout Inventory"
  echo "- run_id: $RUN_ID"
  echo "- mode: $MODE"
  echo "- repo: $ROOT"
  echo "- head_branch: $CURRENT_BRANCH"
  echo "- head_sha: $(git -C "$ROOT" rev-parse HEAD)"
  echo "- worktrees_count: $ROOT_WORKTREE_COUNT"
  echo "- local_branches_count: $LOCAL_BRANCH_COUNT_BEFORE"
  echo "- remote_codex_origin_count: $ORIGIN_CODEX_COUNT_BEFORE"
  echo "- remote_codex_github_count: $GITHUB_CODEX_COUNT_BEFORE"
} > "$INVENTORY_MD"

list_to_file() {
  local file="$1"
  shift
  : > "$file"
  local item
  for item in "$@"; do
    echo "$item" >> "$file"
  done
}

list_to_file "$ARTIFACT_DIR/local_branch_protected.txt" "${LOCAL_BRANCH_PROTECTED[@]}"
list_to_file "$ARTIFACT_DIR/local_branch_candidates.txt" "${LOCAL_BRANCH_CANDIDATES[@]}"
list_to_file "$ARTIFACT_DIR/local_branch_held.txt" "${LOCAL_BRANCH_HELD[@]}"
list_to_file "$ARTIFACT_DIR/worktree_protected.txt" "${WORKTREE_PROTECTED[@]}"
list_to_file "$ARTIFACT_DIR/worktree_candidates.txt" "${WORKTREE_CANDIDATES[@]}"
list_to_file "$ARTIFACT_DIR/worktree_held.txt" "${WORKTREE_HELD[@]}"
list_to_file "$ARTIFACT_DIR/stale_paths_candidates.txt" "${STALE_PATHS_CANDIDATES[@]}"
list_to_file "$ARTIFACT_DIR/stale_paths_protected.txt" "${STALE_PATHS_PROTECTED[@]}"
list_to_file "$ARTIFACT_DIR/remote_origin_candidates.txt" "${REMOTE_ORIGIN_CANDIDATES[@]}"
list_to_file "$ARTIFACT_DIR/remote_origin_protected.txt" "${REMOTE_ORIGIN_PROTECTED[@]}"
list_to_file "$ARTIFACT_DIR/remote_origin_held.txt" "${REMOTE_ORIGIN_HELD[@]}"
list_to_file "$ARTIFACT_DIR/remote_github_candidates.txt" "${REMOTE_GITHUB_CANDIDATES[@]}"
list_to_file "$ARTIFACT_DIR/remote_github_protected.txt" "${REMOTE_GITHUB_PROTECTED[@]}"
list_to_file "$ARTIFACT_DIR/remote_github_held.txt" "${REMOTE_GITHUB_HELD[@]}"

{
  echo "# Nightly Closeout Classification"
  echo "- protected_items_count: $(( ${#LOCAL_BRANCH_PROTECTED[@]} + ${#WORKTREE_PROTECTED[@]} + ${#STALE_PATHS_PROTECTED[@]} + ${#REMOTE_ORIGIN_PROTECTED[@]} + ${#REMOTE_GITHUB_PROTECTED[@]} ))"
  echo "- prune_candidates_branches_count: $(( ${#LOCAL_BRANCH_CANDIDATES[@]} + ${#REMOTE_ORIGIN_CANDIDATES[@]} + ${#REMOTE_GITHUB_CANDIDATES[@]} ))"
  echo "- prune_candidates_worktrees_count: ${#WORKTREE_CANDIDATES[@]}"
  echo "- stale_path_candidates_count: ${#STALE_PATHS_CANDIDATES[@]}"
  echo "- blocked_items_due_to_scope_count: $(( ${#LOCAL_BRANCH_PROTECTED[@]} + ${#WORKTREE_PROTECTED[@]} + ${#STALE_PATHS_PROTECTED[@]} + ${#REMOTE_ORIGIN_PROTECTED[@]} + ${#REMOTE_GITHUB_PROTECTED[@]} ))"
  echo ""
  echo "## Protected local branches"
  sed -n '1,120p' "$ARTIFACT_DIR/local_branch_protected.txt"
  echo "## Candidate local branches"
  sed -n '1,120p' "$ARTIFACT_DIR/local_branch_candidates.txt"
  echo "## Protected worktrees"
  sed -n '1,120p' "$ARTIFACT_DIR/worktree_protected.txt"
  echo "## Candidate worktrees"
  sed -n '1,120p' "$ARTIFACT_DIR/worktree_candidates.txt"
  echo "## Candidate stale paths"
  sed -n '1,120p' "$ARTIFACT_DIR/stale_paths_candidates.txt"
  echo "## Candidate remote origin codex branches"
  sed -n '1,120p' "$ARTIFACT_DIR/remote_origin_candidates.txt"
  echo "## Candidate remote github codex branches"
  sed -n '1,120p' "$ARTIFACT_DIR/remote_github_candidates.txt"
} > "$CLASSIFICATION_MD"

SNAPSHOT_BUNDLE=""
SNAPSHOT_REFS=""

ACTION_BRANCHES_PRUNED=()
ACTION_WORKTREES_REMOVED=()
ACTION_STALE_PATHS_REMOVED=()
ACTION_REMOTE_ORIGIN_PRUNED=()
ACTION_REMOTE_GITHUB_PRUNED=()
ACTION_SKIPPED=()

if [[ "$MODE" == "apply" ]]; then
  mkdir -p "$SNAPSHOT_ROOT"
  SNAPSHOT_BUNDLE="$SNAPSHOT_ROOT/$(basename "$ROOT")-allrefs-${RUN_UTC}.bundle"
  SNAPSHOT_REFS="${SNAPSHOT_BUNDLE}.refs.txt"

  git -C "$ROOT" bundle create "$SNAPSHOT_BUNDLE" --all
  git -C "$ROOT" show-ref > "$SNAPSHOT_REFS"

  : > "$ACTIONS_LOG"

  for item in "${LOCAL_BRANCH_CANDIDATES[@]}"; do
    branch="${item%%|*}"
    if [[ "$branch" == "$CURRENT_BRANCH" ]]; then
      ACTION_SKIPPED+=("$branch|local-checked-out")
      continue
    fi
    if git -C "$ROOT" branch -d "$branch" >> "$ACTIONS_LOG" 2>&1; then
      ACTION_BRANCHES_PRUNED+=("$branch")
    else
      ACTION_SKIPPED+=("$branch|local-branch-delete-failed")
    fi
  done

  for item in "${WORKTREE_CANDIDATES[@]}"; do
    wt="${item%%|*}"
    if git -C "$ROOT" worktree remove "$wt" >> "$ACTIONS_LOG" 2>&1; then
      ACTION_WORKTREES_REMOVED+=("$wt")
    else
      ACTION_SKIPPED+=("$wt|worktree-remove-failed")
    fi
  done

  for item in "${STALE_PATHS_CANDIDATES[@]}"; do
    stale="${item%%|*}"
    case "$stale" in
      "$ROOT"/.worktrees/*)
        if rm -rf "$stale" >> "$ACTIONS_LOG" 2>&1; then
          ACTION_STALE_PATHS_REMOVED+=("$stale")
        else
          ACTION_SKIPPED+=("$stale|stale-path-remove-failed")
        fi
        ;;
      *)
        ACTION_SKIPPED+=("$stale|stale-path-outside-allowed-root")
        ;;
    esac
  done

  for item in "${REMOTE_ORIGIN_CANDIDATES[@]}"; do
    branch="${item%%|*}"
    if git -C "$ROOT" push origin --delete "$branch" >> "$ACTIONS_LOG" 2>&1; then
      ACTION_REMOTE_ORIGIN_PRUNED+=("$branch")
    else
      ACTION_SKIPPED+=("$branch|origin-remote-delete-failed")
    fi
  done

  for item in "${REMOTE_GITHUB_CANDIDATES[@]}"; do
    branch="${item%%|*}"
    if git -C "$ROOT" push github --delete "$branch" >> "$ACTIONS_LOG" 2>&1; then
      ACTION_REMOTE_GITHUB_PRUNED+=("$branch")
    else
      ACTION_SKIPPED+=("$branch|github-remote-delete-failed")
    fi
  done
else
  : > "$ACTIONS_LOG"
  echo "dry-run: destructive actions not executed" > "$ACTIONS_LOG"
fi

set +e
"$ROOT/ops/plugins/loops/bin/loops-status" > "$ARTIFACT_DIR/loops_status.log" 2>&1
echo "$?" > "$ARTIFACT_DIR/loops_status.rc"
"$ROOT/ops/plugins/loops/bin/gaps-status" > "$ARTIFACT_DIR/gaps_status.log" 2>&1
echo "$?" > "$ARTIFACT_DIR/gaps_status.rc"
"$ROOT/ops/plugins/ops/bin/worktree-lifecycle-reconcile" --json > "$ARTIFACT_DIR/worktree_lifecycle.log" 2>&1
echo "$?" > "$ARTIFACT_DIR/worktree_lifecycle.rc"
set -e

cat "$ARTIFACT_DIR/loops_status.log"
cat "$ARTIFACT_DIR/gaps_status.log"
cat "$ARTIFACT_DIR/worktree_lifecycle.log"

LOOPS_RUN_KEY="direct:ops/plugins/loops/bin/loops-status"
GAPS_RUN_KEY="direct:ops/plugins/loops/bin/gaps-status"
WORKTREE_RECONCILE_RUN_KEY="direct:ops/plugins/ops/bin/worktree-lifecycle-reconcile --json"

LOOPS_OPEN="$(awk '/By Status:/{f=1;next} f&&$1=="Open:"{print $2; exit}' "$ARTIFACT_DIR/loops_status.log" 2>/dev/null || true)"
GAPS_OPEN="$(sed -nE 's/^Gaps:[^|]*\|[[:space:]]*([0-9]+)[[:space:]]+open.*/\1/p' "$ARTIFACT_DIR/gaps_status.log" | head -1)"
ORPHANED_GAPS="$(sed -nE 's/^Orphaned gaps.*:[[:space:]]*([0-9]+).*/\1/p' "$ARTIFACT_DIR/gaps_status.log" | head -1)"
[[ -n "$LOOPS_OPEN" ]] || LOOPS_OPEN="unknown"
[[ -n "$GAPS_OPEN" ]] || GAPS_OPEN="unknown"
[[ -n "$ORPHANED_GAPS" ]] || ORPHANED_GAPS="unknown"

LOCAL_BRANCH_COUNT_AFTER="$(git -C "$ROOT" for-each-ref refs/heads --format='%(refname:short)' | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
WORKTREE_COUNT_AFTER="$(git -C "$ROOT" worktree list --porcelain | grep -c '^worktree ' || true)"
ORIGIN_CODEX_COUNT_AFTER="$(git -C "$ROOT" for-each-ref refs/remotes/origin/codex --format='%(refname:short)' 2>/dev/null | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
GITHUB_CODEX_COUNT_AFTER="$(git -C "$ROOT" for-each-ref refs/remotes/github/codex --format='%(refname:short)' 2>/dev/null | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"

{
  echo "# Nightly Closeout Summary"
  echo "- run_id: $RUN_ID"
  echo "- mode: $MODE"
  echo "- run_utc: $RUN_UTC"
  echo "- repo: $ROOT"
  echo "- head_sha: $(git -C "$ROOT" rev-parse HEAD)"
  echo "- loops_open: $LOOPS_OPEN"
  echo "- gaps_open: $GAPS_OPEN"
  echo "- orphaned_gaps: $ORPHANED_GAPS"
  echo "- local_branches_before: $LOCAL_BRANCH_COUNT_BEFORE"
  echo "- local_branches_after: $LOCAL_BRANCH_COUNT_AFTER"
  echo "- worktrees_before: $ROOT_WORKTREE_COUNT"
  echo "- worktrees_after: $WORKTREE_COUNT_AFTER"
  echo "- remote_codex_origin_before: $ORIGIN_CODEX_COUNT_BEFORE"
  echo "- remote_codex_origin_after: $ORIGIN_CODEX_COUNT_AFTER"
  echo "- remote_codex_github_before: $GITHUB_CODEX_COUNT_BEFORE"
  echo "- remote_codex_github_after: $GITHUB_CODEX_COUNT_AFTER"
  echo "- snapshot_bundle: ${SNAPSHOT_BUNDLE:-none}"
  echo "- snapshot_refs_inventory: ${SNAPSHOT_REFS:-none}"
  echo "- run_key_loops_status: ${LOOPS_RUN_KEY:-none}"
  echo "- run_key_gaps_status: ${GAPS_RUN_KEY:-none}"
  echo "- run_key_worktree_lifecycle: ${WORKTREE_RECONCILE_RUN_KEY:-none}"
  echo ""
  echo "## Actions"
  echo "- local_branches_pruned: ${#ACTION_BRANCHES_PRUNED[@]}"
  for row in "${ACTION_BRANCHES_PRUNED[@]}"; do echo "  - $row"; done
  echo "- worktrees_removed: ${#ACTION_WORKTREES_REMOVED[@]}"
  for row in "${ACTION_WORKTREES_REMOVED[@]}"; do echo "  - $row"; done
  echo "- stale_paths_removed: ${#ACTION_STALE_PATHS_REMOVED[@]}"
  for row in "${ACTION_STALE_PATHS_REMOVED[@]}"; do echo "  - $row"; done
  echo "- remote_origin_pruned: ${#ACTION_REMOTE_ORIGIN_PRUNED[@]}"
  for row in "${ACTION_REMOTE_ORIGIN_PRUNED[@]}"; do echo "  - $row"; done
  echo "- remote_github_pruned: ${#ACTION_REMOTE_GITHUB_PRUNED[@]}"
  for row in "${ACTION_REMOTE_GITHUB_PRUNED[@]}"; do echo "  - $row"; done
  echo "- skipped_items: ${#ACTION_SKIPPED[@]}"
  for row in "${ACTION_SKIPPED[@]}"; do echo "  - $row"; done
} > "$SUMMARY_MD"

{
  echo "mode=$MODE"
  echo "run_id=$RUN_ID"
  echo "run_utc=$RUN_UTC"
  echo "repo=$ROOT"
  echo "summary_md=$SUMMARY_MD"
  echo "inventory_md=$INVENTORY_MD"
  echo "classification_md=$CLASSIFICATION_MD"
  echo "actions_log=$ACTIONS_LOG"
  echo "snapshot_bundle=${SNAPSHOT_BUNDLE:-none}"
  echo "snapshot_refs=${SNAPSHOT_REFS:-none}"
  echo "run_key_loops_status=${LOOPS_RUN_KEY:-none}"
  echo "run_key_gaps_status=${GAPS_RUN_KEY:-none}"
  echo "run_key_worktree_lifecycle=${WORKTREE_RECONCILE_RUN_KEY:-none}"
  echo "loops_open=$LOOPS_OPEN"
  echo "gaps_open=$GAPS_OPEN"
  echo "orphaned_gaps=$ORPHANED_GAPS"
  echo "local_branches_before=$LOCAL_BRANCH_COUNT_BEFORE"
  echo "local_branches_after=$LOCAL_BRANCH_COUNT_AFTER"
  echo "worktrees_before=$ROOT_WORKTREE_COUNT"
  echo "worktrees_after=$WORKTREE_COUNT_AFTER"
  echo "remote_codex_origin_before=$ORIGIN_CODEX_COUNT_BEFORE"
  echo "remote_codex_origin_after=$ORIGIN_CODEX_COUNT_AFTER"
  echo "remote_codex_github_before=$GITHUB_CODEX_COUNT_BEFORE"
  echo "remote_codex_github_after=$GITHUB_CODEX_COUNT_AFTER"
} > "$SUMMARY_ENV"

echo "nightly.closeout mode=$MODE run_id=$RUN_ID"
echo "artifact.summary=$SUMMARY_MD"
echo "artifact.inventory=$INVENTORY_MD"
echo "artifact.classification=$CLASSIFICATION_MD"
echo "artifact.actions=$ACTIONS_LOG"
echo "artifact.summary_env=$SUMMARY_ENV"
echo "run_key.loops_status=${LOOPS_RUN_KEY:-none}"
echo "run_key.gaps_status=${GAPS_RUN_KEY:-none}"
echo "run_key.worktree_lifecycle=${WORKTREE_RECONCILE_RUN_KEY:-none}"
echo "snapshot.bundle=${SNAPSHOT_BUNDLE:-none}"
echo "snapshot.refs=${SNAPSHOT_REFS:-none}"
