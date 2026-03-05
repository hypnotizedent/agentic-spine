#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$ROOT/surfaces/verify/d377-mailroom-runtime-split-brain-lock.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

mkrepo() {
  local dir="$1"
  mkdir -p "$dir/ops/bindings" "$dir/mailroom/outbox/proposals" "$dir/mailroom/state/orchestration"
  cat > "$dir/ops/bindings/mailroom.runtime.contract.yaml" <<'YAML'
active: true
runtime_root: /tmp/runtime-mailroom
tracked_exceptions:
  - mailroom/outbox/.keep
  - mailroom/state/.keep
  - mailroom/state/loop-scopes/**
runtime_migration:
  items:
    - mailroom/outbox/proposals
    - mailroom/state/orchestration
    - mailroom/state/mailroom-bridge.token
YAML
}

run_gate_expect() {
  local dir="$1" expected_rc="$2"
  set +e
  SPINE_ROOT="$dir" bash "$GATE" >/tmp/d377-test.out 2>/tmp/d377-test.err
  rc=$?
  set -e
  if [[ "$rc" -ne "$expected_rc" ]]; then
    echo "--- stdout ---"; cat /tmp/d377-test.out || true
    echo "--- stderr ---"; cat /tmp/d377-test.err || true
    fail "expected rc=$expected_rc got rc=$rc"
  fi
}

echo "D377 Tests"

# Case 1: clean migrated trees (only .keep stubs) should pass.
case1="$TMP/case1"
mkrepo "$case1"
touch "$case1/mailroom/outbox/proposals/.keep"
touch "$case1/mailroom/state/orchestration/.keep"
run_gate_expect "$case1" 0
pass "clean runtime trees with stubs pass"

# Case 2: duplicate runtime artifact under migrated tree should fail.
case2="$TMP/case2"
mkrepo "$case2"
echo "x" > "$case2/mailroom/outbox/proposals/manifest.yaml"
run_gate_expect "$case2" 1
pass "duplicate runtime artifact fails"

# Case 3: explicit tracked exception inside migrated tree should pass.
case3="$TMP/case3"
mkrepo "$case3"
cat >> "$case3/ops/bindings/mailroom.runtime.contract.yaml" <<'YAML'
tracked_exceptions:
  - mailroom/outbox/proposals/allowlisted.yaml
YAML
echo "x" > "$case3/mailroom/outbox/proposals/allowlisted.yaml"
run_gate_expect "$case3" 0
pass "explicit tracked exception is honored"

echo "D377 tests PASS"
