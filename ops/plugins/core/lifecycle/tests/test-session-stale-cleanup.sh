#!/usr/bin/env bash
set -euo pipefail

# test-session-stale-cleanup.sh
#
# Integration tests for stale worktree/branch cleanup.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
source "${SPINE_ROOT:-$ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

CLEANER="$ROOT/ops/plugins/core/session/bin/session-stale-cleanup"

# Test setup
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

setup_test_repo() {
  local repo_path="$1"
  mkdir -p "$repo_path"
  cd "$repo_path"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"

  # Create initial commit on main
  echo "test" > README.md
  git add -A
  git commit -q -m "Initial commit"
  git branch -M main
}

test_no_stale_worktrees() {
  local test_repo="$TEMP_DIR/no_stale_repo"
  setup_test_repo "$test_repo"

  # Run cleanup (should find nothing)
  if "$CLEANER" --repo-path "$test_repo" --json --dry-run > "$TEMP_DIR/result.json"; then
    local stale_count=$(jq -r '.stale_count' "$TEMP_DIR/result.json")

    if [[ "$stale_count" -eq 0 ]]; then
      echo "PASS: no_stale_worktrees - no cleanup needed"
      return 0
    fi
  fi

  echo "FAIL: no_stale_worktrees - should find no stale worktrees"
  cat "$TEMP_DIR/result.json"
  return 1
}

test_old_branch_detected() {
  local test_repo="$TEMP_DIR/old_branch_repo"
  setup_test_repo "$test_repo"

  # Create an old feature branch
  git -C "$test_repo" checkout -q -b feature/old-work
  echo "old work" > "$test_repo/old.txt"
  git -C "$test_repo" add -A
  git -C "$test_repo" commit -q -m "Old work" --date="30 days ago"
  git -C "$test_repo" checkout -q main

  # Create worktree from old branch
  local wt_path="$test_repo/../old-worktree"
  git -C "$test_repo" worktree add -q "$wt_path" feature/old-work

  # Run cleanup in dry-run mode
  if "$CLEANER" --repo-path "$test_repo" --json --dry-run --max-age-days 7 > "$TEMP_DIR/result.json"; then
    local stale_count=$(jq -r '.stale_count' "$TEMP_DIR/result.json")

    if [[ "$stale_count" -gt 0 ]]; then
      echo "PASS: old_branch_detected - found stale worktree from old branch"
      return 0
    fi
  fi

  echo "FAIL: old_branch_detected - should detect old branch worktree"
  cat "$TEMP_DIR/result.json"
  return 1
}

test_dirty_worktree_preserved() {
  local test_repo="$TEMP_DIR/dirty_worktree_repo"
  setup_test_repo "$test_repo"

  # Create old branch with worktree
  git -C "$test_repo" checkout -q -b feature/dirty-work
  local wt_path="$test_repo/../dirty-worktree"
  git -C "$test_repo" worktree add -q "$wt_path" -b feature/dirty-branch
  git -C "$test_repo" checkout -q main

  # Make worktree dirty
  echo "uncommitted work" > "$wt_path/dirty.txt"

  # Run cleanup (should skip dirty worktree)
  if "$CLEANER" --repo-path "$test_repo" --json --dry-run --max-age-days 0 > "$TEMP_DIR/result.json"; then
    local stale_count=$(jq -r '.stale_count' "$TEMP_DIR/result.json")

    # Should not detect dirty worktree as stale
    if [[ "$stale_count" -eq 0 ]]; then
      echo "PASS: dirty_worktree_preserved - dirty worktree not marked for cleanup"
      return 0
    fi
  fi

  echo "FAIL: dirty_worktree_preserved - should preserve dirty worktree"
  cat "$TEMP_DIR/result.json"
  return 1
}

test_dry_run_no_changes() {
  local test_repo="$TEMP_DIR/dry_run_repo"
  setup_test_repo "$test_repo"

  # Create old worktree
  git -C "$test_repo" checkout -q -b feature/to-clean
  echo "old" > "$test_repo/old.txt"
  git -C "$test_repo" add -A
  git -C "$test_repo" commit -q -m "Old" --date="30 days ago"
  local wt_path="$test_repo/../to-clean-worktree"
  git -C "$test_repo" worktree add -q "$wt_path" feature/to-clean
  git -C "$test_repo" checkout -q main

  # Run in dry-run mode
  "$CLEANER" --repo-path "$test_repo" --json --dry-run --max-age-days 7 > "$TEMP_DIR/result.json"

  # Verify worktree still exists
  if git -C "$test_repo" worktree list | grep -q "to-clean"; then
    echo "PASS: dry_run_no_changes - dry-run preserves worktree"
    return 0
  fi

  echo "FAIL: dry_run_no_changes - dry-run should not modify worktrees"
  return 1
}

# Run all tests
echo "Running session stale cleanup tests..."
echo ""

PASSED=0
FAILED=0

for test_func in test_no_stale_worktrees test_old_branch_detected test_dirty_worktree_preserved test_dry_run_no_changes; do
  if $test_func; then
    ((PASSED++))
  else
    ((FAILED++))
  fi
  echo ""
done

echo "======================================"
echo "Test Results: $PASSED passed, $FAILED failed"
echo "======================================"

exit $FAILED
