#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
RECONCILE="$ROOT/ops/plugins/core/ops/bin/worktree-lifecycle-reconcile"
PLANS_CREATE="$ROOT/ops/plugins/core/lifecycle/bin/planning-plans-create"

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

echo "branch plan linkage tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

TARGET="$TMPDIR_BASE/target"
STATE="$TMPDIR_BASE/state"
mkdir -p "$STATE/loop-scopes" "$STATE/plans"

git init "$TARGET" >/dev/null
git -C "$TARGET" config user.name "Test User"
git -C "$TARGET" config user.email "test@example.com"
printf 'base\n' > "$TARGET/file.txt"
git -C "$TARGET" add file.txt
git -C "$TARGET" commit -m "base" >/dev/null
git -C "$TARGET" branch -M main >/dev/null
git -C "$TARGET" checkout -b codex/deferred-branch >/dev/null
printf 'deferred\n' >> "$TARGET/file.txt"
git -C "$TARGET" add file.txt
git -C "$TARGET" commit -m "deferred branch change" >/dev/null
git -C "$TARGET" checkout main >/dev/null

cat > "$STATE/plans/index.yaml" <<'EOF'
version: "1.0"
updated_at: "2026-03-22"
plans: []
EOF

FIRST_JSON="$TMPDIR_BASE/reconcile-before.json"
(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_STATE="$STATE" \
    "$RECONCILE" --json > "$FIRST_JSON"
)
assert_eq "$(json_eval "$FIRST_JSON" "payload['summary']['checked_local_branches']")" "1" "local branch inventory is exposed"
assert_eq "$(json_eval "$FIRST_JSON" "any(item['code'] == 'branch_missing_plan_linkage' and item['branch'] == 'codex/deferred-branch' for item in payload['issues'])")" "True" "unlinked deferred branch is flagged as lifecycle drift"

cat > "$STATE/loop-scopes/LOOP-DEFERRED-BRANCH-KEEP-20260322.scope.md" <<'EOF'
---
loop_id: LOOP-DEFERRED-BRANCH-KEEP-20260322
created: 2026-03-22
status: planned
owner: "@ronny"
scope: branch
priority: medium
horizon: later
execution_readiness: blocked
execution_mode: single_worker
objective: Preserve deferred branch memory.
---
EOF

PLANS_DB_PATH="$STATE/shared_authority.db" \
PLANS_INDEX_PATH="$STATE/plans/index.yaml" \
PLANS_DIR_PATH="$STATE/plans" \
"$PLANS_CREATE" \
  --plan-id PLAN-DEFERRED-BRANCH-KEEP \
  --loop-id LOOP-DEFERRED-BRANCH-KEEP-20260322 \
  --owner @ronny \
  --horizon later \
  --review-date 2026-03-29 \
  --description "Keep deferred branch memory in plans instead of branch-only state." \
  --branch-ref codex/deferred-branch \
  --worktree-path "$TARGET" \
  --branch-retention-state keep >/dev/null

SECOND_JSON="$TMPDIR_BASE/reconcile-after.json"
(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_STATE="$STATE" \
    "$RECONCILE" --json > "$SECOND_JSON"
)
assert_eq "$(json_eval "$SECOND_JSON" "any(row['branch'] == 'codex/deferred-branch' and row['branch_memory_linked'] for row in payload['local_branches'])")" "True" "linked plan is visible on local branch inventory"
assert_eq "$(json_eval "$SECOND_JSON" "any(item['code'] == 'branch_missing_plan_linkage' and item['branch'] == 'codex/deferred-branch' for item in payload['issues'])")" "False" "plan linkage clears missing-branch-memory issue"
assert_eq "$(json_eval "$SECOND_JSON" "payload['local_branches'][0]['linked_plan_refs']")" "['PLAN-DEFERRED-BRANCH-KEEP']" "local branch carries plan linkage metadata"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
