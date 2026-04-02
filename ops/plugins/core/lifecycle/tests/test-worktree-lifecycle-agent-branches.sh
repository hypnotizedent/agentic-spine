#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
RECONCILE="$ROOT/ops/plugins/core/lifecycle/bin/worktree-lifecycle-reconcile"

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

echo "worktree lifecycle agent branch tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

TARGET="$TMPDIR_BASE/target"
AGENT_WORKTREE="$TMPDIR_BASE/agent-smoke"
TMP_ROOT="$TMPDIR_BASE/runtime/tmp"

git init "$TARGET" >/dev/null
git -C "$TARGET" config user.name "Test User"
git -C "$TARGET" config user.email "test@example.com"
printf 'base\n' > "$TARGET/file.txt"
git -C "$TARGET" add file.txt
git -C "$TARGET" commit -m "base" >/dev/null
git -C "$TARGET" branch -M main >/dev/null

mkdir -p "$(dirname "$AGENT_WORKTREE")"
git -C "$TARGET" worktree add -b worktree-agent-smoke "$AGENT_WORKTREE" main >/dev/null 2>&1
printf 'agent drift\n' >> "$AGENT_WORKTREE/file.txt"

RECONCILE_JSON="$TMPDIR_BASE/reconcile.json"
(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_TMP="$TMP_ROOT" \
    "$RECONCILE" --json > "$RECONCILE_JSON"
)

assert_eq "$(json_eval "$RECONCILE_JSON" 'payload["summary"]["checked_worktrees"]')" "1" "agent worktree is inventoried"
assert_eq "$(json_eval "$RECONCILE_JSON" 'payload["worktrees"][0]["branch"]')" "worktree-agent-smoke" "agent worktree branch is reported"
assert_eq "$(json_eval "$RECONCILE_JSON" '"orphan_branch_no_remote" in payload["worktrees"][0]["issues"]')" "False" "agent worktree is not treated as orphaned lane debt"
assert_eq "$(json_eval "$RECONCILE_JSON" '"local_branch_no_remote" in payload["worktrees"][0]["warnings"]')" "True" "agent worktree still emits local branch warning"
assert_eq "$(json_eval "$RECONCILE_JSON" '"dirty_unowned" in payload["worktrees"][0]["warnings"]')" "True" "agent worktree dirty state remains visible as warning"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
