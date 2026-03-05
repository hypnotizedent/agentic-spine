#!/usr/bin/env bash
# Tests for D87: RAG workspace contract lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d87-rag-workspace-contract-lock.sh"
REAL_CONTRACT="$SP/ops/bindings/rag.workspace.contract.yaml"
REAL_RAG="$SP/ops/plugins/rag/bin/rag"

PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

# Helper: create minimal mock SPINE_ROOT for isolated tests
setup_mock() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/ops/bindings" "$tmp/ops/plugins/rag/bin"
  cp "$REAL_CONTRACT" "$tmp/ops/bindings/rag.workspace.contract.yaml"
  cp "$REAL_RAG" "$tmp/ops/plugins/rag/bin/rag"
  echo "$tmp"
}

cleanup_mock() {
  [[ -n "${1:-}" && -d "$1" ]] && rm -rf "$1" || true
}

# ── Test 1: Live pass ──
echo "--- Test 1: live state PASS ---"
if bash "$GATE" >/dev/null 2>&1; then
  pass "D87 passes on current repo state"
else
  fail "D87 should pass on current repo state"
fi

# ── Test 2: Missing contract file fails ──
echo "--- Test 2: missing contract file ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
rm -f "$MOCK/ops/bindings/rag.workspace.contract.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D87 correctly detects missing contract file (rc=$rc)"
else
  fail "D87 should fail for missing contract file (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

# ── Test 3: Workspace slug mismatch fails ──
echo "--- Test 3: workspace slug mismatch ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
yq -i '.workspace.slug = "wrong-slug"' "$MOCK/ops/bindings/rag.workspace.contract.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D87 correctly detects workspace slug mismatch (rc=$rc)"
else
  fail "D87 should fail for workspace slug mismatch (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

# ── Test 4: Sync timeout mismatch fails ──
echo "--- Test 4: sync timeout mismatch ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
yq -i '.sync_policy.upload_timeout_sec = 999' "$MOCK/ops/bindings/rag.workspace.contract.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D87 correctly detects sync timeout mismatch (rc=$rc)"
else
  fail "D87 should fail for sync timeout mismatch (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
