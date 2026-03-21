#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init
HELPER="$ROOT/ops/plugins/domains/ha/lib/ha-snapshot-common.sh"

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

echo "ha snapshot runtime-first tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

TARGET="$TMPDIR_BASE/target"
INHERITED="$TMPDIR_BASE/inherited"
mkdir -p "$TARGET" "$INHERITED"
git init "$TARGET" >/dev/null
git -C "$TARGET" config user.name "Test User"
git -C "$TARGET" config user.email "test@example.com"
printf 'base\n' > "$TARGET/README.md"
git -C "$TARGET" add README.md
git -C "$TARGET" commit -m "base" >/dev/null
git -C "$TARGET" branch -M main >/dev/null

git init "$INHERITED" >/dev/null
git -C "$INHERITED" config user.name "Test User"
git -C "$INHERITED" config user.email "test@example.com"
printf 'base\n' > "$INHERITED/README.md"
git -C "$INHERITED" add README.md
git -C "$INHERITED" commit -m "base" >/dev/null
git -C "$INHERITED" branch -M main >/dev/null

TARGET_CANON="$(cd "$TARGET" && pwd -P)"
INHERITED_CANON="$(cd "$INHERITED" && pwd -P)"

echo ""
echo "── T1: current checkout wins over ambient SPINE_ROOT ──"
t1_out="$(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO SPINE_ROOT="$INHERITED" SPINE_REPO="$INHERITED" SPINE_CODE="$ROOT" bash -lc '
    source "'"$HELPER"'"
    ha_snapshot_init "ha.addons.yaml"
    printf "%s|%s|%s\n" "$HA_SNAPSHOT_ROOT" "$HA_SNAPSHOT_OUTPUT" "$HA_SNAPSHOT_TRACKED_OUTPUT"
  '
)"
t1_root="${t1_out%%|*}"
t1_rest="${t1_out#*|}"
t1_output="${t1_rest%%|*}"
t1_tracked="${t1_rest##*|}"
assert_eq "$t1_root" "$TARGET_CANON" "snapshot helper resolves target repo from current checkout"
assert_eq "$t1_output" "$TARGET_CANON/runtime/domain-state/snapshots/ha.addons.yaml" "snapshot helper defaults to runtime output"
assert_eq "$t1_tracked" "$TARGET_CANON/ops/bindings/ha.addons.yaml" "snapshot helper tracks the canonical binding path separately"

echo ""
echo "── T2: explicit SPINE_TARGET_REPO overrides inherited roots ──"
t2_out="$(
  cd "$TARGET"
  env SPINE_TARGET_REPO="$INHERITED" SPINE_ROOT="$TARGET" SPINE_REPO="$TARGET" SPINE_CODE="$ROOT" bash -lc '
    source "'"$HELPER"'"
    ha_snapshot_init "ha.addons.yaml"
    printf "%s|%s\n" "$HA_SNAPSHOT_ROOT" "$HA_SNAPSHOT_OUTPUT"
  '
)"
t2_root="${t2_out%%|*}"
t2_output="${t2_out##*|}"
assert_eq "$t2_root" "$INHERITED_CANON" "explicit target repo wins"
assert_eq "$t2_output" "$INHERITED_CANON/runtime/domain-state/snapshots/ha.addons.yaml" "explicit target repo controls runtime output path"

echo ""
echo "── T3: runtime source resolution prefers fresh runtime snapshots ──"
mkdir -p "$TARGET/runtime/domain-state/snapshots" "$TARGET/ops/bindings"
printf 'runtime\n' > "$TARGET/runtime/domain-state/snapshots/z2m.devices.yaml"
printf 'tracked\n' > "$TARGET/ops/bindings/z2m.devices.yaml"
t3_out="$(
  cd "$TARGET"
  env -u SPINE_TARGET_REPO SPINE_ROOT="$INHERITED" SPINE_REPO="$INHERITED" SPINE_CODE="$ROOT" bash -lc '
    source "'"$HELPER"'"
    printf "%s\n" "$(ha_snapshot_resolve_source_path "'"$TARGET_CANON"'" "ops/bindings/z2m.devices.yaml")"
  '
)"
assert_eq "$t3_out" "$TARGET_CANON/runtime/domain-state/snapshots/z2m.devices.yaml" "runtime source path wins when present"

echo ""
echo "── T4: semantic no-op apply ignores volatile timestamp fields ──"
mkdir -p "$TARGET/ops/bindings"
cat > "$TARGET/ops/bindings/ha.addons.yaml" <<'YAML'
schema_version: "1.0"
generated: "2026-03-20T00:00:00Z"
source: ha.addons.snapshot
addons:
  - slug: test-addon
    state: started
YAML
cat > "$TMPDIR_BASE/ha.addons.candidate.yaml" <<'YAML'
schema_version: "1.0"
generated: "2026-03-21T00:00:00Z"
source: ha.addons.snapshot
addons:
  - slug: test-addon
    state: started
YAML
t4_action="$(
  env bash -lc '
    source "'"$HELPER"'"
    HA_SNAPSHOT_MODE="apply"
    HA_SNAPSHOT_OUTPUT="'"$TARGET_CANON"'/ops/bindings/ha.addons.yaml"
    HA_SNAPSHOT_TRACKED_OUTPUT="$HA_SNAPSHOT_OUTPUT"
    ha_snapshot_finalize "'"$TMPDIR_BASE"'/ha.addons.candidate.yaml"
    printf "%s\n" "$HA_SNAPSHOT_FINAL_ACTION"
  '
)"
t4_generated="$(grep '^generated:' "$TARGET/ops/bindings/ha.addons.yaml")"
assert_eq "$t4_action" "semantic-noop" "apply mode skips timestamp-only churn"
assert_eq "$t4_generated" 'generated: "2026-03-20T00:00:00Z"' "tracked file stays unchanged on semantic no-op"

echo ""
echo "── T5: semantic apply still writes real content changes ──"
cat > "$TMPDIR_BASE/ha.addons.changed.yaml" <<'YAML'
schema_version: "1.0"
generated: "2026-03-21T00:00:00Z"
source: ha.addons.snapshot
addons:
  - slug: test-addon
    state: stopped
YAML
t5_action="$(
  env bash -lc '
    source "'"$HELPER"'"
    HA_SNAPSHOT_MODE="apply"
    HA_SNAPSHOT_OUTPUT="'"$TARGET_CANON"'/ops/bindings/ha.addons.yaml"
    HA_SNAPSHOT_TRACKED_OUTPUT="$HA_SNAPSHOT_OUTPUT"
    ha_snapshot_finalize "'"$TMPDIR_BASE"'/ha.addons.changed.yaml"
    printf "%s\n" "$HA_SNAPSHOT_FINAL_ACTION"
  '
)"
t5_state="$(grep 'state:' "$TARGET/ops/bindings/ha.addons.yaml" | head -1 | xargs)"
assert_eq "$t5_action" "wrote" "apply mode writes real content changes"
assert_eq "$t5_state" "state: stopped" "tracked binding updates when semantic content changes"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
