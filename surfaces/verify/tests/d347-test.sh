#!/usr/bin/env bash
# Tests for D347: bootstrap hardcoded-path admission lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d347-bootstrap-hardcoded-path-admission-lock.sh"

PASS=0
FAIL_COUNT=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1" >&2; }

setup_mock() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p \
    "$tmp/surfaces/verify" \
    "$tmp/ops/bindings" \
    "$tmp/ops/plugins/session/bin"
  cp "$GATE" "$tmp/surfaces/verify/d347-bootstrap-hardcoded-path-admission-lock.sh"
  cp "$SP/ops/bindings/runtime.bootstrap.contract.yaml" "$tmp/ops/bindings/runtime.bootstrap.contract.yaml"
  cp "$SP/ops/plugins/session/bin/spine-init" "$tmp/ops/plugins/session/bin/spine-init"
  cp "$SP/ops/plugins/session/bin/spine-doctor" "$tmp/ops/plugins/session/bin/spine-doctor"
  chmod +x \
    "$tmp/surfaces/verify/d347-bootstrap-hardcoded-path-admission-lock.sh" \
    "$tmp/ops/plugins/session/bin/spine-init" \
    "$tmp/ops/plugins/session/bin/spine-doctor"
  echo "$tmp"
}

cleanup_mock() {
  [[ -n "${1:-}" && -d "$1" ]] && rm -rf "$1" || true
}

echo "--- Test 1: live state PASS ---"
if bash "$GATE" >/dev/null 2>&1; then
  pass "D347 passes on current repo state"
else
  fail "D347 should pass on current repo state"
fi

echo "--- Test 2: injected absolute path FAIL ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
echo '# injected violation /Users/ronnyworks/code/agentic-spine' >> "$MOCK/ops/plugins/session/bin/spine-init"
output=$(bash "$MOCK/surfaces/verify/d347-bootstrap-hardcoded-path-admission-lock.sh" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D347 correctly fails on prohibited literal (rc=$rc)"
else
  fail "D347 should fail for prohibited literal (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

echo "--- Test 3: missing contract FAIL ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
rm -f "$MOCK/ops/bindings/runtime.bootstrap.contract.yaml"
output=$(bash "$MOCK/surfaces/verify/d347-bootstrap-hardcoded-path-admission-lock.sh" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D347 correctly fails when contract is missing (rc=$rc)"
else
  fail "D347 should fail when contract is missing (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
