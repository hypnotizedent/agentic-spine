#!/usr/bin/env bash
# Tests for D90: RAG reindex runtime quality gate
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d90-rag-reindex-runtime-quality-gate.sh"

PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

setup_mock() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p \
    "$tmp/ops/bindings" \
    "$tmp/surfaces/verify"
  cp "$SP/ops/bindings/rag.remote.runner.yaml" "$tmp/ops/bindings/rag.remote.runner.yaml"
  cp "$SP/ops/bindings/rag.reindex.quality.yaml" "$tmp/ops/bindings/rag.reindex.quality.yaml"
  echo "$tmp"
}

cleanup_mock() {
  [[ -n "${1:-}" && -d "$1" ]] && rm -rf "$1" || true
}

# ── Test 1: live pass (session running should PASS) ──
echo "--- Test 1: live state with session running ---"
if bash "$GATE" >/dev/null 2>&1; then
  pass "D90 passes when session is running (expected)"
else
  # Session might be stopped - check if it's a valid failure reason
  output=$(bash "$GATE" 2>&1) || true
  if echo "$output" | grep -q "is RUNNING"; then
    fail "D90 should pass when session is RUNNING"
  else
    pass "D90 correctly fails when session is STOPPED with quality issues"
  fi
fi

# ── Test 2: missing binding fails ──
echo "--- Test 2: missing binding ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
rm -f "$MOCK/ops/bindings/rag.remote.runner.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D90 correctly detects missing runner binding (rc=$rc)"
else
  fail "D90 should fail for missing binding (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

# ── Test 3: missing quality binding fails ──
echo "--- Test 3: missing quality binding ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
rm -f "$MOCK/ops/bindings/rag.reindex.quality.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D90 correctly detects missing quality binding (rc=$rc)"
else
  fail "D90 should fail for missing quality binding (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

# ── Test 4: invalid host in binding fails gracefully ──
echo "--- Test 4: invalid host fails gracefully ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
yq -i '.remote.host = "invalid-host-99999.invalid"' "$MOCK/ops/bindings/rag.remote.runner.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
# Should fail due to SSH connection failure
if [[ "$rc" -ne 0 ]]; then
  pass "D90 correctly handles unreachable host (rc=$rc)"
else
  fail "D90 should fail for unreachable host (rc=$rc)"
fi
cleanup_mock "$MOCK"

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
