#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
SYNC="$ROOT/ops/plugins/core/ops/bin/worktree-lifecycle-managed-sync"

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

setup_repo() {
  local repo_path="$1" managed_path="$2"
  git init "$repo_path" >/dev/null
  git -C "$repo_path" config user.name "Test User"
  git -C "$repo_path" config user.email "test@example.com"
  printf 'base\n' > "$repo_path/file.txt"
  git -C "$repo_path" add file.txt
  git -C "$repo_path" commit -m "base" >/dev/null
  git -C "$repo_path" branch -M main >/dev/null
  mkdir -p "$(dirname "$managed_path")"
  git -C "$repo_path" worktree add -b runtime/scheduler-projection "$managed_path" main >/dev/null 2>&1
}

echo "managed worktree sync tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo ""
echo "── T1: behind managed worktree fast-forwards to main ──"
REPO1="$TMPDIR_BASE/repo1"
MANAGED1="$TMPDIR_BASE/repo1-managed"
setup_repo "$REPO1" "$MANAGED1"
printf 'main update\n' >> "$REPO1/file.txt"
git -C "$REPO1" commit -am "main update" >/dev/null
SYNC_JSON1="$TMPDIR_BASE/sync1.json"
(
  cd "$REPO1"
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_WORKTREE_LIFECYCLE_MANAGED_WORKTREE_PATHS="$MANAGED1" \
    "$SYNC" --trigger test.ff --json > "$SYNC_JSON1"
)
assert_eq "$(git -C "$MANAGED1" rev-parse HEAD)" "$(git -C "$REPO1" rev-parse refs/heads/main)" "managed worktree fast-forwarded to main"
assert_eq "$(json_eval "$SYNC_JSON1" 'payload["summary"]["synced_count"]')" "1" "sync summary counts fast-forward"
assert_eq "$(json_eval "$SYNC_JSON1" 'payload["summary"]["blocked_count"]')" "0" "sync summary stays unblocked on fast-forward"

echo ""
echo "── T2: dirty managed worktree blocks sync ──"
REPO2="$TMPDIR_BASE/repo2"
MANAGED2="$TMPDIR_BASE/repo2-managed"
setup_repo "$REPO2" "$MANAGED2"
printf 'main update\n' >> "$REPO2/file.txt"
git -C "$REPO2" commit -am "main update" >/dev/null
printf 'dirty\n' >> "$MANAGED2/file.txt"
set +e
SYNC_OUT2="$(
  cd "$REPO2" && \
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_WORKTREE_LIFECYCLE_MANAGED_WORKTREE_PATHS="$MANAGED2" \
    "$SYNC" --trigger test.dirty --brief 2>&1
)"
SYNC_STATUS2=$?
set -e
assert_eq "$SYNC_STATUS2" "1" "dirty managed worktree exits non-zero"
assert_contains "$SYNC_OUT2" "FAIL" "dirty managed worktree reports failure"
assert_eq "$(git -C "$MANAGED2" rev-parse HEAD)" "$(git -C "$MANAGED2" rev-parse refs/heads/runtime/scheduler-projection)" "dirty managed worktree head unchanged"

echo ""
echo "── T3: diverged managed worktree blocks non-fast-forward sync ──"
REPO3="$TMPDIR_BASE/repo3"
MANAGED3="$TMPDIR_BASE/repo3-managed"
setup_repo "$REPO3" "$MANAGED3"
printf 'managed only\n' >> "$MANAGED3/file.txt"
git -C "$MANAGED3" commit -am "managed only" >/dev/null
printf 'main update\n' >> "$REPO3/file.txt"
git -C "$REPO3" commit -am "main update" >/dev/null
set +e
SYNC_OUT3="$(
  cd "$REPO3" && \
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_WORKTREE_LIFECYCLE_MANAGED_WORKTREE_PATHS="$MANAGED3" \
    "$SYNC" --trigger test.nonff --brief 2>&1
)"
SYNC_STATUS3=$?
set -e
assert_eq "$SYNC_STATUS3" "1" "diverged managed worktree exits non-zero"
assert_contains "$SYNC_OUT3" "blocked=1" "diverged managed worktree reports blocked status"

echo ""
echo "── T4: post-commit hook triggers managed sync path on main ──"
REPO4="$TMPDIR_BASE/repo4"
STUB4="$TMPDIR_BASE/stub4.sh"
LOG4="$TMPDIR_BASE/post-commit.log"
git init "$REPO4" >/dev/null
git -C "$REPO4" config user.name "Test User"
git -C "$REPO4" config user.email "test@example.com"
git -C "$REPO4" config core.hooksPath "$ROOT/.githooks"
cat > "$STUB4" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SYNC_STUB_LOG:?}"
EOF
chmod +x "$STUB4"
printf 'base\n' > "$REPO4/file.txt"
(
  cd "$REPO4"
  git checkout -b main >/dev/null 2>&1
  git add file.txt
  OPS_GOVERNED_MAIN_OVERRIDE=1 SYNC_STUB_LOG="$LOG4" SPINE_MANAGED_WORKTREE_SYNC_BIN="$STUB4" git commit -m "base" >/dev/null
)
assert_contains "$(cat "$LOG4")" "--trigger git.post-commit --brief" "post-commit hook invokes managed sync runner"

echo ""
echo "── T5: post-merge hook triggers managed sync path on main ──"
REPO5="$TMPDIR_BASE/repo5"
STUB5="$TMPDIR_BASE/stub5.sh"
LOG5="$TMPDIR_BASE/post-merge.log"
git init "$REPO5" >/dev/null
git -C "$REPO5" config user.name "Test User"
git -C "$REPO5" config user.email "test@example.com"
git -C "$REPO5" config core.hooksPath "$ROOT/.githooks"
cat > "$STUB5" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SYNC_STUB_LOG:?}"
EOF
chmod +x "$STUB5"
printf 'base\n' > "$REPO5/file.txt"
(
  cd "$REPO5"
  git checkout -b main >/dev/null 2>&1
  git add file.txt
  OPS_GOVERNED_MAIN_OVERRIDE=1 SYNC_STUB_LOG="$LOG5" SPINE_MANAGED_WORKTREE_SYNC_BIN="$STUB5" git commit -m "base" >/dev/null
  : > "$LOG5"
  git switch -c feature/branch >/dev/null
  printf 'feature\n' >> file.txt
  git commit -am "feature" >/dev/null
  git switch main >/dev/null
  OPS_GOVERNED_MAIN_OVERRIDE=1 SYNC_STUB_LOG="$LOG5" SPINE_MANAGED_WORKTREE_SYNC_BIN="$STUB5" git merge --no-ff feature/branch -m "merge feature" >/dev/null
)
assert_contains "$(cat "$LOG5")" "--trigger git.post-merge --brief" "post-merge hook invokes managed sync runner"

echo ""
echo "── T6: post-commit hook fast-forwards managed worktree with real helper ──"
REPO6="$TMPDIR_BASE/repo6"
MANAGED6="$TMPDIR_BASE/repo6-managed"
setup_repo "$REPO6" "$MANAGED6"
git -C "$REPO6" config core.hooksPath "$ROOT/.githooks"
printf 'main update\n' >> "$REPO6/file.txt"
(
  cd "$REPO6"
  OPS_GOVERNED_MAIN_OVERRIDE=1 \
  SPINE_MANAGED_WORKTREE_SYNC_BIN="$SYNC" \
  SPINE_WORKTREE_LIFECYCLE_MANAGED_WORKTREE_PATHS="$MANAGED6" \
    git commit -am "main update" >/dev/null
)
assert_eq "$(git -C "$MANAGED6" rev-parse HEAD)" "$(git -C "$REPO6" rev-parse refs/heads/main)" "real post-commit hook keeps managed worktree at main"

echo ""
echo "── T7: detached managed worktree fast-forwards without blocking startup ──"
REPO7="$TMPDIR_BASE/repo7"
MANAGED7="$TMPDIR_BASE/repo7-managed"
setup_repo "$REPO7" "$MANAGED7"
git -C "$MANAGED7" checkout --detach >/dev/null 2>&1
printf 'main update\n' >> "$REPO7/file.txt"
git -C "$REPO7" commit -am "main update" >/dev/null
SYNC_JSON7="$TMPDIR_BASE/sync7.json"
(
  cd "$REPO7"
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_WORKTREE_LIFECYCLE_MANAGED_WORKTREE_PATHS="$MANAGED7" \
    "$SYNC" --trigger test.detached --json > "$SYNC_JSON7"
)
assert_eq "$(git -C "$MANAGED7" rev-parse HEAD)" "$(git -C "$REPO7" rev-parse refs/heads/main)" "detached managed worktree catches up to main"
assert_eq "$(json_eval "$SYNC_JSON7" 'payload["summary"]["blocked_count"]')" "0" "detached managed worktree does not block sync"
assert_eq "$(json_eval "$SYNC_JSON7" 'payload["summary"]["synced_count"]')" "1" "detached managed worktree counts as synced after fast-forward"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
