#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
NORMALIZE="$ROOT/ops/plugins/core/ops/bin/worktree-lifecycle-root-normalize"

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

hours_ago_iso() {
  local hours="$1"
  python3 - "$hours" <<'PY'
import sys
from datetime import datetime, timedelta, timezone

hours = float(sys.argv[1])
dt = datetime.now(timezone.utc) - timedelta(hours=hours)
print(dt.strftime("%Y-%m-%dT%H:%M:%S %z"))
PY
}

create_main_stash() {
  local repo_path="$1" age_hours="$2" label="$3"
  local ts
  ts="$(hours_ago_iso "$age_hours")"
  printf '%s\n' "$label" >> "$repo_path/ops/bindings/terminal.worker.catalog.yaml"
  (
    cd "$repo_path" && \
    GIT_AUTHOR_DATE="$ts" \
    GIT_COMMITTER_DATE="$ts" \
    git stash push -m "$label" >/dev/null
  )
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

write_governed_contract() {
  local path="$1"
  cat > "$path" <<'YAML'
status: authoritative
version: 1
governed_surfaces:
  - tracked_output: ops/bindings/terminal.worker.catalog.yaml
  - tracked_output: docs/reference/generated/worker-usage
YAML
}

seed_worker_files() {
  local repo="$1" catalog_text="$2" doc_text="$3"
  mkdir -p "$repo/ops/bindings" "$repo/docs/reference/generated/worker-usage"
  printf '%s\n' "$catalog_text" > "$repo/ops/bindings/terminal.worker.catalog.yaml"
  printf '%s\n' "$doc_text" > "$repo/docs/reference/generated/worker-usage/README.md"
  printf '%s\n' "base" > "$repo/file.txt"
}

echo "worktree lifecycle root normalize tests"
echo "════════════════════════════════════════"

if [[ -x "$NORMALIZE" ]]; then
  pass "root normalize executable present"
else
  fail "root normalize executable present"
  echo "Results: $PASS passed, $FAIL failed"
  exit "$FAIL"
fi

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

REMOTE="$TMPDIR_BASE/remote.git"
LOCAL="$TMPDIR_BASE/local"
UPSTREAM="$TMPDIR_BASE/upstream"
WORKTREE_ROOT="$TMPDIR_BASE/worktrees"
CLONE_ROOT="$TMPDIR_BASE/clones"
STATE_ROOT="$TMPDIR_BASE/state"
RUNTIME_ROOT="$TMPDIR_BASE/runtime"
CONTROL_ROOT_CONTRACT="ops/bindings/terminal.worker.projection.contract.yaml"

git init --bare "$REMOTE" >/dev/null
git clone "$REMOTE" "$LOCAL" >/dev/null 2>&1
git clone "$REMOTE" "$UPSTREAM" >/dev/null 2>&1
for repo in "$LOCAL" "$UPSTREAM"; do
  git -C "$repo" config user.name "Test User"
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" checkout -b main >/dev/null 2>&1 || git -C "$repo" switch main >/dev/null 2>&1
done

seed_worker_files "$LOCAL" "catalog: base" "# Base Worker Usage"
(
  cd "$LOCAL"
  git add ops docs file.txt
  git commit -m "base" >/dev/null
  git push -u origin main >/dev/null 2>&1
)

git -C "$UPSTREAM" fetch origin >/dev/null 2>&1
git -C "$UPSTREAM" reset --hard origin/main >/dev/null

echo ""
echo "── T1: governed generated drift + behind main self-heals ──"
printf '%s\n' "catalog: remote" > "$UPSTREAM/ops/bindings/terminal.worker.catalog.yaml"
printf '%s\n' "# Remote Worker Usage" > "$UPSTREAM/docs/reference/generated/worker-usage/README.md"
(
  cd "$UPSTREAM"
  git add ops docs
  git commit -m "remote update" >/dev/null
  git push origin main >/dev/null 2>&1
)
git -C "$LOCAL" fetch origin >/dev/null 2>&1
create_main_stash "$LOCAL" 96 "ancient diagnostic stash"
printf '%s\n' "catalog: dirty local drift" > "$LOCAL/ops/bindings/terminal.worker.catalog.yaml"
printf '%s\n' "# Dirty Local Worker Usage" > "$LOCAL/docs/reference/generated/worker-usage/README.md"
T1_JSON="$TMPDIR_BASE/t1-root-normalize.json"
(
  cd "$LOCAL"
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_STATE="$STATE_ROOT" \
    SPINE_RUNTIME_ROOT="$RUNTIME_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_WORKTREE_ROOT="$WORKTREE_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_TEMP_CLONE_ROOT="$CLONE_ROOT" \
    SPINE_WORKTREE_ROOT_NORMALIZATION_CONTRACTS="$CONTROL_ROOT_CONTRACT" \
    "$NORMALIZE" --json > "$T1_JSON"
)
assert_eq "$(json_eval "$T1_JSON" 'payload["summary"]["status"]')" "healed" "governed dirty root is healed"
assert_eq "$(json_eval "$T1_JSON" 'payload["summary"]["restored_generated_drift"]')" "True" "governed drift restore recorded"
assert_eq "$(json_eval "$T1_JSON" 'payload["summary"]["fast_forwarded_main"]')" "True" "fast-forward recorded"
assert_eq "$(json_eval "$T1_JSON" 'payload["summary"]["dropped_stashes"]')" "1" "candidate stash dropped"
assert_eq "$(git -C "$LOCAL" rev-parse HEAD)" "$(git -C "$LOCAL" rev-parse origin/main)" "local root fast-forwarded to origin/main"
assert_eq "$(git -C "$LOCAL" status --short | wc -l | tr -d ' ')" "0" "local root clean after heal"
assert_eq "$(git -C "$LOCAL" stash list | wc -l | tr -d ' ')" "0" "candidate main stash dropped"

echo ""
echo "── T2: ungoverned dirt blocks without mutation ──"
printf '%s\n' "manual change" >> "$LOCAL/file.txt"
set +e
t2_out="$(
  cd "$LOCAL" && \
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_STATE="$STATE_ROOT" \
    SPINE_RUNTIME_ROOT="$RUNTIME_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_WORKTREE_ROOT="$WORKTREE_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_TEMP_CLONE_ROOT="$CLONE_ROOT" \
    SPINE_WORKTREE_ROOT_NORMALIZATION_CONTRACTS="$CONTROL_ROOT_CONTRACT" \
    "$NORMALIZE" --brief 2>&1
)"
t2_status=$?
set -e
assert_eq "$t2_status" "1" "ungoverned root dirt blocks"
assert_contains "$t2_out" "FAIL status=blocked" "blocked brief status emitted"
assert_contains "$(git -C "$LOCAL" status --short)" "file.txt" "ungoverned dirty file preserved"
git -C "$LOCAL" restore file.txt >/dev/null

echo ""
echo "── T3: parked root branch matching main switches back to main ──"
git -C "$LOCAL" switch -c feature/root-parking >/dev/null
T3_JSON="$TMPDIR_BASE/t3-root-normalize.json"
(
  cd "$LOCAL"
  env -u SPINE_TARGET_REPO -u SPINE_REPO -u SPINE_CODE \
    SPINE_STATE="$STATE_ROOT" \
    SPINE_RUNTIME_ROOT="$RUNTIME_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_WORKTREE_ROOT="$WORKTREE_ROOT" \
    SPINE_WORKTREE_LIFECYCLE_TEMP_CLONE_ROOT="$CLONE_ROOT" \
    SPINE_WORKTREE_ROOT_NORMALIZATION_CONTRACTS="$CONTROL_ROOT_CONTRACT" \
    "$NORMALIZE" --json > "$T3_JSON"
)
assert_eq "$(json_eval "$T3_JSON" 'payload["summary"]["status"]')" "healed" "parked root branch normalization heals"
assert_eq "$(json_eval "$T3_JSON" 'payload["summary"]["switched_to_main"]')" "True" "switch to main recorded"
assert_eq "$(git -C "$LOCAL" branch --show-current)" "main" "root branch normalized to main"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
