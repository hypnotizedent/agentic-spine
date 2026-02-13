#!/usr/bin/env bash
set -euo pipefail

# d75-test.sh — Unit tests for D75 gap registry mutation lock
#
# Tests:
#   1. PASS: commit with valid trailers
#   2. FAIL: commit without trailers (manual edit)
#   3. FAIL: dirty registry file (unstaged)
#
# Uses a temporary git repo to avoid mutating real state.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$ROOT/surfaces/verify/d75-gap-registry-mutation-lock.sh"
POLICY_SRC="$ROOT/ops/bindings/d75-gap-mutation-policy.yaml"

PASS=0
FAIL_COUNT=0
TMPDIR=""

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }

setup_temp_repo() {
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "test"

  # Mirror expected directory structure
  mkdir -p ops/bindings surfaces/verify

  # Create a minimal gaps file
  cat > ops/bindings/operational.gaps.yaml <<'YAML'
gaps:
  - id: GAP-OP-001
    status: open
YAML

  # Create a policy file pointing to the gaps file
  # The enforcement_after_sha will be set to the initial commit
  git add .
  git commit -q -m "initial commit"

  BASELINE_SHA="$(git rev-parse HEAD)"

  cat > ops/bindings/d75-gap-mutation-policy.yaml <<YAML
version: 1
gate_id: D75
file: ops/bindings/operational.gaps.yaml
window: 50
enforcement_after_sha: "$BASELINE_SHA"
required_trailers:
  - Gap-Mutation
  - Gap-Capability
  - Gap-Run-Key
strict: true
YAML

  # Copy the gate script
  cp "$GATE" surfaces/verify/d75-gap-registry-mutation-lock.sh
  chmod +x surfaces/verify/d75-gap-registry-mutation-lock.sh

  git add .
  git commit -q -m "add gate and policy"
}

teardown() {
  cd /
  rm -rf "$TMPDIR" 2>/dev/null || true
}

trap teardown EXIT INT TERM

# ─────────────────────────────────────────────────────────────────────────
# Test 1: PASS — commit with valid trailers
# ─────────────────────────────────────────────────────────────────────────
test_valid_trailers() {
  echo "Test 1: Commit with valid trailers"
  setup_temp_repo

  # Add a commit to the gaps file WITH proper trailers
  cat >> ops/bindings/operational.gaps.yaml <<'YAML'
  - id: GAP-OP-002
    status: open
YAML
  git add ops/bindings/operational.gaps.yaml
  git commit -q -m "$(cat <<'EOF'
gov(GAP-OP-002): register gap via gaps.file

Gap-Mutation: capability
Gap-Capability: gaps.file
Gap-Run-Key: CAP-20260213-000000__gaps.file__Rtest1
EOF
)"

  if bash surfaces/verify/d75-gap-registry-mutation-lock.sh 2>/dev/null; then
    pass "valid trailers accepted"
  else
    fail "valid trailers should pass"
  fi

  teardown
}

# ─────────────────────────────────────────────────────────────────────────
# Test 2: FAIL — commit without trailers (manual edit)
# ─────────────────────────────────────────────────────────────────────────
test_missing_trailers() {
  echo "Test 2: Commit without trailers (manual edit)"
  setup_temp_repo

  # Add a commit to the gaps file WITHOUT trailers
  cat >> ops/bindings/operational.gaps.yaml <<'YAML'
  - id: GAP-OP-003
    status: open
YAML
  git add ops/bindings/operational.gaps.yaml
  git commit -q -m "manual edit to gaps registry"

  if bash surfaces/verify/d75-gap-registry-mutation-lock.sh 2>/dev/null; then
    fail "missing trailers should fail"
  else
    pass "missing trailers correctly rejected"
  fi

  teardown
}

# ─────────────────────────────────────────────────────────────────────────
# Test 3: FAIL — dirty registry file (unstaged changes)
# ─────────────────────────────────────────────────────────────────────────
test_dirty_registry() {
  echo "Test 3: Dirty registry file (unstaged changes)"
  setup_temp_repo

  # Modify the file without committing
  echo "# dirty" >> ops/bindings/operational.gaps.yaml

  if bash surfaces/verify/d75-gap-registry-mutation-lock.sh 2>/dev/null; then
    fail "dirty registry should fail"
  else
    pass "dirty registry correctly rejected"
  fi

  teardown
}

# ─────────────────────────────────────────────────────────────────────────
# Run all tests
# ─────────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  D75 Gap Registry Mutation Lock Tests"
echo "═══════════════════════════════════════════════════════════════"
echo

test_valid_trailers
echo
test_missing_trailers
echo
test_dirty_registry

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL_COUNT failed"
echo "═══════════════════════════════════════════════════════════════"

[[ $FAIL_COUNT -gt 0 ]] && exit 1
exit 0
