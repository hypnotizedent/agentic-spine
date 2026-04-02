#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
PROFILE_VALIDATE="$ROOT/ops/plugins/core/authority/bin/tenant-profile-validate"
STORAGE_AUDIT="$ROOT/ops/plugins/core/authority/bin/tenant-storage-audit"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

make_stub_repo() {
  local dir="$1"
  git init "$dir" >/dev/null
  git -C "$dir" config user.name "Test User"
  git -C "$dir" config user.email "test@example.com"
  printf 'stub\n' > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -m "stub" >/dev/null
}

echo "tenant portability baseline tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
stale_repo="$tmpdir/stale-root"
make_stub_repo "$stale_repo"

set +e
profile_out="$(
  cd "$ROOT"
  env SPINE_TARGET_REPO="$stale_repo" SPINE_ROOT="$stale_repo" SPINE_REPO="$stale_repo" SPINE_CODE="$stale_repo" \
    bash "$PROFILE_VALIDATE" --profile ops/bindings/tenant.profile.yaml 2>&1
)"
profile_rc=$?
set -e
if [[ "$profile_rc" -eq 0 ]]; then
  pass "tenant profile validate ignores stale inherited env"
else
  fail "tenant profile validate ignores stale inherited env"
  echo "$profile_out" >&2
fi

set +e
storage_out="$(
  cd "$ROOT"
  env SPINE_TARGET_REPO="$stale_repo" SPINE_ROOT="$stale_repo" SPINE_REPO="$stale_repo" SPINE_CODE="$stale_repo" \
    bash "$STORAGE_AUDIT" 2>&1
)"
storage_rc=$?
set -e
if [[ "$storage_rc" -eq 0 ]]; then
  pass "tenant storage audit ignores stale inherited env"
else
  fail "tenant storage audit ignores stale inherited env"
  echo "$storage_out" >&2
fi

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
