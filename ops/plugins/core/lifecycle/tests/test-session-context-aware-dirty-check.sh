#!/usr/bin/env bash
set -euo pipefail

# test-session-context-aware-dirty-check.sh
#
# Integration tests for context-aware dirty checking in session attach.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
source "${SPINE_ROOT:-$ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

CHECKER="$ROOT/ops/plugins/core/session/bin/session-context-aware-dirty-check"

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

  # Create initial commit
  mkdir -p ops/bindings ops/plugins/core/session/bin ops/lib bin
  echo "test" > README.md
  git add -A
  git commit -q -m "Initial commit"
}

test_clean_repo() {
  local test_repo="$TEMP_DIR/clean_repo"
  setup_test_repo "$test_repo"

  # Run checker on clean repo
  if "$CHECKER" --repo-path "$test_repo" --json > "$TEMP_DIR/result.json"; then
    local dirty_count=$(jq -r '.dirty_count' "$TEMP_DIR/result.json")
    local safe=$(jq -r '.safe_to_proceed' "$TEMP_DIR/result.json")

    if [[ "$dirty_count" -eq 0 && "$safe" == "true" ]]; then
      echo "PASS: clean_repo - clean repo allows session attach"
      return 0
    fi
  fi

  echo "FAIL: clean_repo - should allow attach on clean repo"
  return 1
}

test_hotspot_files_allowed() {
  local test_repo="$TEMP_DIR/hotspot_repo"
  setup_test_repo "$test_repo"

  # Modify hotspot files (contract files)
  mkdir -p "$test_repo/ops/bindings"
  echo "modified" > "$test_repo/ops/bindings/test.contract.yaml"

  # Run checker
  if "$CHECKER" --repo-path "$test_repo" --json > "$TEMP_DIR/result.json"; then
    local dirty_count=$(jq -r '.dirty_count' "$TEMP_DIR/result.json")
    local safe=$(jq -r '.safe_to_proceed' "$TEMP_DIR/result.json")
    local reason=$(jq -r '.reason' "$TEMP_DIR/result.json")

    if [[ "$dirty_count" -gt 0 && "$safe" == "true" && "$reason" == "governed_operation_hotspots" ]]; then
      echo "PASS: hotspot_files_allowed - hotspot files allow session attach"
      return 0
    fi
  fi

  echo "FAIL: hotspot_files_allowed - should allow attach with only hotspot modifications"
  cat "$TEMP_DIR/result.json"
  return 1
}

test_session_bootstrap_conflict() {
  local test_repo="$TEMP_DIR/conflict_repo"
  setup_test_repo "$test_repo"

  # Modify session bootstrap files (should block)
  mkdir -p "$test_repo/ops/plugins/core/session"
  echo "modified" > "$test_repo/ops/plugins/core/session/bin/session-start"

  # Run checker (should fail)
  if ! "$CHECKER" --repo-path "$test_repo" --json > "$TEMP_DIR/result.json"; then
    local dirty_count=$(jq -r '.dirty_count' "$TEMP_DIR/result.json")
    local safe=$(jq -r '.safe_to_proceed' "$TEMP_DIR/result.json")
    local reason=$(jq -r '.reason' "$TEMP_DIR/result.json")

    if [[ "$dirty_count" -gt 0 && "$safe" == "false" && "$reason" == "session_bootstrap_conflict" ]]; then
      echo "PASS: session_bootstrap_conflict - bootstrap file changes block attach"
      return 0
    fi
  fi

  echo "FAIL: session_bootstrap_conflict - should block attach on bootstrap file changes"
  cat "$TEMP_DIR/result.json"
  return 1
}

test_non_hotspot_files_allowed_with_warning() {
  local test_repo="$TEMP_DIR/non_hotspot_repo"
  setup_test_repo "$test_repo"

  # Modify non-hotspot files (should allow but warn)
  echo "modified" > "$test_repo/some_random_file.txt"

  # Run checker
  if "$CHECKER" --repo-path "$test_repo" --json > "$TEMP_DIR/result.json"; then
    local dirty_count=$(jq -r '.dirty_count' "$TEMP_DIR/result.json")
    local safe=$(jq -r '.safe_to_proceed' "$TEMP_DIR/result.json")
    local reason=$(jq -r '.reason' "$TEMP_DIR/result.json")

    if [[ "$dirty_count" -gt 0 && "$safe" == "true" && "$reason" == "non_hotspot_files_allowed" ]]; then
      echo "PASS: non_hotspot_files_allowed - non-hotspot files allow attach with warning"
      return 0
    fi
  fi

  echo "FAIL: non_hotspot_files_allowed - should allow attach on non-critical files"
  cat "$TEMP_DIR/result.json"
  return 1
}

# Run all tests
echo "Running session context-aware dirty check tests..."
echo ""

PASSED=0
FAILED=0

for test_func in test_clean_repo test_hotspot_files_allowed test_session_bootstrap_conflict test_non_hotspot_files_allowed_with_warning; do
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
