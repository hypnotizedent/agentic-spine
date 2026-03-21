#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "${ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
PROJECTION="$ROOT/ops/plugins/core/authority/bin/spine-self-governance-projection-build"
STATUS="$ROOT/ops/plugins/core/verify/bin/spine-self-governance-status"
TELEMETRY="$ROOT/ops/plugins/core/evidence/bin/spine-surface-usage-telemetry"
GATE="$ROOT/surfaces/verify/d415-spine-self-governance-lifecycle-lock.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (expected: $needle)"
  fi
}

make_stub_repo() {
  local dir="$1"
  git init "$dir" >/dev/null
  git -C "$dir" config user.name "Test User"
  git -C "$dir" config user.email "test@example.com"
  printf 'stub\n' > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -m "stub" >/dev/null
}

run_with_stale_env() {
  local workdir="$1"
  shift
  (
    cd "$workdir"
    env \
      SPINE_TARGET_REPO="$STALE_REPO" \
      SPINE_ROOT="$STALE_REPO" \
      SPINE_REPO="$STALE_REPO" \
      SPINE_CODE="$STALE_REPO" \
      "$@"
  )
}

echo "self-governance target resolution tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT
STALE_REPO="$TMPDIR_BASE/stale-root"
OUTSIDE_REPO="$TMPDIR_BASE/outside"
make_stub_repo "$STALE_REPO"
make_stub_repo "$OUTSIDE_REPO"

set +e
projection_out="$(run_with_stale_env "$ROOT" python3 "$PROJECTION" --check 2>&1)"
projection_rc=$?
set -e
if [[ "$projection_rc" -eq 0 ]]; then
  pass "projection build uses current checkout over stale inherited env"
else
  fail "projection build uses current checkout over stale inherited env"
  echo "$projection_out" >&2
fi
assert_contains "$projection_out" "PASS" "projection build direct invocation reports pass"

set +e
status_out="$(run_with_stale_env "$ROOT" python3 "$STATUS" --brief 2>&1)"
status_rc=$?
set -e
if [[ "$status_rc" -eq 0 ]]; then
  pass "status uses current checkout over stale inherited env"
else
  fail "status uses current checkout over stale inherited env"
  echo "$status_out" >&2
fi
assert_contains "$status_out" "issues=0" "status direct invocation reports zero blocking issues"

set +e
telemetry_out="$(run_with_stale_env "$ROOT" python3 "$TELEMETRY" --brief 2>&1)"
telemetry_rc=$?
set -e
if [[ "$telemetry_rc" -eq 0 ]]; then
  pass "usage telemetry uses current checkout over stale inherited env"
else
  fail "usage telemetry uses current checkout over stale inherited env"
  echo "$telemetry_out" >&2
fi
assert_contains "$telemetry_out" "status=ok" "usage telemetry direct invocation reports ok"

set +e
gate_out="$(run_with_stale_env "$ROOT" bash "$GATE" 2>&1)"
gate_rc=$?
set -e
if [[ "$gate_rc" -eq 0 ]]; then
  pass "D415 uses current checkout over stale inherited env"
else
  fail "D415 uses current checkout over stale inherited env"
  echo "$gate_out" >&2
fi

set +e
override_projection_out="$(
  cd "$OUTSIDE_REPO"
  env SPINE_TARGET_REPO="$STALE_REPO" SPINE_ROOT="$STALE_REPO" SPINE_REPO="$STALE_REPO" SPINE_CODE="$STALE_REPO" \
    python3 "$PROJECTION" --root "$ROOT" --check 2>&1
)"
override_projection_rc=$?
set -e
if [[ "$override_projection_rc" -eq 0 ]]; then
  pass "projection build explicit --root override works"
else
  fail "projection build explicit --root override works"
  echo "$override_projection_out" >&2
fi

set +e
override_status_out="$(
  cd "$OUTSIDE_REPO"
  env SPINE_TARGET_REPO="$STALE_REPO" SPINE_ROOT="$STALE_REPO" SPINE_REPO="$STALE_REPO" SPINE_CODE="$STALE_REPO" \
    python3 "$STATUS" --root "$ROOT" --brief 2>&1
)"
override_status_rc=$?
set -e
if [[ "$override_status_rc" -eq 0 ]]; then
  pass "status explicit --root override works"
else
  fail "status explicit --root override works"
  echo "$override_status_out" >&2
fi

set +e
override_telemetry_out="$(
  cd "$OUTSIDE_REPO"
  env SPINE_TARGET_REPO="$STALE_REPO" SPINE_ROOT="$STALE_REPO" SPINE_REPO="$STALE_REPO" SPINE_CODE="$STALE_REPO" \
    python3 "$TELEMETRY" --root "$ROOT" --brief 2>&1
)"
override_telemetry_rc=$?
set -e
if [[ "$override_telemetry_rc" -eq 0 ]]; then
  pass "usage telemetry explicit --root override works"
else
  fail "usage telemetry explicit --root override works"
  echo "$override_telemetry_out" >&2
fi

set +e
override_gate_out="$(
  cd "$OUTSIDE_REPO"
  env SPINE_TARGET_REPO="$STALE_REPO" SPINE_ROOT="$STALE_REPO" SPINE_REPO="$STALE_REPO" SPINE_CODE="$STALE_REPO" \
    bash "$GATE" --root "$ROOT" 2>&1
)"
override_gate_rc=$?
set -e
if [[ "$override_gate_rc" -eq 0 ]]; then
  pass "D415 explicit --root override works"
else
  fail "D415 explicit --root override works"
  echo "$override_gate_out" >&2
fi

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
