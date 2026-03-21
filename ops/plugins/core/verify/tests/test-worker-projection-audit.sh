#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "${ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
AUDIT="$ROOT/ops/plugins/core/verify/bin/worker-projection-audit"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

fixture_root() {
  local dir="$1"
  mkdir -p \
    "$dir/ops/bindings" \
    "$dir/ops/plugins/core/ops/bin" \
    "$dir/docs/reference/generated/worker-usage"
  cat > "$dir/ops/bindings/terminal.worker.projection.contract.yaml" <<'YAML'
status: authoritative
owner: "@test"
last_verified: 2026-03-21
scope: terminal-worker-projection-governance
version: 1
updated_at: "2026-03-21"
policy:
  authority_binding: ops/bindings/terminal.worker.catalog.yaml
  tracked_usage_root: docs/reference/generated/worker-usage
  runtime_usage_root: runtime/domain-state/projections/worker-usage
generator:
  path: ops/plugins/core/ops/bin/gen-terminal-worker-runtime-v2.py
governed_surfaces:
  - target: catalog
    wrapper: ops/plugins/core/ops/bin/gen-worker-catalog.sh
    tracked_output: ops/bindings/terminal.worker.catalog.yaml
  - target: dispatch
    wrapper: ops/plugins/core/ops/bin/gen-routing-dispatch.sh
    tracked_output: ops/bindings/routing.dispatch.yaml
  - target: launcher
    wrapper: ops/plugins/core/ops/bin/gen-launcher-view.sh
    tracked_output: ops/bindings/terminal.launcher.view.yaml
  - target: usage
    wrapper: ops/plugins/core/ops/bin/gen-worker-usage-docs.sh
    tracked_output: docs/reference/generated/worker-usage
    runtime_output: runtime/domain-state/projections/worker-usage
YAML
  cat > "$dir/docs/reference/generated/worker-usage/README.md" <<'MD'
---
status: generated
last_verified: 2026-03-21
---
MD
}

write_pass_fixture() {
  local dir="$1"
  fixture_root "$dir"
  cat > "$dir/ops/plugins/core/ops/bin/gen-terminal-worker-runtime-v2.py" <<'PY'
#!/usr/bin/env python3
WORKER_USAGE_RUNTIME_REL = "runtime/domain-state/projections/worker-usage"
def _resolve_root(value): return value
def _semantic_equal(kind, current, incoming): return current == incoming
if __name__ == "__main__":
    print("--apply")
PY
  cat > "$dir/ops/plugins/core/ops/bin/gen-worker-catalog.sh" <<'SH'
#!/usr/bin/env bash
spine_paths_init
echo --root "$ROOT" --apply --check >/dev/null
exit 0
SH
  cat > "$dir/ops/plugins/core/ops/bin/gen-routing-dispatch.sh" <<'SH'
#!/usr/bin/env bash
spine_paths_init
echo --root "$ROOT" --apply --check >/dev/null
exit 0
SH
  cat > "$dir/ops/plugins/core/ops/bin/gen-launcher-view.sh" <<'SH'
#!/usr/bin/env bash
spine_paths_init
echo --root "$ROOT" --apply --check >/dev/null
exit 0
SH
  cat > "$dir/ops/plugins/core/ops/bin/gen-worker-usage-docs.sh" <<'SH'
#!/usr/bin/env bash
spine_paths_init
echo --root "$ROOT" --apply --check >/dev/null
for arg in "$@"; do
  case "$arg" in
    --usage-output-dir=*)
      out="${arg#*=}"
      mkdir -p "$out"
      printf '%s\n' '# Worker Usage' > "$out/README.md"
      printf '%s\n' '# Worker Doc' > "$out/SPINE-CONTROL-01.md"
      ;;
  esac
done
exit 0
SH
  chmod +x "$dir"/ops/plugins/core/ops/bin/*
}

write_fail_fixture() {
  local dir="$1"
  fixture_root "$dir"
  cat > "$dir/ops/plugins/core/ops/bin/gen-terminal-worker-runtime-v2.py" <<'PY'
#!/usr/bin/env python3
print("bad")
PY
  cat > "$dir/ops/plugins/core/ops/bin/gen-worker-catalog.sh" <<'SH'
#!/usr/bin/env bash
exit 1
SH
  cat > "$dir/ops/plugins/core/ops/bin/gen-routing-dispatch.sh" <<'SH'
#!/usr/bin/env bash
exit 1
SH
  cat > "$dir/ops/plugins/core/ops/bin/gen-launcher-view.sh" <<'SH'
#!/usr/bin/env bash
exit 1
SH
  cat > "$dir/ops/plugins/core/ops/bin/gen-worker-usage-docs.sh" <<'SH'
#!/usr/bin/env bash
exit 1
SH
  chmod +x "$dir"/ops/plugins/core/ops/bin/*
}

echo "worker-projection-audit tests"
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
if echo "$bad_out" | grep -q 'target_repo_resolution_missing'; then
  pass "fail fixture reports generator target repo drift"
else
  fail "fail fixture reports generator target repo drift"
fi
if echo "$bad_out" | grep -q 'tracked_surface_drift'; then
  pass "fail fixture reports wrapper drift"
else
  fail "fail fixture reports wrapper drift"
fi

if live_out="$(
  cd "$ROOT"
  env \
    SPINE_TARGET_REPO="$bad_dir" \
    SPINE_ROOT="$bad_dir" \
    SPINE_REPO="$bad_dir" \
    SPINE_CODE="$bad_dir" \
    "$AUDIT" --brief 2>&1
)"; then
  pass "live audit exits 0 under stale env"
else
  fail "live audit exits 0 under stale env"
  echo "$live_out" >&2
fi
if echo "$live_out" | grep -q '^PASS issues=0 '; then
  pass "live audit brief reports zero issues under stale env"
else
  fail "live audit brief reports zero issues under stale env"
fi

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
