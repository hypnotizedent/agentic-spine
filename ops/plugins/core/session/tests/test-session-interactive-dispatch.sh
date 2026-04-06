#!/usr/bin/env bash
set -euo pipefail

# Test: Interactive dispatch adoption for governed repo mutations
# Verifies the adopted workflow for controller-issued secondary-terminal
# mutations to governed spine repo paths:
#   dispatch -> pending visibility -> target completion -> linked receipt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
DISPATCH_BIN="$ROOT/ops/plugins/core/session/bin/session-interactive-dispatch"
STATUS_BIN="$ROOT/ops/plugins/core/session/bin/session-interactive-status"
COMPLETE_BIN="$ROOT/ops/plugins/core/session/bin/session-interactive-complete"
PASS=0
FAIL=0
TOTAL=0

TEST_STATE="$(mktemp -d)"
TEST_EVIDENCE="$(mktemp -d)"
export SPINE_STATE="$TEST_STATE"
export SPINE_EVIDENCE="$TEST_EVIDENCE"

cleanup() {
  rm -rf "$TEST_STATE" "$TEST_EVIDENCE" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$SPINE_STATE/dispatch/interactive" "$SPINE_STATE/dispatch/completion"

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

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$haystack" | grep -qF "$needle"; then
    echo "FAIL: $label (output unexpectedly contains '$needle')"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $label"
    PASS=$((PASS + 1))
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

# ── Test: Scripts exist and are executable ──
TOTAL=$((TOTAL + 1))
if [[ -x "$DISPATCH_BIN" && -x "$STATUS_BIN" && -x "$COMPLETE_BIN" ]]; then
  echo "PASS: dispatch/status/complete scripts are executable"
  PASS=$((PASS + 1))
else
  echo "FAIL: interactive path scripts missing or not executable"
  FAIL=$((FAIL + 1))
fi

# ── Test: Adopted governed repo mutation dispatch ──
ADOPTED_OUTPUT=$("$DISPATCH_BIN" \
  --summary "Adopt governed repo mutation path for session workflow" \
  --loop LOOP-TEST-INTERACTIVE \
  --governed-repo-mutation \
  --governed-path ops/bindings/session.admission.contract.yaml \
  --governed-path surfaces/verify/d75-gap-registry-mutation-lock.sh \
  --first-command "verify.fast -- --brief" 2>&1)

assert_contains "adopted dispatch output has INTERACTIVE DISPATCH CREATED" "$ADOPTED_OUTPUT" "INTERACTIVE DISPATCH CREATED"
assert_contains "adopted dispatch output shows adopted task class" "$ADOPTED_OUTPUT" "ADOPTED TASK CLASS"
assert_contains "adopted dispatch output exports dispatch id" "$ADOPTED_OUTPUT" "export SPINE_INTERACTIVE_DISPATCH_ID=ENV-"
assert_contains "adopted dispatch output shows target completion command" "$ADOPTED_OUTPUT" "session.interactive.complete -- --run-key <RUN_KEY>"
assert_contains "adopted dispatch output has governed path" "$ADOPTED_OUTPUT" "ops/bindings/session.admission.contract.yaml"

ENVELOPE_ID=$(echo "$ADOPTED_OUTPUT" | awk '/^Envelope:/ {print $2}')
DISPATCH_FILE=$(echo "$ADOPTED_OUTPUT" | awk '/^Dispatch:/ {print $2}')

TOTAL=$((TOTAL + 1))
if [[ "$ENVELOPE_ID" == ENV-* ]]; then
  echo "PASS: adopted envelope ID starts with ENV-"
  PASS=$((PASS + 1))
else
  echo "FAIL: adopted envelope ID format (got '$ENVELOPE_ID')"
  FAIL=$((FAIL + 1))
fi

assert_file_exists "adopted dispatch file created" "$DISPATCH_FILE"

if command -v yq >/dev/null 2>&1 && [[ -f "$DISPATCH_FILE" ]]; then
  assert_eq "adopted dispatch kind" "interactive_dispatch" "$(yq e -r '.kind' "$DISPATCH_FILE")"
  assert_eq "adopted dispatch target_node" "execution" "$(yq e -r '.target_node' "$DISPATCH_FILE")"
  assert_eq "adopted dispatch domain" "spine" "$(yq e -r '.work_scope.domain' "$DISPATCH_FILE")"
  assert_eq "adopted dispatch capability_id" "verify.fast" "$(yq e -r '.work_scope.capability_id' "$DISPATCH_FILE")"
  assert_eq "adopted dispatch workflow rule" "interactive_governed_repo_mutation_default" "$(yq e -r '.workflow_adoption.rule_id' "$DISPATCH_FILE")"
  assert_eq "adopted dispatch completion required" "true" "$(yq e -r '.workflow_adoption.completion_required' "$DISPATCH_FILE")"
  assert_contains "adopted dispatch stores governed paths" "$(yq e -r '.workflow_adoption.governed_repo_paths[]' "$DISPATCH_FILE")" "ops/bindings/session.admission.contract.yaml"
  assert_contains "adopted dispatch stores target export" "$(yq e -r '.delegation_context.target_terminal_exports[]' "$DISPATCH_FILE")" "SPINE_INTERACTIVE_DISPATCH_ID=${ENVELOPE_ID}"
else
  echo "SKIP: adopted dispatch structure tests (yq not available)"
fi

# ── Test: Missing completion is detectable ──
STATUS_PENDING=$("$STATUS_BIN" --dispatch-id "$ENVELOPE_ID" 2>&1)
assert_contains "status reports awaiting completion" "$STATUS_PENDING" "status: awaiting_completion"
assert_contains "status reports workflow rule" "$STATUS_PENDING" "workflow_rule_id: interactive_governed_repo_mutation_default"

FILTERED_PENDING=$("$STATUS_BIN" --list-pending --governed-repo-mutations-only 2>&1)
assert_contains "pending list includes adopted envelope" "$FILTERED_PENDING" "$ENVELOPE_ID"

# ── Test: Generic interactive dispatch stays out of adopted filter ──
GENERIC_OUTPUT=$("$DISPATCH_BIN" \
  --summary "Generic interactive dispatch outside adopted class" \
  --role researcher \
  --safety read-only \
  --domain core \
  --first-command "verify.fast -- --brief" \
  --target execution 2>&1)

GENERIC_ENVELOPE=$(echo "$GENERIC_OUTPUT" | awk '/^Envelope:/ {print $2}')
assert_not_contains "generic dispatch does not export adopted dispatch env" "$GENERIC_OUTPUT" "SPINE_INTERACTIVE_DISPATCH_ID"
assert_not_contains "generic dispatch is not labeled adopted" "$GENERIC_OUTPUT" "ADOPTED TASK CLASS"

FILTERED_PENDING_AFTER_GENERIC=$("$STATUS_BIN" --list-pending --governed-repo-mutations-only 2>&1)
assert_not_contains "governed filter excludes generic dispatch" "$FILTERED_PENDING_AFTER_GENERIC" "$GENERIC_ENVELOPE"

ALL_PENDING=$("$STATUS_BIN" --list-pending 2>&1)
assert_contains "unfiltered pending list includes generic dispatch" "$ALL_PENDING" "$GENERIC_ENVELOPE"

# ── Test: JSON mode includes workflow adoption metadata ──
JSON_OUTPUT=$("$DISPATCH_BIN" \
  --summary "JSON mode adopted dispatch" \
  --loop LOOP-TEST-JSON \
  --governed-repo-mutation \
  --governed-path bin/ops \
  --first-command "verify.fast -- --brief" \
  --json 2>&1)

TOTAL=$((TOTAL + 1))
if echo "$JSON_OUTPUT" | python3 -m json.tool >/dev/null 2>&1; then
  echo "PASS: adopted JSON mode produces valid JSON"
  PASS=$((PASS + 1))
else
  echo "FAIL: adopted JSON mode output is not valid JSON"
  FAIL=$((FAIL + 1))
fi

JSON_RULE=$(echo "$JSON_OUTPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("workflow_adoption", {}).get("rule_id", ""))' 2>/dev/null || true)
assert_eq "adopted JSON mode has workflow rule" "interactive_governed_repo_mutation_default" "$JSON_RULE"
JSON_ENVELOPE=$(echo "$JSON_OUTPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("envelope_id", ""))' 2>/dev/null || true)
if [[ -n "$JSON_ENVELOPE" ]]; then
  rm -f "$SPINE_STATE/dispatch/interactive/${JSON_ENVELOPE}.dispatch.yaml"
fi

# ── Test: Complete adopted dispatch via target-terminal env ──
FAKE_RUN_KEY="CAP-20260406-000000__verify.fast__Rtest123"
COMPLETE_OUTPUT=$(env \
  SPINE_STATE="$SPINE_STATE" \
  SPINE_EVIDENCE="$SPINE_EVIDENCE" \
  SPINE_INTERACTIVE_DISPATCH_ID="$ENVELOPE_ID" \
  "$COMPLETE_BIN" \
  --run-key "$FAKE_RUN_KEY" 2>&1)

assert_contains "complete output has COMPLETED" "$COMPLETE_OUTPUT" "INTERACTIVE DISPATCH COMPLETED"
assert_contains "complete output shows workflow" "$COMPLETE_OUTPUT" "Workflow:   controller-issued secondary-terminal governed spine repo mutation"

COMP_FILE="$SPINE_STATE/dispatch/completion/${ENVELOPE_ID}.completion.json"
assert_file_exists "completion artifact created" "$COMP_FILE"

if [[ -f "$COMP_FILE" ]]; then
  COMP_ENVELOPE=$(python3 -c "import json; print(json.load(open('$COMP_FILE'))['envelope_id'])" 2>/dev/null || true)
  COMP_RUN_KEY=$(python3 -c "import json; print(json.load(open('$COMP_FILE'))['run_key'])" 2>/dev/null || true)
  COMP_STATUS=$(python3 -c "import json; print(json.load(open('$COMP_FILE'))['completion_status'])" 2>/dev/null || true)

  assert_eq "completion envelope_id matches adopted dispatch" "$ENVELOPE_ID" "$COMP_ENVELOPE"
  assert_eq "completion run_key matches" "$FAKE_RUN_KEY" "$COMP_RUN_KEY"
  assert_eq "completion status" "complete" "$COMP_STATUS"
fi

STATUS_COMPLETE=$("$STATUS_BIN" --dispatch-id "$ENVELOPE_ID" 2>&1)
assert_contains "status reports complete after completion" "$STATUS_COMPLETE" "status: complete"
assert_contains "status reports run key after completion" "$STATUS_COMPLETE" "$FAKE_RUN_KEY"

FILTERED_PENDING_AFTER_COMPLETE=$("$STATUS_BIN" --list-pending --governed-repo-mutations-only 2>&1)
assert_contains "governed filter empty after completion" "$FILTERED_PENDING_AFTER_COMPLETE" "pending_dispatches: 0"

# ── Test: Invalid governed path is rejected ──
TOTAL=$((TOTAL + 1))
if "$DISPATCH_BIN" \
  --summary "Should reject non-governed path" \
  --governed-repo-mutation \
  --governed-path docs/governance/SPINE.md \
  --first-command "verify.fast -- --brief" >/dev/null 2>&1; then
  echo "FAIL: dispatch should reject non-governed path"
  FAIL=$((FAIL + 1))
else
  echo "PASS: dispatch rejects non-governed path"
  PASS=$((PASS + 1))
fi

# ── Test: governed path without adopted mode is rejected ──
TOTAL=$((TOTAL + 1))
if "$DISPATCH_BIN" \
  --summary "Should require adopted mode" \
  --governed-path ops/bindings/session.admission.contract.yaml \
  --first-command "verify.fast -- --brief" >/dev/null 2>&1; then
  echo "FAIL: dispatch should require --governed-repo-mutation when governed path is provided"
  FAIL=$((FAIL + 1))
else
  echo "PASS: dispatch requires --governed-repo-mutation when governed path is provided"
  PASS=$((PASS + 1))
fi

echo ""
echo "════════════════════════════════════════"
echo "INTERACTIVE DISPATCH: $PASS/$TOTAL passed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILURES: $FAIL"
  exit 1
fi
echo "════════════════════════════════════════"
