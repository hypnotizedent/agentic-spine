#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/program.closeout.contract.yaml"
ARTIFACT="$ROOT/ops/bindings/program.closeout.march25-post-v3.yaml"
VALIDATOR="$ROOT/ops/plugins/core/lifecycle/bin/program-closeout-validate"
SPINE_DOC="$ROOT/docs/governance/SPINE.md"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if printf '%s\n' "$haystack" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "program closeout framework tests"
echo "════════════════════════════════════════"

command -v yq >/dev/null 2>&1 || {
  echo "FAIL: missing dependency yq" >&2
  exit 1
}

if [[ -f "$CONTRACT" ]]; then
  pass "program closeout contract exists"
else
  fail "program closeout contract exists"
fi

if [[ -f "$ARTIFACT" ]]; then
  pass "March 25 machine closeout artifact exists"
else
  fail "March 25 machine closeout artifact exists"
fi

if [[ -x "$VALIDATOR" ]]; then
  pass "program closeout validator is executable"
else
  fail "program closeout validator is executable"
fi

allowed_states="$(yq e -r '.terminal_states.allowed[]' "$CONTRACT" | tr '\n' ' ')"
for state in fixed retired explicit_hold reclassified; do
  if echo "$allowed_states" | grep -Eq "(^| )${state}( |$)"; then
    pass "contract allows ${state}"
  else
    fail "contract allows ${state}"
  fi
done

artifact_states="$(yq e -r '.findings[].terminal_state' "$ARTIFACT" | tr '\n' ' ')"
for state in fixed retired explicit_hold reclassified; do
  if echo "$artifact_states" | grep -Eq "(^| )${state}( |$)"; then
    pass "March 25 artifact exercises ${state}"
  else
    fail "March 25 artifact exercises ${state}"
  fi
done

if validate_out="$(python3 "$VALIDATOR" --root "$ROOT" --artifact "$ARTIFACT" --brief 2>&1)"; then
  pass "validator accepts March 25 artifact"
else
  fail "validator accepts March 25 artifact"
  echo "$validate_out" >&2
fi
assert_contains "$validate_out" "issues=0" "validator reports zero issues for March 25 artifact"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
INVALID="$TMPDIR/invalid-program-closeout.yaml"
cat > "$INVALID" <<'EOF'
status: authoritative
owner: "@ronny"
scope: invalid-program-closeout
program:
  id: invalid
  title: Invalid Closeout
  as_of: 2026-04-05
  closure_status: closed
  scope_statement: invalid fixture
  companion_narrative: docs/governance/SPINE_MARCH25_CLOSURE_20260405.md
  in_scope_gate_ids:
    - D225
  no_silent_warn_only_residue: true
findings:
  - gate_id: D225
    terminal_state: explicit_hold
    as_of: 2026-04-05
    summary: invalid hold fixture
    rationale: missing blocker on purpose
    owner: "@ronny"
    follow_up_truth: ops/bindings/gate.registry.yaml
EOF

set +e
invalid_out="$(python3 "$VALIDATOR" --root "$ROOT" --artifact "$INVALID" --brief 2>&1)"
invalid_rc=$?
set -e
if [[ "$invalid_rc" -ne 0 ]]; then
  pass "validator rejects malformed explicit_hold"
else
  fail "validator rejects malformed explicit_hold"
fi
assert_contains "$invalid_out" "FAIL" "invalid fixture reports FAIL"

spine_text="$(sed -n '1,220p' "$SPINE_DOC")"
assert_contains "$spine_text" "Program Closeout" "SPINE.md documents program closeout workflow"
assert_contains "$spine_text" "program-closeout-validate" "SPINE.md references validator"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
