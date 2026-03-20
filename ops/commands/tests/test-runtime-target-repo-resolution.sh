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
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
