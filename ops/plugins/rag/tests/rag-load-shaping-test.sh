#!/usr/bin/env bash
# Tests for RAG load-shaping knob resolution and enforcement.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
BINDING="$SP/ops/bindings/rag.workspace.contract.yaml"
RAG_CLI="$SP/ops/plugins/rag/bin/rag"

pass=0
fail_count=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    pass=$((pass + 1))
  else
    echo "  FAIL: $label (expected='$expected', got='$actual')"
    fail_count=$((fail_count + 1))
  fi
}

assert_contains() {
  local label="$1" pattern="$2" text="$3"
  if echo "$text" | grep -q "$pattern"; then
    echo "  PASS: $label"
    pass=$((pass + 1))
  else
    echo "  FAIL: $label (pattern='$pattern' not found)"
    fail_count=$((fail_count + 1))
  fi
}

echo "=== RAG Load-Shaping Knob Tests ==="

# Test 1: Binding has load_shaping section
echo "Test 1: load_shaping section exists in binding"
val="$(yq -r '.sync_policy.load_shaping' "$BINDING")"
if [[ "$val" != "null" && -n "$val" ]]; then
  echo "  PASS: load_shaping section present"
  pass=$((pass + 1))
else
  echo "  FAIL: load_shaping section missing"
  fail_count=$((fail_count + 1))
fi

# Test 2: inter_doc_pace_sec has valid default
echo "Test 2: inter_doc_pace_sec default"
val="$(yq -r '.sync_policy.load_shaping.inter_doc_pace_sec // ""' "$BINDING")"
assert_eq "inter_doc_pace_sec" "1" "$val"

# Test 3: per_request_timeout_sec
echo "Test 3: per_request_timeout_sec default"
val="$(yq -r '.sync_policy.load_shaping.per_request_timeout_sec // ""' "$BINDING")"
assert_eq "per_request_timeout_sec" "180" "$val"

# Test 4: max_retries
echo "Test 4: max_retries default"
val="$(yq -r '.sync_policy.load_shaping.max_retries // ""' "$BINDING")"
assert_eq "max_retries" "2" "$val"

# Test 5: backoff_strategy
echo "Test 5: backoff_strategy default"
val="$(yq -r '.sync_policy.load_shaping.backoff_strategy // ""' "$BINDING")"
assert_eq "backoff_strategy" "exponential" "$val"

# Test 6: retry_base_delay_sec
echo "Test 6: retry_base_delay_sec default"
val="$(yq -r '.sync_policy.load_shaping.retry_base_delay_sec // ""' "$BINDING")"
assert_eq "retry_base_delay_sec" "5" "$val"

# Test 7: retry_max_delay_sec
echo "Test 7: retry_max_delay_sec default"
val="$(yq -r '.sync_policy.load_shaping.retry_max_delay_sec // ""' "$BINDING")"
assert_eq "retry_max_delay_sec" "60" "$val"

# Test 8: resolve_load_shaping function exists in rag CLI
echo "Test 8: resolve_load_shaping function wired in rag CLI"
if grep -q "resolve_load_shaping" "$RAG_CLI"; then
  echo "  PASS: resolve_load_shaping found in rag CLI"
  pass=$((pass + 1))
else
  echo "  FAIL: resolve_load_shaping not found in rag CLI"
  fail_count=$((fail_count + 1))
fi

# Test 9: compute_retry_delay function exists
echo "Test 9: compute_retry_delay function wired in rag CLI"
if grep -q "compute_retry_delay" "$RAG_CLI"; then
  echo "  PASS: compute_retry_delay found in rag CLI"
  pass=$((pass + 1))
else
  echo "  FAIL: compute_retry_delay not found in rag CLI"
  fail_count=$((fail_count + 1))
fi

# Test 10: Sync dry-run shows load_shaping line
echo "Test 10: sync dry-run prints load_shaping knobs"
# We can't run actual sync but can check the sync section references load_shaping
if grep -q "load_shaping:" "$RAG_CLI"; then
  echo "  PASS: load_shaping output wired in sync"
  pass=$((pass + 1))
else
  echo "  FAIL: load_shaping output not found in sync section"
  fail_count=$((fail_count + 1))
fi

# Test 11: Inter-doc pacing wired in sync loop
echo "Test 11: inter-doc pacing wired in sync loop"
if grep -q "LS_INTER_DOC_PACE" "$RAG_CLI"; then
  echo "  PASS: LS_INTER_DOC_PACE referenced in sync loop"
  pass=$((pass + 1))
else
  echo "  FAIL: LS_INTER_DOC_PACE not found"
  fail_count=$((fail_count + 1))
fi

echo
echo "=== Results: $pass passed, $fail_count failed ==="
if [[ "$fail_count" -gt 0 ]]; then
  exit 1
fi
