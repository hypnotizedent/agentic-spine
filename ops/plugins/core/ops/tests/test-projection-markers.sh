#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

GEN_WORKER="$ROOT/ops/plugins/core/ops/bin/gen-terminal-worker-runtime-v2.py"
GEN_BOOT="$ROOT/ops/plugins/core/ops/bin/gen-boot-entry-surface.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label (expected: $needle)"
  fi
}

echo "projection marker coverage tests"
echo "════════════════════════════════════════"

worker_check_log="$(mktemp)"
boot_check_log="$(mktemp)"
trap 'rm -f "$worker_check_log" "$boot_check_log"' EXIT

if python3 "$GEN_WORKER" --root "$ROOT" --target catalog --target launcher --target usage --check >"$worker_check_log" 2>&1; then
  pass "worker generator check passes"
else
  fail "worker generator check passes"
  cat "$worker_check_log" >&2
fi

if "$GEN_BOOT" --check >"$boot_check_log" 2>&1; then
  pass "boot entry generator check passes"
else
  fail "boot entry generator check passes"
  cat "$boot_check_log" >&2
fi

worker_catalog="$(cat "$ROOT/ops/bindings/terminal.worker.catalog.yaml")"
launcher_view="$(cat "$ROOT/ops/bindings/terminal.launcher.view.yaml")"
worker_index="$(cat "$ROOT/docs/reference/generated/worker-usage/README.md")"
control_usage="$(cat "$ROOT/docs/reference/generated/worker-usage/SPINE-CONTROL-01.md")"
boot_surface="$(cat "$ROOT/docs/reference/generated/BOOT_ENTRY_SURFACE.md")"

assert_contains "$worker_catalog" "authority_state: projection" "worker catalog marks itself as projection"
assert_contains "$worker_catalog" "projection_of:" "worker catalog carries projection coverage"
assert_contains "$launcher_view" "authority_state: projection" "launcher view marks itself as projection"
assert_contains "$worker_index" "authority_state: projection" "worker usage index marks itself as projection"
assert_contains "$control_usage" "authority_state: projection" "worker usage surface marks itself as projection"
assert_contains "$control_usage" "Canonical session entry: \`./bin/ops cap run session.v3.attach -- --allow-no-loop\`" "worker usage reflects canonical V3 attach"
assert_contains "$boot_surface" "authority_state: projection" "boot entry surface marks itself as projection"
assert_contains "$boot_surface" "projection_of: ops/bindings/entry.boot.surface.contract.yaml" "boot entry surface has explicit projection source"
assert_contains "$boot_surface" "./bin/ops cap run session.v3.attach -- --allow-no-loop" "boot entry surface reflects canonical V3 attach"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
