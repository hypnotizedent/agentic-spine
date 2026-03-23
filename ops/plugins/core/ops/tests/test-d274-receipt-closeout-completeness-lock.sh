#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
SCRIPT="$ROOT/surfaces/verify/d274-receipt-closeout-completeness-lock.sh"

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

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

TEST_ROOT="$TMPDIR_BASE/repo"
mkdir -p "$TEST_ROOT/ops/bindings" "$TEST_ROOT/.evidence/spine/reports/verify"

cat > "$TEST_ROOT/ops/bindings/wave.closeout.contract.yaml" <<'EOF'
receipt_crumb_detection:
  block_untracked: true
  untracked_receipt_regex: "(^|/)\\.evidence/spine/reports/verify/W[^/]*RECEIPT[^/]*\\.md$"
EOF

git -C "$TMPDIR_BASE" init repo >/dev/null 2>&1
git -C "$TEST_ROOT" config user.name "Test User"
git -C "$TEST_ROOT" config user.email "test@example.com"
printf 'tracked\n' > "$TEST_ROOT/README.md"
git -C "$TEST_ROOT" add README.md ops/bindings/wave.closeout.contract.yaml
git -C "$TEST_ROOT" commit -m "base" >/dev/null 2>&1

set +e
clean_out="$(SPINE_ROOT="$TEST_ROOT" "$SCRIPT" --policy enforce 2>&1)"
clean_rc=$?
set -e
if [[ "$clean_rc" == "0" ]]; then
  pass "clean repo passes receipt crumb lock"
else
  fail "clean repo passes receipt crumb lock"
fi
assert_contains "$clean_out" "D274 PASS" "clean repo emits pass message"

printf 'crumb\n' > "$TEST_ROOT/.evidence/spine/reports/verify/W123_RECEIPT.md"
set +e
dirty_out="$(SPINE_ROOT="$TEST_ROOT" "$SCRIPT" --policy enforce 2>&1)"
dirty_rc=$?
set -e
if [[ "$dirty_rc" == "1" ]]; then
  pass "untracked receipt crumb blocks enforce policy"
else
  fail "untracked receipt crumb blocks enforce policy"
fi
assert_contains "$dirty_out" "D274 ENFORCE" "enforce mode reports crumb failure"
assert_contains "$dirty_out" "W123_RECEIPT.md" "crumb path surfaced in failure output"

set +e
report_out="$(SPINE_ROOT="$TEST_ROOT" "$SCRIPT" --policy report 2>&1)"
report_rc=$?
set -e
if [[ "$report_rc" == "0" ]]; then
  pass "report mode does not fail on crumbs"
else
  fail "report mode does not fail on crumbs"
fi
assert_contains "$report_out" "D274 REPORT" "report mode reports crumb warning"

echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
