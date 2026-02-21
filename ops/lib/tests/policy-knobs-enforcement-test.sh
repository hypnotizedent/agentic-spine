#!/usr/bin/env bash
set -euo pipefail

# policy-knobs-enforcement-test.sh — Tests for Phase B policy knob enforcement wiring
#
# Tests:
#   T1: stale_ssot_max_days → D58 receives SSOT_FRESHNESS_DAYS from policy
#   T2: gap_auto_claim=true → gaps-file auto-claims after filing
#   T3: gap_auto_claim=false → gaps-file does NOT auto-claim
#   T4: proposal_required=true → cap.sh blocks mutating caps
#   T5: proposal_required=false → cap.sh allows mutating caps
#   T6: multi_agent_writes=proposal-only → cap.sh blocks direct mutating caps
#   T7: receipt_retention_days → evidence.export.plan uses policy value
#   T8: commit_sign_required=true → pre-commit blocks unsigned commits
#   T9: multi_agent_writes=proposal-only → pre-commit blocks main commits
#   T10: multi_agent_writes_when_multi_session → cap.sh uses session-count override

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

echo "=== Policy Knobs Enforcement Tests ==="

# ── T1: stale_ssot_max_days → D58 SSOT_FRESHNESS_DAYS ──
echo ""
echo "T1: stale_ssot_max_days wires to D58 threshold"
(
  # Verify the drift-gate.sh exports SSOT_FRESHNESS_DAYS from RESOLVED_STALE_SSOT_MAX_DAYS
  grep -q 'SSOT_FRESHNESS_DAYS.*RESOLVED_STALE_SSOT_MAX_DAYS' "$ROOT/surfaces/verify/drift-gate.sh" || {
    echo "  FAIL: drift-gate.sh does not wire SSOT_FRESHNESS_DAYS from RESOLVED_STALE_SSOT_MAX_DAYS" >&2
    exit 1
  }
  # Verify D58 reads SSOT_FRESHNESS_DAYS
  grep -q 'SSOT_FRESHNESS_DAYS' "$ROOT/surfaces/verify/d58-ssot-freshness-lock.sh" || {
    echo "  FAIL: D58 does not read SSOT_FRESHNESS_DAYS" >&2
    exit 1
  }
  # Verify the value resolves to 14 for balanced
  unset SPINE_POLICY_PRESET SPINE_TENANT_PROFILE SSOT_FRESHNESS_DAYS
  SP="$ROOT"
  export SP
  source "$ROOT/ops/lib/resolve-policy.sh"
  resolve_policy_knobs
  [[ "$RESOLVED_STALE_SSOT_MAX_DAYS" == "14" ]] || {
    echo "  FAIL: balanced stale_ssot_max_days=$RESOLVED_STALE_SSOT_MAX_DAYS expected=14" >&2
    exit 1
  }
) && pass "stale_ssot_max_days wired to D58" || fail "stale_ssot_max_days wired to D58"

# ── T2: gap_auto_claim=true → auto-claim behavior ──
echo ""
echo "T2: gap_auto_claim=true triggers auto-claim in gaps-file"
(
  # Verify gaps-file sources resolve-policy.sh
  grep -q 'resolve-policy.sh' "$ROOT/ops/plugins/loops/bin/gaps-file" || {
    echo "  FAIL: gaps-file does not source resolve-policy.sh" >&2
    exit 1
  }
  # Verify gaps-file checks RESOLVED_GAP_AUTO_CLAIM
  grep -q 'RESOLVED_GAP_AUTO_CLAIM' "$ROOT/ops/plugins/loops/bin/gaps-file" || {
    echo "  FAIL: gaps-file does not check RESOLVED_GAP_AUTO_CLAIM" >&2
    exit 1
  }
  # Verify auto-claim call is present
  grep -q 'claim_gap.*auto-claimed' "$ROOT/ops/plugins/loops/bin/gaps-file" || {
    echo "  FAIL: gaps-file does not call claim_gap on auto-claim" >&2
    exit 1
  }
) && pass "gap_auto_claim=true auto-claims" || fail "gap_auto_claim=true auto-claims"

# ── T3: gap_auto_claim=false → no auto-claim ──
echo ""
echo "T3: gap_auto_claim=false skips auto-claim"
(
  # The conditional should only fire when == "true"
  grep -q '"${RESOLVED_GAP_AUTO_CLAIM:-false}" == "true"' "$ROOT/ops/plugins/loops/bin/gaps-file" || {
    echo "  FAIL: gaps-file auto-claim conditional not properly guarded" >&2
    exit 1
  }
  # Verify strict preset gives false
  unset SPINE_TENANT_PROFILE
  SP="$ROOT"
  SPINE_POLICY_PRESET="strict"
  export SP SPINE_POLICY_PRESET
  source "$ROOT/ops/lib/resolve-policy.sh"
  resolve_policy_knobs
  [[ "$RESOLVED_GAP_AUTO_CLAIM" == "false" ]] || {
    echo "  FAIL: strict gap_auto_claim=$RESOLVED_GAP_AUTO_CLAIM expected=false" >&2
    exit 1
  }
) && pass "gap_auto_claim=false no auto-claim" || fail "gap_auto_claim=false no auto-claim"

# ── T4: proposal_required=true → cap.sh blocks mutating ──
echo ""
echo "T4: proposal_required=true blocks mutating caps"
(
  grep -q 'RESOLVED_PROPOSAL_REQUIRED.*true' "$ROOT/ops/commands/cap.sh" || {
    echo "  FAIL: cap.sh does not check RESOLVED_PROPOSAL_REQUIRED" >&2
    exit 1
  }
  grep -q 'BLOCKED.*proposal_required=true' "$ROOT/ops/commands/cap.sh" || {
    echo "  FAIL: cap.sh does not emit BLOCKED message for proposal_required" >&2
    exit 1
  }
) && pass "proposal_required=true blocks mutating" || fail "proposal_required=true blocks mutating"

# ── T5: proposal_required=false → no block ──
echo ""
echo "T5: proposal_required=false allows caps"
(
  # Verify balanced resolves to false
  unset SPINE_POLICY_PRESET SPINE_TENANT_PROFILE
  SP="$ROOT"
  export SP
  source "$ROOT/ops/lib/resolve-policy.sh"
  resolve_policy_knobs
  [[ "$RESOLVED_PROPOSAL_REQUIRED" == "false" ]] || {
    echo "  FAIL: balanced proposal_required=$RESOLVED_PROPOSAL_REQUIRED expected=false" >&2
    exit 1
  }
) && pass "proposal_required=false allows caps" || fail "proposal_required=false allows caps"

# ── T6: multi_agent_writes=proposal-only → cap.sh blocks ──
echo ""
echo "T6: multi_agent_writes=proposal-only blocks in cap.sh"
(
  grep -q 'RESOLVED_MULTI_AGENT_WRITES.*proposal-only' "$ROOT/ops/commands/cap.sh" || {
    echo "  FAIL: cap.sh does not check RESOLVED_MULTI_AGENT_WRITES" >&2
    exit 1
  }
  grep -q 'BLOCKED.*multi_agent_writes=proposal-only' "$ROOT/ops/commands/cap.sh" || {
    echo "  FAIL: cap.sh does not emit BLOCKED message for multi_agent_writes" >&2
    exit 1
  }
) && pass "multi_agent_writes=proposal-only blocks in cap.sh" || fail "multi_agent_writes=proposal-only blocks in cap.sh"

# ── T7: receipt_retention_days → evidence.export.plan ──
echo ""
echo "T7: receipt_retention_days wires to evidence.export.plan"
(
  grep -q 'RESOLVED_RECEIPT_RETENTION_DAYS' "$ROOT/ops/plugins/evidence/bin/evidence-export-plan" || {
    echo "  FAIL: evidence-export-plan does not read RESOLVED_RECEIPT_RETENTION_DAYS" >&2
    exit 1
  }
  grep -q 'policy override' "$ROOT/ops/plugins/evidence/bin/evidence-export-plan" || {
    echo "  FAIL: evidence-export-plan does not indicate policy override" >&2
    exit 1
  }
) && pass "receipt_retention_days wired to evidence.export.plan" || fail "receipt_retention_days wired to evidence.export.plan"

# ── T8: commit_sign_required=true → pre-commit blocks ──
echo ""
echo "T8: commit_sign_required=true blocks unsigned commits"
(
  grep -q 'RESOLVED_COMMIT_SIGN_REQUIRED.*true' "$ROOT/.githooks/pre-commit" || {
    echo "  FAIL: pre-commit does not check RESOLVED_COMMIT_SIGN_REQUIRED" >&2
    exit 1
  }
  grep -q 'BLOCKED.*commit_sign_required=true' "$ROOT/.githooks/pre-commit" || {
    echo "  FAIL: pre-commit does not emit BLOCKED message for commit_sign_required" >&2
    exit 1
  }
  grep -q 'user.signingkey' "$ROOT/.githooks/pre-commit" || {
    echo "  FAIL: pre-commit does not check user.signingkey" >&2
    exit 1
  }
) && pass "commit_sign_required blocks unsigned" || fail "commit_sign_required blocks unsigned"

# ── T9: multi_agent_writes=proposal-only → pre-commit blocks main ──
echo ""
echo "T9: multi_agent_writes=proposal-only blocks main in pre-commit"
(
  grep -q 'RESOLVED_MULTI_AGENT_WRITES.*proposal-only' "$ROOT/.githooks/pre-commit" || {
    echo "  FAIL: pre-commit does not check RESOLVED_MULTI_AGENT_WRITES" >&2
    exit 1
  }
  grep -q 'BLOCKED.*multi_agent_writes=proposal-only' "$ROOT/.githooks/pre-commit" || {
    echo "  FAIL: pre-commit does not emit BLOCKED for multi_agent_writes" >&2
    exit 1
  }
) && pass "multi_agent_writes blocks main in pre-commit" || fail "multi_agent_writes blocks main in pre-commit"

# ── T10: multi_agent_writes_when_multi_session → cap.sh session override ──
echo ""
echo "T10: multi_agent_writes_when_multi_session is enforced in cap.sh"
(
  grep -q 'RESOLVED_MULTI_AGENT_WRITES_WHEN_MULTI_SESSION' "$ROOT/ops/commands/cap.sh" || {
    echo "  FAIL: cap.sh does not check RESOLVED_MULTI_AGENT_WRITES_WHEN_MULTI_SESSION" >&2
    exit 1
  }
  unset SPINE_POLICY_PRESET SPINE_TENANT_PROFILE
  SP="$ROOT"
  export SP
  source "$ROOT/ops/lib/resolve-policy.sh"
  resolve_policy_knobs
  [[ "$RESOLVED_MULTI_AGENT_WRITES_WHEN_MULTI_SESSION" == "proposal-only" ]] || {
    echo "  FAIL: balanced multi_agent_writes_when_multi_session=$RESOLVED_MULTI_AGENT_WRITES_WHEN_MULTI_SESSION expected=proposal-only" >&2
    exit 1
  }
) && pass "multi_agent_writes_when_multi_session enforced" || fail "multi_agent_writes_when_multi_session enforced"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
