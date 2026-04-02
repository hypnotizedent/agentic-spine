#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
RECONCILE="$ROOT/ops/plugins/core/lifecycle/bin/worktree-lifecycle-reconcile"
PLANS_CREATE="$ROOT/ops/plugins/core/lifecycle/bin/planning-plans-create"
PLANS_RECONCILE="$ROOT/ops/plugins/core/lifecycle/bin/planning-plans-reconcile"
LOOPS_CREATE="$ROOT/ops/plugins/core/lifecycle/bin/loops-create"
HANDOFF_CREATE="$ROOT/ops/plugins/core/session/bin/session-handoff-create"

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
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$label"
  else
    fail "$label (missing '$needle')"
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

missing_scope_output="$(
  PLANS_DB_PATH="$STATE/shared_authority.db" \
  PLANS_INDEX_PATH="$STATE/plans/index.yaml" \
  PLANS_DIR_PATH="$STATE/plans" \
  "$PLANS_CREATE" \
    --plan-id PLAN-MISSING-SCOPE \
    --loop-id LOOP-MISSING-SCOPE-20260322 \
    --owner @ronny \
    --horizon later \
    --review-date 2026-03-29 \
    --description "Should fail when source loop scope does not exist." \
    2>&1 || true
)"
assert_contains "$missing_scope_output" "source_loop_id must resolve to a real scope file" "plan creation rejects nonexistent source loop scope"

FIRST_JSON="$TMPDIR_BASE/reconcile-before.json"
(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_STATE="$STATE" \
    "$RECONCILE" --json > "$FIRST_JSON"
)
assert_eq "$(json_eval "$FIRST_JSON" "payload['summary']['checked_local_branches']")" "1" "local branch inventory is exposed"
assert_eq "$(json_eval "$FIRST_JSON" "any(item['code'] == 'branch_missing_plan_linkage' and item['branch'] == 'codex/deferred-branch' for item in payload['issues'])")" "True" "unlinked deferred branch is flagged as lifecycle drift"

loop_json="$(
  SPINE_STATE="$STATE" \
  "$LOOPS_CREATE" \
    --name "loop-deferred-branch-keep-20260322" \
    --objective "Preserve deferred branch memory." \
    --priority medium \
    --horizon later \
    --readiness blocked \
    --execution-mode single_worker \
    --json
)"
LOOP_ID="$(printf '%s' "$loop_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["loop_id"])')"
LOOP_SCOPE_FILE="$(printf '%s' "$loop_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["scope_file"])')"
TODAY_UTC="$(date -u +%Y%m%d)"
assert_eq "$LOOP_ID" "LOOP-DEFERRED-BRANCH-KEEP-$TODAY_UTC" "loops-create json returns canonical loop id"
assert_eq "$LOOP_SCOPE_FILE" "$STATE/loop-scopes/$LOOP_ID.scope.md" "loops-create json exposes canonical scope path"

HANDOFF_JSON="$(
  SPINE_STATE="$STATE" \
  "$HANDOFF_CREATE" \
    --summary "Park deferred branch memory in mailroom handoff state." \
    --loops "$LOOP_ID" \
    --kind parked_lane \
    --review-date 2026-03-29 \
    --branch-refs codex/deferred-branch \
    --worktree-paths "$TARGET" \
    --json
)"
HANDOFF_ID="$(printf '%s' "$HANDOFF_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"

HANDOFF_JSON_RECONCILE="$TMPDIR_BASE/reconcile-handoff.json"
(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_STATE="$STATE" \
    "$RECONCILE" --json > "$HANDOFF_JSON_RECONCILE"
)
assert_eq "$(json_eval "$HANDOFF_JSON_RECONCILE" "any(row['branch'] == 'codex/deferred-branch' and row['branch_memory_linked'] for row in payload['local_branches'])")" "True" "parked handoff also counts as branch memory linkage"
assert_eq "$(json_eval "$HANDOFF_JSON_RECONCILE" "any(item['code'] == 'branch_missing_plan_linkage' and item['branch'] == 'codex/deferred-branch' for item in payload['issues'])")" "False" "parked handoff clears missing branch memory issue"
assert_eq "$(json_eval "$HANDOFF_JSON_RECONCILE" "payload['local_branches'][0]['linked_handoff_refs']")" "['$HANDOFF_ID']" "local branch inventory exposes parked handoff linkage"

PLANS_DB_PATH="$STATE/shared_authority.db" \
PLANS_INDEX_PATH="$STATE/plans/index.yaml" \
PLANS_DIR_PATH="$STATE/plans" \
"$PLANS_CREATE" \
  --plan-id PLAN-DEFERRED-BRANCH-KEEP \
  --loop-id "$LOOP_ID" \
  --owner @ronny \
  --horizon later \
  --review-date 2026-03-29 \
  --description "Keep deferred branch memory in plans instead of branch-only state." \
  --branch-ref codex/deferred-branch \
  --worktree-path "$TARGET" \
  --branch-retention-state keep >/dev/null

PLAN_DOC="$STATE/plans/PLAN-DEFERRED-BRANCH-KEEP.md"
python3 - "$PLAN_DOC" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("source_loop_id: `LOOP-DEFERRED-BRANCH-KEEP-", "source_loop_id: `LOOP-DEFERRED-BRANCH-KEEP-STALE-"), encoding="utf-8")
PY

reconcile_check_output="$(
  PLANS_DB_PATH="$STATE/shared_authority.db" \
  PLANS_INDEX_PATH="$STATE/plans/index.yaml" \
  PLANS_DIR_PATH="$STATE/plans" \
  "$PLANS_RECONCILE" --check 2>&1 || true
)"
assert_contains "$reconcile_check_output" "stale placeholder plan docs: 1" "reconcile check detects stale placeholder plan docs"

PLANS_DB_PATH="$STATE/shared_authority.db" \
PLANS_INDEX_PATH="$STATE/plans/index.yaml" \
PLANS_DIR_PATH="$STATE/plans" \
"$PLANS_RECONCILE" --fix >/dev/null
assert_contains "$(cat "$PLAN_DOC")" "source_loop_id: \`$LOOP_ID\`" "reconcile fix refreshes placeholder doc from authority"

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
