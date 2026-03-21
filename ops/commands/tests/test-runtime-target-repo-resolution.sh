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

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (expected: $needle)"
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
echo "── T4: schema conventions audit honors current checkout over inherited SPINE_ROOT ──"
mkdir -p "$TARGET/ops/bindings" "$TARGET/ops"
cat > "$TARGET/ops/capabilities.yaml" <<'YAML'
---
status: authoritative
YAML
cat > "$TARGET/ops/bindings/spine.schema.conventions.yaml" <<'YAML'
---
status: authoritative
owner: "@test"
last_verified: 2026-03-20
scope: schema-conventions-test

version: 1
updated_at: "2026-03-20"

policy:
  enforcement_mode: touch_and_fix
  changed_file_enforcement: true
  include_globs:
    - "ops/bindings/**/*.yaml"
  always_validate_files:
    - ops/bindings/spine.schema.conventions.yaml

status_rules:
  canonical_field: status
  allowed_values: [authoritative]
  lifecycle_field: lifecycle
  lifecycle_values: [ready]

date_rules:
  canonical_fields: [created_at, updated_at, closed_at]
  accepted_legacy_fields: [last_verified]
  iso_8601_regex: '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'

field_rules:
  canonical_id_field: id
  canonical_description_field: description
  disallowed_alias_keys: []
  discouraged_alias_keys: []

legacy_alias_rules:
  touch_to_fix_required: true
  legacy_exceptions: []

schema_bound_files: []
YAML
cat > "$TARGET/ops/bindings/service.closure.contract.yaml" <<'YAML'
---
status: authoritative
owner: "@test"
last_verified: 2026-03-20
scope: closure-test

closures: []
YAML
(
  cd "$TARGET"
  git add ops/capabilities.yaml ops/bindings/spine.schema.conventions.yaml ops/bindings/service.closure.contract.yaml
)
t4_out="$(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO SPINE_ROOT="$ROOT" SPINE_REPO="$ROOT" SPINE_CODE="$ROOT" \
    "$ROOT/ops/plugins/core/verify/bin/schema-conventions-audit" --mode staged
)"
assert_eq "$(printf '%s\n' "$t4_out" | grep '^violations:' | awk '{print $2}')" "0" "schema audit uses the current checkout, not inherited SPINE_ROOT"

echo ""
echo "── T5: operator hygiene reconcile honors current checkout over inherited SPINE_ROOT ──"
mkdir -p "$TARGET/debug"
printf 'old-debug\n' > "$TARGET/debug/old.log"
python3 - "$TARGET/debug/old.log" <<'PY'
import os
import sys
import time

ts = time.time() - (45 * 86400)
os.utime(sys.argv[1], (ts, ts))
PY
cat > "$TARGET/ops/bindings/operator.hygiene.contract.yaml" <<YAML
status: authoritative
owner: "@test"
last_verified: 2026-03-21
scope: operator-hygiene-test
version: 2
updated_at: "2026-03-21"
paths:
  archive_root: "$TMPDIR_BASE/archive"
tool_history:
  policies:
    - id: target.operator.hygiene
      status: active
      kind: aged_file_report
      root: "$TARGET/debug"
      retention_days: 30
      execute_by_default: false
YAML
t5_json="$TMPDIR_BASE/t5-operator-hygiene.json"
TARGET_DEBUG_CANON="$(cd "$TARGET" && cd debug && pwd -P)"
(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO SPINE_ROOT="$ROOT" SPINE_REPO="$ROOT" SPINE_CODE="$ROOT" \
    "$ROOT/ops/plugins/core/ops/bin/operator-hygiene-reconcile" --json > "$t5_json"
)
assert_eq "$(python3 - <<'PY' "$t5_json"
import json, sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
print(payload['rows'][0]['id'])
PY
)" "target.operator.hygiene" "operator hygiene reconcile loads target repo contract from current checkout"
assert_eq "$(python3 - <<'PY' "$t5_json"
import json, sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
print(payload['rows'][0]['root'])
PY
)" "$TARGET_DEBUG_CANON" "operator hygiene reconcile reports target repo roots, not inherited spine root"

echo ""
echo "── T6: worker runtime generator writes runtime projection to current checkout, not inherited spine root ──"
WORKER_FIXTURE="$TMPDIR_BASE/worker-fixture"
git init "$WORKER_FIXTURE" >/dev/null
git -C "$WORKER_FIXTURE" config user.name "Test User"
git -C "$WORKER_FIXTURE" config user.email "test@example.com"
mkdir -p "$WORKER_FIXTURE/ops/bindings"
cat > "$WORKER_FIXTURE/ops/bindings/agents.registry.yaml" <<'YAML'
agents: []
YAML
cat > "$WORKER_FIXTURE/ops/bindings/terminal.role.contract.yaml" <<'YAML'
roles:
  - terminal_id: SPINE-CONTROL-01
    terminal_type: control-plane
    status: active
    description: Test control terminal
    domain: core
    capabilities:
      - spine.verify
    write_scope: []
    picker_group: spine
    sort_order: 1
    default_tool: codex
    allowed_tools:
      - codex
YAML
cat > "$WORKER_FIXTURE/ops/bindings/gate.domain.profiles.yaml" <<'YAML'
domains:
  core:
    gate_ids:
      - D3
YAML
cat > "$WORKER_FIXTURE/ops/bindings/gate.agent.profiles.yaml" <<'YAML'
profiles: []
YAML
cat > "$WORKER_FIXTURE/ops/capabilities.yaml" <<'YAML'
capabilities:
  spine.verify:
    description: Test verify capability
    command: ./ops/plugins/core/verify/bin/verify-run fast
    safety: read-only
    approval: auto
    domain: none
YAML
(
  cd "$WORKER_FIXTURE"
  git add ops
  git commit -m "fixture" >/dev/null
)

ROOT_CATALOG_HASH_BEFORE="$(shasum -a 256 "$ROOT/ops/bindings/terminal.worker.catalog.yaml" | awk '{print $1}')"
ROOT_USAGE_HASH_BEFORE="$(shasum -a 256 "$ROOT/docs/reference/generated/worker-usage/README.md" | awk '{print $1}')"
(
  cd "$WORKER_FIXTURE"
  env -u SPINE_TARGET_REPO SPINE_ROOT="$ROOT" SPINE_REPO="$ROOT" SPINE_CODE="$ROOT" \
    python3 "$ROOT/ops/plugins/core/ops/bin/gen-terminal-worker-runtime-v2.py" --target usage >/dev/null
)
ROOT_CATALOG_HASH_AFTER="$(shasum -a 256 "$ROOT/ops/bindings/terminal.worker.catalog.yaml" | awk '{print $1}')"
ROOT_USAGE_HASH_AFTER="$(shasum -a 256 "$ROOT/docs/reference/generated/worker-usage/README.md" | awk '{print $1}')"
assert_eq "$ROOT_CATALOG_HASH_AFTER" "$ROOT_CATALOG_HASH_BEFORE" "worker runtime generator leaves inherited root catalog untouched"
assert_eq "$ROOT_USAGE_HASH_AFTER" "$ROOT_USAGE_HASH_BEFORE" "worker runtime generator leaves inherited root usage docs untouched"
if [[ -f "$WORKER_FIXTURE/runtime/domain-state/projections/worker-usage/README.md" ]]; then
  pass "worker runtime generator writes usage projection under current checkout runtime root"
else
  fail "worker runtime generator writes usage projection under current checkout runtime root"
fi

echo ""
echo "── T7: D377 gate honors current checkout over inherited SPINE_ROOT ──"
D377_FIXTURE="$TMPDIR_BASE/d377-fixture"
MISDIRECT_ROOT="$TMPDIR_BASE/d377-misdirect"
git init "$D377_FIXTURE" >/dev/null
git -C "$D377_FIXTURE" config user.name "Test User"
git -C "$D377_FIXTURE" config user.email "test@example.com"
printf 'fixture\n' > "$D377_FIXTURE/README.md"
git -C "$D377_FIXTURE" add README.md
git -C "$D377_FIXTURE" commit -m "fixture" >/dev/null
git -C "$D377_FIXTURE" branch -M main >/dev/null

git init "$MISDIRECT_ROOT" >/dev/null
git -C "$MISDIRECT_ROOT" config user.name "Test User"
git -C "$MISDIRECT_ROOT" config user.email "test@example.com"
mkdir -p "$MISDIRECT_ROOT/ops/lib" "$MISDIRECT_ROOT/mailroom/logs"
cp "$ROOT/ops/lib/runtime-paths.sh" "$MISDIRECT_ROOT/ops/lib/runtime-paths.sh"
printf 'misdirect\n' > "$MISDIRECT_ROOT/README.md"
git -C "$MISDIRECT_ROOT" add README.md ops/lib/runtime-paths.sh
git -C "$MISDIRECT_ROOT" commit -m "misdirect" >/dev/null
git -C "$MISDIRECT_ROOT" branch -M main >/dev/null

set +e
t7_out="$(
  cd "$D377_FIXTURE"
  env SPINE_ROOT="$MISDIRECT_ROOT" "$ROOT/surfaces/verify/d377-mailroom-runtime-split-brain-lock.sh" 2>&1
)"
t7_status=$?
set -e
assert_eq "$t7_status" "0" "D377 uses current checkout instead of inherited SPINE_ROOT"
assert_contains "$t7_out" "D377 PASS" "D377 reports pass for clean target repo"

echo ""
echo "── T8: D396 gate honors current checkout and allows git worktree .git files ──"
D396_FIXTURE="$TMPDIR_BASE/d396-fixture"
D396_WORKTREE_PARENT="$TMPDIR_BASE/d396-worktrees"
D396_WORKTREE="$D396_WORKTREE_PARENT/check"
MISDIRECT_ROOT_T8="$TMPDIR_BASE/d396-misdirect"
git init "$D396_FIXTURE" >/dev/null
git -C "$D396_FIXTURE" config user.name "Test User"
git -C "$D396_FIXTURE" config user.email "test@example.com"
mkdir -p "$D396_FIXTURE/bin" "$D396_FIXTURE/docs" "$D396_FIXTURE/fixtures" "$D396_FIXTURE/ops/lib" "$D396_FIXTURE/surfaces/verify"
printf 'fixture\n' > "$D396_FIXTURE/README.md"
printf 'keep\n' > "$D396_FIXTURE/bin/.keep"
printf 'keep\n' > "$D396_FIXTURE/docs/.keep"
printf 'keep\n' > "$D396_FIXTURE/fixtures/.keep"
cp "$ROOT/ops/lib/runtime-paths.sh" "$D396_FIXTURE/ops/lib/runtime-paths.sh"
cp "$ROOT/surfaces/verify/d396-boring-root-model-lock.sh" "$D396_FIXTURE/surfaces/verify/d396-boring-root-model-lock.sh"
git -C "$D396_FIXTURE" add README.md bin docs fixtures ops/lib/runtime-paths.sh surfaces/verify/d396-boring-root-model-lock.sh
git -C "$D396_FIXTURE" commit -m "fixture" >/dev/null
git -C "$D396_FIXTURE" branch -M main >/dev/null
mkdir -p "$D396_WORKTREE_PARENT"
git -C "$D396_FIXTURE" worktree add "$D396_WORKTREE" -b check >/dev/null

git init "$MISDIRECT_ROOT_T8" >/dev/null
git -C "$MISDIRECT_ROOT_T8" config user.name "Test User"
git -C "$MISDIRECT_ROOT_T8" config user.email "test@example.com"
mkdir -p "$MISDIRECT_ROOT_T8/ops/lib" "$MISDIRECT_ROOT_T8/mailroom"
cp "$ROOT/ops/lib/runtime-paths.sh" "$MISDIRECT_ROOT_T8/ops/lib/runtime-paths.sh"
printf 'misdirect\n' > "$MISDIRECT_ROOT_T8/README.md"
git -C "$MISDIRECT_ROOT_T8" add README.md ops/lib/runtime-paths.sh
git -C "$MISDIRECT_ROOT_T8" commit -m "misdirect" >/dev/null
git -C "$MISDIRECT_ROOT_T8" branch -M main >/dev/null

set +e
t8_out="$(
  cd "$D396_WORKTREE"
  env SPINE_ROOT="$MISDIRECT_ROOT_T8" "$D396_WORKTREE/surfaces/verify/d396-boring-root-model-lock.sh" 2>&1
)"
t8_status=$?
set -e
assert_eq "$t8_status" "0" "D396 uses current checkout instead of inherited SPINE_ROOT"
assert_contains "$t8_out" "D396 PASS" "D396 accepts git worktree .git file roots"

echo ""
echo "── T9: D397 gate honors current checkout over inherited SPINE_ROOT ──"
D397_FIXTURE="$TMPDIR_BASE/d397-fixture"
MISDIRECT_ROOT_T9="$TMPDIR_BASE/d397-misdirect"
D397_EXTERNAL_ROOT="$TMPDIR_BASE/d397-external"
D397_RUNTIME_ROOT="$D397_EXTERNAL_ROOT/runtime"
D397_MAILROOM_ROOT="$D397_RUNTIME_ROOT/mailroom"
D397_STATE_ROOT="$D397_RUNTIME_ROOT/state"
D397_LOGS_ROOT="$D397_RUNTIME_ROOT/logs"
D397_EVIDENCE_ROOT="$D397_EXTERNAL_ROOT/evidence"
D397_RECEIPTS_ROOT="$D397_EVIDENCE_ROOT/sessions"
D397_VERIFY_ROOT="$D397_EVIDENCE_ROOT/verify"
D397_DATA_ROOT="$D397_EXTERNAL_ROOT/data"
D397_BACKUPS_ROOT="$D397_EXTERNAL_ROOT/backups"
D397_FOUNDATION_ROOT="$D397_EXTERNAL_ROOT/foundation"

git init "$D397_FIXTURE" >/dev/null
git -C "$D397_FIXTURE" config user.name "Test User"
git -C "$D397_FIXTURE" config user.email "test@example.com"
printf 'fixture\n' > "$D397_FIXTURE/README.md"
git -C "$D397_FIXTURE" add README.md
git -C "$D397_FIXTURE" commit -m "fixture" >/dev/null
git -C "$D397_FIXTURE" branch -M main >/dev/null

mkdir -p "$MISDIRECT_ROOT_T9/mailroom" "$MISDIRECT_ROOT_T9/runtime"
mkdir -p \
  "$D397_MAILROOM_ROOT" \
  "$D397_STATE_ROOT" \
  "$D397_LOGS_ROOT" \
  "$D397_RECEIPTS_ROOT" \
  "$D397_VERIFY_ROOT" \
  "$D397_DATA_ROOT" \
  "$D397_BACKUPS_ROOT" \
  "$D397_FOUNDATION_ROOT/docs/agents" \
  "$D397_FOUNDATION_ROOT/docs/archive" \
  "$D397_FOUNDATION_ROOT/docs/product" \
  "$D397_FOUNDATION_ROOT/docs/reference" \
  "$D397_FOUNDATION_ROOT/ops/domains" \
  "$D397_FOUNDATION_ROOT/ops/infra"

set +e
t9_out="$(
  cd "$D397_FIXTURE"
  env -u SPINE_TARGET_REPO -u SPINE_REPO \
    SPINE_ROOT="$MISDIRECT_ROOT_T9" \
    SPINE_CODE="$ROOT" \
    SPINE_RUNTIME_ROOT="$D397_RUNTIME_ROOT" \
    SPINE_MAILROOM_ROOT="$D397_MAILROOM_ROOT" \
    SPINE_STATE="$D397_STATE_ROOT" \
    SPINE_LOGS="$D397_LOGS_ROOT" \
    SPINE_EVIDENCE_ROOT="$D397_EVIDENCE_ROOT" \
    SPINE_RECEIPTS="$D397_RECEIPTS_ROOT" \
    SPINE_VERIFY_ROOT="$D397_VERIFY_ROOT" \
    SPINE_DATA_ROOT="$D397_DATA_ROOT" \
    SPINE_BACKUPS_ROOT="$D397_BACKUPS_ROOT" \
    SPINE_FOUNDATION_ROOT="$D397_FOUNDATION_ROOT" \
    "$ROOT/surfaces/verify/d397-externalized-runtime-evidence-lock.sh" 2>&1
)"
t9_status=$?
set -e
assert_eq "$t9_status" "0" "D397 uses current checkout instead of inherited SPINE_ROOT"
assert_contains "$t9_out" "D397 PASS" "D397 reports pass for clean target repo"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
