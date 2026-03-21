#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
AUDIT="$ROOT/ops/plugins/core/verify/bin/snapshot-surface-audit"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

fixture_root() {
  local dir="$1"
  mkdir -p "$dir/ops/bindings" "$dir/ops/plugins/demo/bin"
  cat > "$dir/ops/bindings/snapshot.surface.contract.yaml" <<'YAML'
status: authoritative
version: 1
policy:
  description_prefix: "Read-only by default:"
  promotion_suffix: "tracked promotion requires --apply."
governed_surfaces:
  - capability: demo.snapshot
    tracked_binding: ops/bindings/demo.snapshot.yaml
automation_surfaces:
  - path: ops/plugins/demo/bin/demo-refresh
YAML
}

write_pass_fixture() {
  local dir="$1"
  fixture_root "$dir"
  cat > "$dir/ops/capabilities.yaml" <<'YAML'
demo.snapshot:
  description: 'Read-only by default: build demo snapshot to runtime/domain-state/snapshots/demo.snapshot.yaml; tracked promotion requires --apply.'
  safety: read-only
  script_path: ./ops/plugins/demo/bin/demo-snapshot
YAML
  cat > "$dir/ops/bindings/routing.dispatch.yaml" <<'YAML'
demo.snapshot:
  description: 'Read-only by default: build demo snapshot to runtime/domain-state/snapshots/demo.snapshot.yaml; tracked promotion requires --apply.'
  safety: read-only
YAML
  cat > "$dir/ops/plugins/demo/bin/demo-snapshot" <<'SH'
#!/usr/bin/env bash
snapshot_surface_init "ops/bindings/demo.snapshot.yaml" "$@"
echo --apply --check
SH
  cat > "$dir/ops/plugins/demo/bin/demo-refresh" <<'SH'
#!/usr/bin/env bash
echo refresh
SH
  chmod +x "$dir/ops/plugins/demo/bin/demo-snapshot" "$dir/ops/plugins/demo/bin/demo-refresh"
}

write_fail_fixture() {
  local dir="$1"
  fixture_root "$dir"
  cat > "$dir/ops/capabilities.yaml" <<'YAML'
demo.snapshot:
  description: 'Read-only: demo snapshot'
  safety: mutating
  script_path: ./ops/plugins/demo/bin/demo-snapshot
YAML
  cat > "$dir/ops/bindings/routing.dispatch.yaml" <<'YAML'
demo.snapshot:
  description: 'Read-only: demo snapshot'
  safety: mutating
YAML
  cat > "$dir/ops/plugins/demo/bin/demo-snapshot" <<'SH'
#!/usr/bin/env bash
TRACKED_OUTPUT="$ROOT/ops/bindings/demo.snapshot.yaml"
git add ops/bindings/demo.snapshot.yaml
SH
  cat > "$dir/ops/plugins/demo/bin/demo-refresh" <<'SH'
#!/usr/bin/env bash
git commit -m bad
SH
  chmod +x "$dir/ops/plugins/demo/bin/demo-snapshot" "$dir/ops/plugins/demo/bin/demo-refresh"
}

echo "snapshot-surface-audit tests"
echo "════════════════════════════════════════"

if [[ -x "$AUDIT" ]]; then
  pass "audit executable present"
else
  fail "audit executable present"
  echo "Results: $PASS passed, $FAIL failed"
  exit "$FAIL"
fi

ok_dir="$(mktemp -d)"
bad_dir="$(mktemp -d)"
trap 'rm -rf "$ok_dir" "$bad_dir"' EXIT

write_pass_fixture "$ok_dir"
write_fail_fixture "$bad_dir"

if ok_out="$("$AUDIT" --root "$ok_dir" --brief 2>&1)"; then
  pass "pass fixture exits 0"
else
  fail "pass fixture exits 0"
  echo "$ok_out" >&2
fi
if echo "$ok_out" | grep -q '^PASS issues=0 '; then
  pass "pass fixture brief reports zero issues"
else
  fail "pass fixture brief reports zero issues"
fi

set +e
bad_out="$("$AUDIT" --root "$bad_dir" 2>&1)"
bad_rc=$?
set -e
if [[ "$bad_rc" -eq 1 ]]; then
  pass "fail fixture exits 1"
else
  fail "fail fixture exits 1 (rc=$bad_rc)"
fi
if echo "$bad_out" | grep -q 'capability_safety_not_read_only'; then
  pass "fail fixture reports safety drift"
else
  fail "fail fixture reports safety drift"
fi
if echo "$bad_out" | grep -q 'tracked_default_writepath'; then
  pass "fail fixture reports tracked default writepath"
else
  fail "fail fixture reports tracked default writepath"
fi
if echo "$bad_out" | grep -q 'automation_implicit_tracked_git_mutation'; then
  pass "fail fixture reports automation git mutation"
else
  fail "fail fixture reports automation git mutation"
fi

if live_out="$("$AUDIT" --brief 2>&1)"; then
  pass "live audit exits 0"
else
  fail "live audit exits 0"
  echo "$live_out" >&2
fi
if echo "$live_out" | grep -q '^PASS issues=0 '; then
  pass "live audit brief reports zero issues"
else
  fail "live audit brief reports zero issues"
fi

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
