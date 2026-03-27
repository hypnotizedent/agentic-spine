#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
RECONCILE="$ROOT/ops/plugins/core/ops/bin/worktree-lifecycle-reconcile"
HEARTBEAT_POST="$ROOT/ops/plugins/core/session/bin/terminal-heartbeat-post"

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
    fail "$label (expected to contain: $needle)"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -Fq -- "$needle"; then
    fail "$label (should NOT contain: $needle)"
  else
    pass "$label"
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

echo "worktree lifecycle lane scope tests"
echo "════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT
STATE_ROOT="$TMPDIR_BASE/state"
mkdir -p "$STATE_ROOT"
export SPINE_STATE="$STATE_ROOT"

# ── Set up a bare repo to serve as origin ────────────────────────
BARE="$TMPDIR_BASE/bare.git"
git init --bare "$BARE" >/dev/null 2>&1

# ── Create the "root" checkout (simulates agentic-spine) ────────
MAIN_CHECKOUT="$TMPDIR_BASE/root-checkout"
git clone "$BARE" "$MAIN_CHECKOUT" >/dev/null 2>&1
git -C "$MAIN_CHECKOUT" config user.name "Test User"
git -C "$MAIN_CHECKOUT" config user.email "test@example.com"
printf 'base\n' > "$MAIN_CHECKOUT/file.txt"
git -C "$MAIN_CHECKOUT" add file.txt
git -C "$MAIN_CHECKOUT" commit -m "base" >/dev/null
git -C "$MAIN_CHECKOUT" branch -M main >/dev/null
git -C "$MAIN_CHECKOUT" push -u origin main >/dev/null 2>&1

# ── Create a linked worktree (simulates a wave lane) ────────────
WORKTREE_DIR="$TMPDIR_BASE/worktrees/wave-alpha"
git -C "$MAIN_CHECKOUT" worktree add -b codex/wave-alpha "$WORKTREE_DIR" main >/dev/null 2>&1
git -C "$WORKTREE_DIR" config user.name "Test User"
git -C "$WORKTREE_DIR" config user.email "test@example.com"

# Resolve paths via python (macOS /var → /private/var symlink handling)
resolve_path() {
  python3 -c "from pathlib import Path; print(Path('$1').resolve())"
}

MAIN_CHECKOUT_RESOLVED="$(resolve_path "$MAIN_CHECKOUT")"
WORKTREE_DIR_RESOLVED="$(resolve_path "$WORKTREE_DIR")"

# Common env overrides for test isolation
COMMON_ENV=(
  "SPINE_TARGET_REPO=$MAIN_CHECKOUT"
  "SPINE_CODE=$ROOT"
)

WT_ENV=(
  "SPINE_TARGET_REPO=$WORKTREE_DIR"
  "SPINE_CODE=$ROOT"
)

# ── T1: Lane mode from root – root dirty is a lane issue ────────
echo ""
echo "── T1: Lane mode from root ──"

printf 'dirty\n' >> "$MAIN_CHECKOUT/file.txt"
OUT="$TMPDIR_BASE/t1.json"
env "${COMMON_ENV[@]}" bash "$RECONCILE" --lane --json > "$OUT" 2>/dev/null || true

LANE_COUNT=$(json_eval "$OUT" "payload['summary']['lane_issue_count']")
assert_eq "$LANE_COUNT" "1" "T1.1: lane mode from root: root_checkout_dirty is lane issue"

LANE_CODES=$(json_eval "$OUT" "','.join(i['code'] for i in payload['lane_issues'])")
assert_contains "$LANE_CODES" "root_checkout_dirty" "T1.2: lane issue code is root_checkout_dirty"

# ── T2: Lane mode from worktree – root dirty is global ──────────
echo ""
echo "── T2: Lane mode from worktree ──"

OUT="$TMPDIR_BASE/t2.json"
env "${WT_ENV[@]}" bash "$RECONCILE" --lane --json > "$OUT" 2>/dev/null || true

LANE_COUNT=$(json_eval "$OUT" "payload['summary']['lane_issue_count']")
assert_eq "$LANE_COUNT" "0" "T2.1: lane mode from worktree: root dirty is NOT a lane issue"

GLOBAL_COUNT=$(json_eval "$OUT" "payload['summary']['global_issue_count']")
assert_eq "$(python3 -c "print(1 if int('$GLOBAL_COUNT') >= 1 else 0)")" "1" \
  "T2.2: root dirty appears as global issue from worktree"

GLOBAL_CODES=$(json_eval "$OUT" "','.join(i['code'] for i in payload['global_issues'])")
assert_contains "$GLOBAL_CODES" "root_checkout_dirty" "T2.3: global issue code is root_checkout_dirty"

# Clean root for remaining tests
git -C "$MAIN_CHECKOUT" checkout -- file.txt 2>/dev/null

# ── T3: Worktree-local issues still block lane mode ─────────────
echo ""
echo "── T3: Local worktree issues block lane mode ──"

# Detach HEAD in the worktree — this is always a blocking lane issue
DETACH_COMMIT="$(git -C "$WORKTREE_DIR" rev-parse HEAD)"
git -C "$WORKTREE_DIR" checkout "$DETACH_COMMIT" >/dev/null 2>&1

OUT="$TMPDIR_BASE/t3.json"
env "${WT_ENV[@]}" bash "$RECONCILE" --lane --json > "$OUT" 2>/dev/null || true

LANE_COUNT=$(json_eval "$OUT" "payload['summary']['lane_issue_count']")
assert_eq "$(python3 -c "print(1 if int('$LANE_COUNT') >= 1 else 0)")" "1" \
  "T3.1: detached HEAD in current worktree is a lane issue"

LANE_CODES=$(json_eval "$OUT" "','.join(i.get('code','') for i in payload['lane_issues'])")
assert_contains "$LANE_CODES" "detached_head" "T3.2: lane issue code is detached_head"

# Lane mode should exit non-zero
env "${WT_ENV[@]}" bash "$RECONCILE" --lane > /dev/null 2>&1 && EXIT_CODE=0 || EXIT_CODE=$?
assert_eq "$(python3 -c "print(1 if int('$EXIT_CODE') > 0 else 0)")" "1" \
  "T3.3: lane mode exits non-zero on local detached HEAD"

# Restore worktree branch
git -C "$WORKTREE_DIR" checkout codex/wave-alpha >/dev/null 2>&1

# ── T4: Root checkout always checked from worktree context ───────
echo ""
echo "── T4: Root checkout checked from worktree context ──"

OUT="$TMPDIR_BASE/t4.json"
env "${WT_ENV[@]}" bash "$RECONCILE" --json > "$OUT" 2>/dev/null || true

ROOT_CHECKED=$(json_eval "$OUT" "payload['summary']['checked_root_checkout']")
assert_eq "$ROOT_CHECKED" "1" "T4.1: root checkout checked even from worktree"

ROOT_PATH=$(json_eval "$OUT" "payload['root_checkout']['path']")
assert_eq "$ROOT_PATH" "$MAIN_CHECKOUT_RESOLVED" "T4.2: root path points to main checkout"

# ── T5: Current worktree appears in worktree rows ────────────────
echo ""
echo "── T5: Current worktree in worktree rows ──"

WT_PATHS=$(json_eval "$OUT" "','.join(w.get('path','') for w in payload['worktrees'])")
assert_contains "$WT_PATHS" "$WORKTREE_DIR_RESOLVED" \
  "T5.1: current worktree appears in worktree_rows"

assert_not_contains "$WT_PATHS" "$MAIN_CHECKOUT_RESOLVED" \
  "T5.2: root checkout not duplicated in worktree_rows"

# ── T6: Gate mode still blocks on everything ─────────────────────
echo ""
echo "── T6: Gate mode blocks globally ──"

# Dirty root again
printf 'dirty\n' >> "$MAIN_CHECKOUT/file.txt"

OUT="$TMPDIR_BASE/t6.json"
env "${WT_ENV[@]}" bash "$RECONCILE" --gate --json > "$OUT" 2>/dev/null || true

TOTAL_ISSUES=$(json_eval "$OUT" "payload['summary']['total_issue_count']")
assert_eq "$(python3 -c "print(1 if int('$TOTAL_ISSUES') >= 1 else 0)")" "1" \
  "T6.1: gate mode counts root dirty as issue"

# Check exit code
env "${WT_ENV[@]}" bash "$RECONCILE" --gate > /dev/null 2>&1 && EXIT_CODE=0 || EXIT_CODE=$?
assert_eq "$(python3 -c "print(1 if int('$EXIT_CODE') > 0 else 0)")" "1" \
  "T6.2: gate mode exits non-zero on root dirty"

# Clean root
git -C "$MAIN_CHECKOUT" checkout -- file.txt 2>/dev/null

# ── T8: Shared root lane contention is blocking ──────────────────
echo ""
echo "── T8: Shared root-lane contention blocks ──"

env SPINE_STATE="$STATE_ROOT" "$HEARTBEAT_POST" \
  --terminal-id SPINE-CONTROL-99 \
  --role control-plane \
  --scope hotspot:operational-gaps \
  --repo-root "$MAIN_CHECKOUT" \
  --branch main >/dev/null

OUT="$TMPDIR_BASE/t8.json"
env "${COMMON_ENV[@]}" bash "$RECONCILE" --lane --json > "$OUT" 2>/dev/null || true

CONTENTIONS=$(json_eval "$OUT" "payload['summary']['blocking_terminal_contention_count']")
assert_eq "$(python3 -c "print(1 if int('$CONTENTIONS') >= 1 else 0)")" "1" \
  "T8.1: blocking terminal contention is counted"

LANE_CODES=$(json_eval "$OUT" "','.join(i.get('code','') for i in payload['lane_issues'])")
if echo "$LANE_CODES" | grep -Eq 'shared_root_checkout_contention|shared_git_index_contention'; then
  pass "T8.2: shared root lane contention blocks lane mode"
else
  fail "T8.2: shared root lane contention blocks lane mode (expected shared_root_checkout_contention or shared_git_index_contention)"
fi

# ── T7: Lane mode passes when only global issues exist ───────────
echo ""
echo "── T7: Lane mode passes with only global issues ──"

# Dirty root (global from worktree perspective)
printf 'dirty\n' >> "$MAIN_CHECKOUT/file.txt"

env "${WT_ENV[@]}" bash "$RECONCILE" --lane > /dev/null 2>&1 && EXIT_CODE=0 || EXIT_CODE=$?
assert_eq "$EXIT_CODE" "0" \
  "T7.1: lane mode exits 0 when only global issues exist"

# Clean root
git -C "$MAIN_CHECKOUT" checkout -- file.txt 2>/dev/null

echo ""
echo "════════════════════════════════════"
echo "pass=$PASS fail=$FAIL"
exit "$FAIL"
