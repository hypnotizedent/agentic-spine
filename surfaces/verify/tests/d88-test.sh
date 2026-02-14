#!/usr/bin/env bash
# Tests for D88: RAG remote reindex governance lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d88-rag-remote-reindex-governance-lock.sh"

PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

setup_mock() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p \
    "$tmp/ops/bindings" \
    "$tmp/ops/plugins/rag/bin" \
    "$tmp/ops/plugins" \
    "$tmp/surfaces/verify"
  cp "$SP/ops/bindings/rag.remote.runner.yaml" "$tmp/ops/bindings/rag.remote.runner.yaml"
  cp "$SP/ops/bindings/ssh.targets.yaml" "$tmp/ops/bindings/ssh.targets.yaml"
  cp "$SP/ops/capabilities.yaml" "$tmp/ops/capabilities.yaml"
  cp "$SP/ops/bindings/capability_map.yaml" "$tmp/ops/bindings/capability_map.yaml"
  cp "$SP/ops/plugins/MANIFEST.yaml" "$tmp/ops/plugins/MANIFEST.yaml"
  cp "$SP/ops/plugins/rag/bin/rag" "$tmp/ops/plugins/rag/bin/rag"
  cp "$SP/ops/plugins/rag/bin/rag-reindex-remote-start" "$tmp/ops/plugins/rag/bin/rag-reindex-remote-start"
  cp "$SP/ops/plugins/rag/bin/rag-reindex-remote-status" "$tmp/ops/plugins/rag/bin/rag-reindex-remote-status"
  cp "$SP/ops/plugins/rag/bin/rag-reindex-remote-stop" "$tmp/ops/plugins/rag/bin/rag-reindex-remote-stop"
  chmod +x "$tmp/ops/plugins/rag/bin/"*
  echo "$tmp"
}

cleanup_mock() {
  [[ -n "${1:-}" && -d "$1" ]] && rm -rf "$1" || true
}

# ── Test 1: live pass ──
echo "--- Test 1: live state PASS ---"
if bash "$GATE" >/dev/null 2>&1; then
  pass "D88 passes on current repo state"
else
  fail "D88 should pass on current repo state"
fi

# ── Test 2: missing binding fails ──
echo "--- Test 2: missing binding ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
rm -f "$MOCK/ops/bindings/rag.remote.runner.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D88 correctly detects missing binding (rc=$rc)"
else
  fail "D88 should fail for missing binding (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

# ── Test 3: capability command mismatch fails ──
echo "--- Test 3: capability command mismatch ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
yq -i '.capabilities."rag.reindex.remote.status".command = "./ops/plugins/rag/bin/wrong-script"' "$MOCK/ops/capabilities.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D88 correctly detects capability command mismatch (rc=$rc)"
else
  fail "D88 should fail for capability command mismatch (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

# ── Test 4: raw bearer token in curl args fails ──
echo "--- Test 4: raw bearer header pattern ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
printf '\n# test mutation\ncurl -H "Authorization: Bearer ${ANYTHINGLLM_API_KEY}" https://example.invalid\n' >> "$MOCK/ops/plugins/rag/bin/rag"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D88 correctly detects raw bearer header pattern (rc=$rc)"
else
  fail "D88 should fail for raw bearer header pattern (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"

