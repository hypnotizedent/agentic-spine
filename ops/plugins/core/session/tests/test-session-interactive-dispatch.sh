#!/usr/bin/env bash
set -euo pipefail

# Test: Interactive dispatch + complete (operator relay admitted path)
# Verifies the full interactive dispatch lifecycle:
#   dispatch → attach → work → complete → receipt linkage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
DISPATCH_BIN="$ROOT/ops/plugins/core/session/bin/session-interactive-dispatch"
COMPLETE_BIN="$ROOT/ops/plugins/core/session/bin/session-interactive-complete"
PASS=0
FAIL=0
TOTAL=0

source "$ROOT/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label (expected='$expected' actual='$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$haystack" | grep -qF "$needle"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label (output does not contain '$needle')"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local label="$1" path="$2"
  TOTAL=$((TOTAL + 1))
  if [[ -f "$path" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label (file not found: $path)"
    FAIL=$((FAIL + 1))
  fi
}

# ── Test: Dispatch scripts exist and are executable ──
TOTAL=$((TOTAL + 1))
if [[ -x "$DISPATCH_BIN" && -x "$COMPLETE_BIN" ]]; then
  echo "PASS: dispatch and complete scripts are executable"
  PASS=$((PASS + 1))
else
  echo "FAIL: scripts missing or not executable"
  FAIL=$((FAIL + 1))
fi

# ── Test: Create interactive dispatch ──
DISPATCH_OUTPUT=$("$DISPATCH_BIN" \
  --summary "Test dispatch for regression coverage" \
  --loop LOOP-TEST-INTERACTIVE \
  --role worker \
  --safety mutating \
  --domain core \
  --first-command "verify.fast -- --brief" \
  --target execution 2>&1)

assert_contains "dispatch output has INTERACTIVE DISPATCH CREATED" "$DISPATCH_OUTPUT" "INTERACTIVE DISPATCH CREATED"
assert_contains "dispatch output has OPERATOR CARRY" "$DISPATCH_OUTPUT" "OPERATOR CARRY"
assert_contains "dispatch output has session.v3.attach" "$DISPATCH_OUTPUT" "session.v3.attach"
assert_contains "dispatch output has first command" "$DISPATCH_OUTPUT" "verify.fast"
assert_contains "dispatch output has interactive.complete" "$DISPATCH_OUTPUT" "session.interactive.complete"

# ── Extract envelope ID from output ──
ENVELOPE_ID=$(echo "$DISPATCH_OUTPUT" | grep "^Envelope:" | awk '{print $2}')
DISPATCH_FILE=$(echo "$DISPATCH_OUTPUT" | grep "^Dispatch:" | awk '{print $2}')

TOTAL=$((TOTAL + 1))
if [[ "$ENVELOPE_ID" == ENV-* ]]; then
  echo "PASS: envelope ID starts with ENV-"
  PASS=$((PASS + 1))
else
  echo "FAIL: envelope ID format (got '$ENVELOPE_ID')"
  FAIL=$((FAIL + 1))
fi

assert_file_exists "dispatch file created" "$DISPATCH_FILE"

# ── Test: Dispatch file has correct structure ──
if command -v yq >/dev/null 2>&1 && [[ -f "$DISPATCH_FILE" ]]; then
  assert_eq "dispatch kind" "interactive_dispatch" "$(yq e -r '.kind' "$DISPATCH_FILE")"
  assert_eq "dispatch transport_mode" "operator_relay" "$(yq e -r '.transport_mode' "$DISPATCH_FILE")"
  assert_eq "dispatch sender_node" "control" "$(yq e -r '.sender_node' "$DISPATCH_FILE")"
  assert_eq "dispatch target_node" "execution" "$(yq e -r '.target_node' "$DISPATCH_FILE")"
  assert_eq "dispatch envelope_id matches" "$ENVELOPE_ID" "$(yq e -r '.envelope_id' "$DISPATCH_FILE")"
  assert_eq "dispatch work_scope.safety_level" "mutating" "$(yq e -r '.work_scope.safety_level' "$DISPATCH_FILE")"
  assert_eq "dispatch work_scope.execution_mode" "code" "$(yq e -r '.work_scope.execution_mode' "$DISPATCH_FILE")"
  assert_eq "dispatch work_scope.loop_id" "LOOP-TEST-INTERACTIVE" "$(yq e -r '.work_scope.loop_id' "$DISPATCH_FILE")"
  assert_eq "dispatch target_terminal.role" "worker" "$(yq e -r '.target_terminal.role' "$DISPATCH_FILE")"
  assert_contains "dispatch attach_command has loop" "$(yq e -r '.target_terminal.attach_command' "$DISPATCH_FILE")" "LOOP-TEST-INTERACTIVE"
  assert_contains "dispatch attach_command has role" "$(yq e -r '.target_terminal.attach_command' "$DISPATCH_FILE")" "worker"
else
  echo "SKIP: dispatch file structure tests (yq not available)"
fi

# ── Test: JSON mode ──
JSON_OUTPUT=$("$DISPATCH_BIN" \
  --summary "JSON mode test" \
  --role researcher \
  --safety read-only \
  --json 2>&1)

TOTAL=$((TOTAL + 1))
if echo "$JSON_OUTPUT" | python3 -m json.tool >/dev/null 2>&1; then
  echo "PASS: JSON mode produces valid JSON"
  PASS=$((PASS + 1))
else
  echo "FAIL: JSON mode output is not valid JSON"
  FAIL=$((FAIL + 1))
fi

# ── Test: Complete an interactive dispatch ──
FAKE_RUN_KEY="CAP-20260405-000000__test.cap__Rtest123"
COMPLETE_OUTPUT=$("$COMPLETE_BIN" \
  --dispatch-id "$ENVELOPE_ID" \
  --run-key "$FAKE_RUN_KEY" 2>&1)

assert_contains "complete output has COMPLETED" "$COMPLETE_OUTPUT" "INTERACTIVE DISPATCH COMPLETED"
assert_contains "complete output has run key" "$COMPLETE_OUTPUT" "$FAKE_RUN_KEY"
assert_contains "complete output has operator_relay" "$COMPLETE_OUTPUT" "operator_relay"

# ── Test: Completion artifact exists and has correct format ──
COMP_FILE="$SPINE_STATE/dispatch/completion/${ENVELOPE_ID}.completion.json"
assert_file_exists "completion artifact created" "$COMP_FILE"

if [[ -f "$COMP_FILE" ]]; then
  COMP_ENVELOPE=$(python3 -c "import json; print(json.load(open('$COMP_FILE'))['envelope_id'])" 2>/dev/null || true)
  COMP_RUN_KEY=$(python3 -c "import json; print(json.load(open('$COMP_FILE'))['run_key'])" 2>/dev/null || true)
  COMP_TRANSPORT=$(python3 -c "import json; print(json.load(open('$COMP_FILE'))['transport_mode'])" 2>/dev/null || true)
  COMP_STATUS=$(python3 -c "import json; print(json.load(open('$COMP_FILE'))['completion_status'])" 2>/dev/null || true)

  assert_eq "completion envelope_id matches dispatch" "$ENVELOPE_ID" "$COMP_ENVELOPE"
  assert_eq "completion run_key matches" "$FAKE_RUN_KEY" "$COMP_RUN_KEY"
  assert_eq "completion transport_mode" "operator_relay" "$COMP_TRANSPORT"
  assert_eq "completion status" "complete" "$COMP_STATUS"
fi

# ── Test: Missing dispatch ID fails ──
TOTAL=$((TOTAL + 1))
if "$COMPLETE_BIN" --dispatch-id "ENV-NONEXISTENT-000" --run-key "CAP-test" 2>/dev/null; then
  echo "FAIL: complete should fail for nonexistent dispatch"
  FAIL=$((FAIL + 1))
else
  echo "PASS: complete fails for nonexistent dispatch"
  PASS=$((PASS + 1))
fi

# ── Test: Missing summary fails ──
TOTAL=$((TOTAL + 1))
if "$DISPATCH_BIN" --role worker 2>/dev/null; then
  echo "FAIL: dispatch should fail without --summary"
  FAIL=$((FAIL + 1))
else
  echo "PASS: dispatch fails without --summary"
  PASS=$((PASS + 1))
fi

# ── Cleanup test artifacts ──
rm -f "$DISPATCH_FILE" "$COMP_FILE"
# Also clean up the JSON test dispatch
JSON_ENVELOPE=$(echo "$JSON_OUTPUT" | python3 -c "import json,sys; print(json.load(sys.stdin)['envelope_id'])" 2>/dev/null || true)
[[ -n "$JSON_ENVELOPE" ]] && rm -f "$SPINE_STATE/dispatch/interactive/${JSON_ENVELOPE}.dispatch.yaml" 2>/dev/null || true

# ── Summary ──
echo ""
echo "════════════════════════════════════════"
echo "INTERACTIVE DISPATCH: $PASS/$TOTAL passed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILURES: $FAIL"
  exit 1
fi
echo "════════════════════════════════════════"
