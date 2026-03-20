#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/runtime-paths.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (expected='$expected', got='$actual')"
  fi
}

echo "runtime target repo resolution tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

TARGET="$TMPDIR_BASE/target"
EXPLICIT="$TMPDIR_BASE/explicit"
git init "$TARGET" >/dev/null
git -C "$TARGET" config user.name "Test User"
git -C "$TARGET" config user.email "test@example.com"
printf 'base\n' > "$TARGET/file.txt"
git -C "$TARGET" add file.txt
git -C "$TARGET" commit -m "base" >/dev/null
git -C "$TARGET" branch -M main >/dev/null

git init "$EXPLICIT" >/dev/null
git -C "$EXPLICIT" config user.name "Test User"
git -C "$EXPLICIT" config user.email "test@example.com"
printf 'base\n' > "$EXPLICIT/file.txt"
git -C "$EXPLICIT" add file.txt
git -C "$EXPLICIT" commit -m "base" >/dev/null
git -C "$EXPLICIT" branch -M main >/dev/null

TARGET_CANON="$(cd "$TARGET" && pwd -P)"
EXPLICIT_CANON="$(cd "$EXPLICIT" && pwd -P)"

echo ""
echo "── T1: current checkout wins over inherited SPINE_REPO ──"
t1_out="$(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO SPINE_REPO="$ROOT" SPINE_CODE="$ROOT" bash -lc '
    source "'"$ROOT"'/ops/lib/runtime-paths.sh"
    spine_runtime_resolve_paths
    printf "%s|%s|%s\n" "$SPINE_TARGET_REPO" "$SPINE_REPO" "$SPINE_CODE"
  '
)"
t1_target="${t1_out%%|*}"
t1_rest="${t1_out#*|}"
t1_repo="${t1_rest%%|*}"
t1_code="${t1_rest##*|}"
assert_eq "$t1_target" "$TARGET_CANON" "target repo resolves from current checkout"
assert_eq "$t1_repo" "$TARGET_CANON" "compat SPINE_REPO follows resolved target repo"
assert_eq "$t1_code" "$ROOT" "control root remains the agentic-spine code checkout"

echo ""
echo "── T2: explicit SPINE_TARGET_REPO overrides current checkout ──"
t2_out="$(
  cd "$TARGET"
  env SPINE_TARGET_REPO="$EXPLICIT" SPINE_REPO="$ROOT" SPINE_CODE="$ROOT" bash -lc '
    source "'"$ROOT"'/ops/lib/runtime-paths.sh"
    spine_runtime_resolve_paths
    printf "%s|%s\n" "$SPINE_TARGET_REPO" "$SPINE_REPO"
  '
)"
t2_target="${t2_out%%|*}"
t2_repo="${t2_out##*|}"
assert_eq "$t2_target" "$EXPLICIT_CANON" "explicit target repo wins"
assert_eq "$t2_repo" "$EXPLICIT_CANON" "compat SPINE_REPO follows explicit target"

echo ""
echo "── T3: cap runner advertises explicit target repo ──"
t3_out="$(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO SPINE_REPO="$ROOT" SPINE_CODE="$ROOT" "$ROOT/bin/ops" cap run worktree.lifecycle.reconcile -- --brief
)"
assert_eq "$(printf '%s\n' "$t3_out" | grep -E '^(PASS|FAIL) issues=' | tail -1)" "PASS issues=0 warnings=0 worktrees=0 temp_clones=0 root=1 stashes=0" "cap-run executes against current checkout, not inherited root repo"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
