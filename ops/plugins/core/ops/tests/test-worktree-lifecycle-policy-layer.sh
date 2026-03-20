#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
RECONCILE="$ROOT/ops/plugins/core/ops/bin/worktree-lifecycle-reconcile"
CLEANUP="$ROOT/ops/plugins/core/ops/bin/worktree-lifecycle-cleanup"

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

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label (expected: $needle)"
  fi
}

touch_old_repo() {
  local repo_path="$1"
  python3 - "$repo_path" <<'PY'
import os
import sys
import time
from pathlib import Path

root = Path(sys.argv[1])
ts = time.time() - (72 * 3600)
targets = [
    root,
    root / ".git",
    root / ".git" / "HEAD",
    root / ".git" / "FETCH_HEAD",
    root / ".git" / "index",
    root / ".git" / "logs" / "HEAD",
]
for target in targets:
    if target.exists():
        os.utime(target, (ts, ts))
PY
}

json_eval() {
  local json_file="$1" expr="$2"
  python3 - "$json_file" "$expr" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
expr = sys.argv[2]
print(eval(expr, {"payload": payload}))
PY
}

echo "worktree lifecycle policy layer tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

TARGET="$TMPDIR_BASE/target"
OTHER="$TMPDIR_BASE/other"
TMP_ROOT="$TMPDIR_BASE/runtime/tmp"
CLONE_ROOT="$TMP_ROOT/clones"
MANAGED_WORKTREE="$TMPDIR_BASE/managed/runtime-scheduler"
mkdir -p "$CLONE_ROOT"

git init "$TARGET" >/dev/null
git -C "$TARGET" config user.name "Test User"
git -C "$TARGET" config user.email "test@example.com"
printf 'base\n' > "$TARGET/file.txt"
git -C "$TARGET" add file.txt
git -C "$TARGET" commit -m "base" >/dev/null
git -C "$TARGET" branch -M main >/dev/null

git init "$OTHER" >/dev/null
git -C "$OTHER" config user.name "Test User"
git -C "$OTHER" config user.email "test@example.com"
printf 'other\n' > "$OTHER/other.txt"
git -C "$OTHER" add other.txt
git -C "$OTHER" commit -m "base" >/dev/null
git -C "$OTHER" branch -M main >/dev/null

CLEAN_CLONE="$CLONE_ROOT/verify-target-clean"
DIRTY_CLONE="$CLONE_ROOT/verify-target-dirty"
IGNORED_CLONE="$CLONE_ROOT/verify-other"
git clone "$TARGET" "$CLEAN_CLONE" >/dev/null 2>&1
git clone "$TARGET" "$DIRTY_CLONE" >/dev/null 2>&1
git clone "$OTHER" "$IGNORED_CLONE" >/dev/null 2>&1
printf 'dirty\n' >> "$DIRTY_CLONE/file.txt"
touch_old_repo "$CLEAN_CLONE"
touch_old_repo "$DIRTY_CLONE"
touch_old_repo "$IGNORED_CLONE"
mkdir -p "$(dirname "$MANAGED_WORKTREE")"
git -C "$TARGET" worktree add -b runtime/scheduler-projection "$MANAGED_WORKTREE" main >/dev/null 2>&1

git -C "$TARGET" switch -c feature/root-parking >/dev/null

echo ""
echo "── T1: reconcile classifies matching temp clones and root normalization ──"
RECONCILE_JSON="$TMPDIR_BASE/reconcile.json"
(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_TMP="$TMP_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_TEMP_CLONE_ROOT="$CLONE_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_MANAGED_WORKTREE_PATHS="$MANAGED_WORKTREE" \
    "$RECONCILE" --json > "$RECONCILE_JSON"
)
assert_eq "$(json_eval "$RECONCILE_JSON" 'payload["summary"]["checked_worktrees"]')" "1" "managed runtime worktree is still inventoried"
assert_eq "$(json_eval "$RECONCILE_JSON" 'payload["summary"]["checked_temp_clones"]')" "2" "only repo-matching temp clones are counted"
assert_eq "$(json_eval "$RECONCILE_JSON" 'payload["root_checkout"]["normalizable"]')" "True" "root checkout is marked normalizable when head matches main"
assert_eq "$(json_eval "$RECONCILE_JSON" '"root_checkout_matches_main_but_branch_not_main" in payload["root_checkout"]["issues"]')" "True" "root non-main normalization issue is reported"
assert_eq "$(json_eval "$RECONCILE_JSON" 'sorted(row["path"].split("/")[-1] for row in payload["temp_clones"])')" "['verify-target-clean', 'verify-target-dirty']" "non-matching clone is ignored"
assert_eq "$(json_eval "$RECONCILE_JSON" 'sorted(sorted(row["issues"]) for row in payload["temp_clones"])')" "[['dirty_temp_clone', 'temp_clone_past_grace'], ['temp_clone_past_grace']]" "temp clone issues distinguish dirty and stale"
assert_eq "$(json_eval "$RECONCILE_JSON" 'payload["worktrees"][0]["managed_worktree"]')" "True" "managed worktree is classified explicitly"
assert_eq "$(json_eval "$RECONCILE_JSON" 'payload["worktrees"][0]["issues"]')" "[]" "managed worktree at main parity is not treated as orphaned lane debt"

echo ""
echo "── T2: cleanup report classifies clone candidates and root action ──"
CLEANUP_JSON="$TMPDIR_BASE/cleanup.json"
(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_TMP="$TMP_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_TEMP_CLONE_ROOT="$CLONE_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_MANAGED_WORKTREE_PATHS="$MANAGED_WORKTREE" \
    "$CLEANUP" --mode report-only --json > "$CLEANUP_JSON"
)
assert_eq "$(json_eval "$CLEANUP_JSON" 'payload["summary"]["temp_clone_delete_candidate_count"]')" "1" "report-only exposes one clean stale temp clone candidate"
assert_eq "$(json_eval "$CLEANUP_JSON" 'payload["summary"]["temp_clone_blocked_count"]')" "1" "report-only blocks dirty stale temp clone"
assert_eq "$(json_eval "$CLEANUP_JSON" 'payload["summary"]["blocked_count"]')" "1" "managed worktree stays protected from cleanup delete"
assert_eq "$(json_eval "$CLEANUP_JSON" 'payload["root_normalization"]["candidate"]["to_branch"]')" "main" "report-only exposes root normalization target"
assert_eq "$(json_eval "$CLEANUP_JSON" 'payload["temp_clone_delete_candidates"][0]["path"].split("/")[-1]')" "verify-target-clean" "clean stale clone becomes delete candidate"

echo ""
echo "── T3: archive/delete removes clean stale clone and normalizes root ──"
archive_out="$(
  cd "$TARGET" && \
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_TMP="$TMP_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_TEMP_CLONE_ROOT="$CLONE_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_MANAGED_WORKTREE_PATHS="$MANAGED_WORKTREE" \
    "$CLEANUP" --mode archive-only 2>&1
)"
assert_contains "$archive_out" "artifact.archive_manifest=" "archive-only emits manifest path"
manifest_path="$(printf '%s\n' "$archive_out" | sed -n 's/^artifact.archive_manifest=//p' | tail -1)"
if [[ -n "$manifest_path" && -f "$manifest_path" ]]; then
  pass "archive manifest created"
else
  fail "archive manifest created"
fi
delete_out="$(
  cd "$TARGET" && \
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_TMP="$TMP_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_TEMP_CLONE_ROOT="$CLONE_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_MANAGED_WORKTREE_PATHS="$MANAGED_WORKTREE" \
    OPS_WORKTREE_DELETE_TOKEN=RELEASE_MAIN_CLEANUP_WINDOW \
    OPS_WORKTREE_CLEANUP_REQUIRE_RECEIPT_GATE_PASS_DELETE=false \
    "$CLEANUP" --mode delete --manifest "$manifest_path" 2>&1
)"
assert_contains "$delete_out" "artifact.actions=" "delete emits actions log"
if [[ ! -d "$CLEAN_CLONE" ]]; then
  pass "clean stale temp clone deleted"
else
  fail "clean stale temp clone deleted"
fi
if [[ -d "$DIRTY_CLONE" ]]; then
  pass "dirty temp clone preserved"
else
  fail "dirty temp clone preserved"
fi
if [[ -d "$MANAGED_WORKTREE" ]]; then
  pass "managed worktree preserved"
else
  fail "managed worktree preserved"
fi
assert_eq "$(git -C "$TARGET" branch --show-current)" "main" "root checkout normalized back to main"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
