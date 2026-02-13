#!/usr/bin/env bash
# Tests for D85: gate registry parity lock (semantic hardening)
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d85-gate-registry-parity-lock.sh"
REAL_REGISTRY="$SP/ops/bindings/gate.registry.yaml"
REAL_DRIFT="$SP/surfaces/verify/drift-gate.sh"

PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

# Helper: create minimal mock SPINE_ROOT for isolated tests
setup_mock() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/ops/bindings" "$tmp/surfaces/verify"
  cp "$REAL_REGISTRY" "$tmp/ops/bindings/gate.registry.yaml"
  cp "$REAL_DRIFT" "$tmp/surfaces/verify/drift-gate.sh"
  # Copy all gate scripts referenced by registry (non-inline, non-retired)
  while IFS=$'\t' read -r script is_inline is_retired; do
    [[ "$is_inline" == "true" || "$is_retired" == "true" ]] && continue
    [[ -z "$script" || "$script" == "null" ]] && continue
    local dir
    dir="$(dirname "$tmp/$script")"
    mkdir -p "$dir"
    cp "$SP/$script" "$tmp/$script" 2>/dev/null || true
  done < <(yq -r '.gates[] | [.check_script // "null", .inline // "false", .retired // "false"] | @tsv' "$REAL_REGISTRY")
  echo "$tmp"
}

cleanup_mock() {
  [[ -n "${1:-}" && -d "$1" ]] && rm -rf "$1" || true
}

# ── Test 1: Live pass ──
echo "--- Test 1: live state PASS ---"
if bash "$GATE" >/dev/null 2>&1; then
  pass "D85 passes on current repo state"
else
  fail "D85 should pass on current repo state"
fi

# ── Test 2: Active count mismatch fails ──
echo "--- Test 2: active count mismatch ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
yq -i '.gate_count.active = 99' "$MOCK/ops/bindings/gate.registry.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D85 correctly detects active count mismatch (rc=$rc)"
else
  fail "D85 should fail for active count mismatch (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

# ── Test 3: Retired count mismatch fails ──
echo "--- Test 3: retired count mismatch ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
yq -i '.gate_count.retired = 99' "$MOCK/ops/bindings/gate.registry.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D85 correctly detects retired count mismatch (rc=$rc)"
else
  fail "D85 should fail for retired count mismatch (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

# ── Test 4: Missing TRIAGE header on gate script fails ──
echo "--- Test 4: missing TRIAGE header ---"
MOCK="$(setup_mock)"
trap 'cleanup_mock "$MOCK"' EXIT
# Create a gate script without TRIAGE header
mkdir -p "$MOCK/surfaces/verify"
cat > "$MOCK/surfaces/verify/d99-test-no-triage.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
echo "D99 PASS: test gate"
SCRIPT
chmod +x "$MOCK/surfaces/verify/d99-test-no-triage.sh"
# Add it to registry as non-inline, non-retired
yq -i '.gates += [{"id": "D99", "name": "test-no-triage", "category": "process-hygiene", "description": "Test gate without triage header", "severity": "low", "check_script": "surfaces/verify/d99-test-no-triage.sh"}]' "$MOCK/ops/bindings/gate.registry.yaml"
# Also add D99 to drift-gate.sh (echo line so extraction finds it)
echo 'echo -n "D99 "' >> "$MOCK/surfaces/verify/drift-gate.sh"
# Update total count to match
new_total=$(yq -r '.gates | length' "$MOCK/ops/bindings/gate.registry.yaml")
yq -i ".gate_count.total = $new_total" "$MOCK/ops/bindings/gate.registry.yaml"
yq -i ".gate_count.active = $((new_total - 1))" "$MOCK/ops/bindings/gate.registry.yaml"
output=$(SPINE_ROOT="$MOCK" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D85 correctly detects missing TRIAGE header (rc=$rc)"
else
  fail "D85 should fail for missing TRIAGE header (rc=$rc, output: $output)"
fi
cleanup_mock "$MOCK"

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
