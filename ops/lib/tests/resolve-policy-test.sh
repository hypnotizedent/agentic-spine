#!/usr/bin/env bash
set -euo pipefail

# resolve-policy-test.sh — Unit tests for ops/lib/resolve-policy.sh
#
# Tests:
#   T1: No profile/preset → resolves to balanced defaults (all 10 knobs)
#   T2: SPINE_POLICY_PRESET=strict → resolves strict knob values (all 10 knobs)
#   T3: SPINE_TENANT_PROFILE=fixtures/tenant.sample.yaml → reads preset from profile
#   T4: Missing yq → falls back to defaults without error
#   T5: Per-knob override in tenant profile → override applied on top of preset
#   T6: Phase B knobs resolve correctly for permissive preset
#   T7: Phase B per-knob overrides in tenant profile

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

echo "=== resolve-policy.sh tests ==="

# ── T1: Default (balanced) ──
echo ""
echo "T1: No profile/preset → balanced defaults"
(
  unset SPINE_POLICY_PRESET SPINE_TENANT_PROFILE
  SP="$ROOT"
  export SP
  source "$ROOT/ops/lib/resolve-policy.sh"
  resolve_policy_knobs
  [[ "$RESOLVED_POLICY_PRESET" == "balanced" ]] || { echo "  FAIL: preset=$RESOLVED_POLICY_PRESET expected=balanced" >&2; exit 1; }
  [[ "$RESOLVED_DRIFT_GATE_MODE" == "fail" ]] || { echo "  FAIL: drift_gate_mode=$RESOLVED_DRIFT_GATE_MODE expected=fail" >&2; exit 1; }
  [[ "$RESOLVED_WARN_POLICY" == "advisory" ]] || { echo "  FAIL: warn_policy=$RESOLVED_WARN_POLICY expected=advisory" >&2; exit 1; }
  [[ "$RESOLVED_APPROVAL_DEFAULT" == "auto" ]] || { echo "  FAIL: approval_default=$RESOLVED_APPROVAL_DEFAULT expected=auto" >&2; exit 1; }
  [[ "$RESOLVED_SESSION_CLOSEOUT_SLA_HOURS" == "48" ]] || { echo "  FAIL: sla=$RESOLVED_SESSION_CLOSEOUT_SLA_HOURS expected=48" >&2; exit 1; }
  [[ "$RESOLVED_STALE_SSOT_MAX_DAYS" == "14" ]] || { echo "  FAIL: stale_ssot=$RESOLVED_STALE_SSOT_MAX_DAYS expected=14" >&2; exit 1; }
  [[ "$RESOLVED_GAP_AUTO_CLAIM" == "true" ]] || { echo "  FAIL: gap_auto_claim=$RESOLVED_GAP_AUTO_CLAIM expected=true" >&2; exit 1; }
  [[ "$RESOLVED_PROPOSAL_REQUIRED" == "false" ]] || { echo "  FAIL: proposal_required=$RESOLVED_PROPOSAL_REQUIRED expected=false" >&2; exit 1; }
  [[ "$RESOLVED_RECEIPT_RETENTION_DAYS" == "30" ]] || { echo "  FAIL: receipt_retention=$RESOLVED_RECEIPT_RETENTION_DAYS expected=30" >&2; exit 1; }
  [[ "$RESOLVED_COMMIT_SIGN_REQUIRED" == "false" ]] || { echo "  FAIL: commit_sign=$RESOLVED_COMMIT_SIGN_REQUIRED expected=false" >&2; exit 1; }
  [[ "$RESOLVED_MULTI_AGENT_WRITES" == "direct" ]] || { echo "  FAIL: multi_agent=$RESOLVED_MULTI_AGENT_WRITES expected=direct" >&2; exit 1; }
) && pass "balanced defaults" || fail "balanced defaults"

# ── T2: Strict preset ──
echo ""
echo "T2: SPINE_POLICY_PRESET=strict → strict knob values"
(
  unset SPINE_TENANT_PROFILE
  SP="$ROOT"
  SPINE_POLICY_PRESET="strict"
  export SP SPINE_POLICY_PRESET
  source "$ROOT/ops/lib/resolve-policy.sh"
  resolve_policy_knobs
  [[ "$RESOLVED_POLICY_PRESET" == "strict" ]] || { echo "  FAIL: preset=$RESOLVED_POLICY_PRESET expected=strict" >&2; exit 1; }
  [[ "$RESOLVED_DRIFT_GATE_MODE" == "fail" ]] || { echo "  FAIL: drift_gate_mode=$RESOLVED_DRIFT_GATE_MODE expected=fail" >&2; exit 1; }
  [[ "$RESOLVED_WARN_POLICY" == "strict" ]] || { echo "  FAIL: warn_policy=$RESOLVED_WARN_POLICY expected=strict" >&2; exit 1; }
  [[ "$RESOLVED_APPROVAL_DEFAULT" == "manual" ]] || { echo "  FAIL: approval_default=$RESOLVED_APPROVAL_DEFAULT expected=manual" >&2; exit 1; }
  [[ "$RESOLVED_SESSION_CLOSEOUT_SLA_HOURS" == "24" ]] || { echo "  FAIL: sla=$RESOLVED_SESSION_CLOSEOUT_SLA_HOURS expected=24" >&2; exit 1; }
  [[ "$RESOLVED_STALE_SSOT_MAX_DAYS" == "7" ]] || { echo "  FAIL: stale_ssot=$RESOLVED_STALE_SSOT_MAX_DAYS expected=7" >&2; exit 1; }
  [[ "$RESOLVED_GAP_AUTO_CLAIM" == "false" ]] || { echo "  FAIL: gap_auto_claim=$RESOLVED_GAP_AUTO_CLAIM expected=false" >&2; exit 1; }
  [[ "$RESOLVED_PROPOSAL_REQUIRED" == "true" ]] || { echo "  FAIL: proposal_required=$RESOLVED_PROPOSAL_REQUIRED expected=true" >&2; exit 1; }
  [[ "$RESOLVED_RECEIPT_RETENTION_DAYS" == "90" ]] || { echo "  FAIL: receipt_retention=$RESOLVED_RECEIPT_RETENTION_DAYS expected=90" >&2; exit 1; }
  [[ "$RESOLVED_COMMIT_SIGN_REQUIRED" == "true" ]] || { echo "  FAIL: commit_sign=$RESOLVED_COMMIT_SIGN_REQUIRED expected=true" >&2; exit 1; }
  [[ "$RESOLVED_MULTI_AGENT_WRITES" == "proposal-only" ]] || { echo "  FAIL: multi_agent=$RESOLVED_MULTI_AGENT_WRITES expected=proposal-only" >&2; exit 1; }
) && pass "strict preset" || fail "strict preset"

# ── T3: Tenant profile path ──
echo ""
echo "T3: SPINE_TENANT_PROFILE → reads preset from profile"
(
  unset SPINE_POLICY_PRESET
  SP="$ROOT"
  SPINE_TENANT_PROFILE="$ROOT/fixtures/tenant.sample.yaml"
  export SP SPINE_TENANT_PROFILE
  source "$ROOT/ops/lib/resolve-policy.sh"
  resolve_policy_knobs
  [[ "$RESOLVED_POLICY_PRESET" == "balanced" ]] || { echo "  FAIL: preset=$RESOLVED_POLICY_PRESET expected=balanced" >&2; exit 1; }
  [[ "$RESOLVED_DRIFT_GATE_MODE" == "fail" ]] || { echo "  FAIL: drift_gate_mode=$RESOLVED_DRIFT_GATE_MODE expected=fail" >&2; exit 1; }
  [[ "$RESOLVED_APPROVAL_DEFAULT" == "auto" ]] || { echo "  FAIL: approval_default=$RESOLVED_APPROVAL_DEFAULT expected=auto" >&2; exit 1; }
) && pass "tenant profile path" || fail "tenant profile path"

# ── T4: Missing yq → fallback to defaults ──
echo ""
echo "T4: Missing yq → falls back to defaults without error"
(
  unset SPINE_POLICY_PRESET SPINE_TENANT_PROFILE
  SP="$ROOT"
  export SP
  # Override PATH to hide yq
  export PATH="/usr/bin:/bin"
  source "$ROOT/ops/lib/resolve-policy.sh"
  resolve_policy_knobs
  [[ "$RESOLVED_POLICY_PRESET" == "balanced" ]] || { echo "  FAIL: preset=$RESOLVED_POLICY_PRESET expected=balanced" >&2; exit 1; }
  [[ "$RESOLVED_DRIFT_GATE_MODE" == "fail" ]] || { echo "  FAIL: drift_gate_mode=$RESOLVED_DRIFT_GATE_MODE expected=fail" >&2; exit 1; }
  [[ "$RESOLVED_WARN_POLICY" == "advisory" ]] || { echo "  FAIL: warn_policy=$RESOLVED_WARN_POLICY expected=advisory" >&2; exit 1; }
  [[ "$RESOLVED_APPROVAL_DEFAULT" == "auto" ]] || { echo "  FAIL: approval_default=$RESOLVED_APPROVAL_DEFAULT expected=auto" >&2; exit 1; }
  [[ "$RESOLVED_SESSION_CLOSEOUT_SLA_HOURS" == "48" ]] || { echo "  FAIL: sla=$RESOLVED_SESSION_CLOSEOUT_SLA_HOURS expected=48" >&2; exit 1; }
) && pass "missing yq fallback" || fail "missing yq fallback"

# ── T5: Per-knob override in tenant profile ──
echo ""
echo "T5: Per-knob override in tenant profile → override applied"
(
  unset SPINE_POLICY_PRESET
  SP="$ROOT"
  # Create a temporary profile with overrides
  TMP_PROFILE="$(mktemp /tmp/tenant-test.XXXXXX.yaml)"
  cat > "$TMP_PROFILE" <<'YAML'
policy:
  preset: balanced
  overrides:
    drift_gate_mode: warn
    session_closeout_sla_hours: 72
YAML
  SPINE_TENANT_PROFILE="$TMP_PROFILE"
  export SP SPINE_TENANT_PROFILE
  source "$ROOT/ops/lib/resolve-policy.sh"
  resolve_policy_knobs
  rm -f "$TMP_PROFILE"
  [[ "$RESOLVED_POLICY_PRESET" == "balanced" ]] || { echo "  FAIL: preset=$RESOLVED_POLICY_PRESET expected=balanced" >&2; exit 1; }
  [[ "$RESOLVED_DRIFT_GATE_MODE" == "warn" ]] || { echo "  FAIL: drift_gate_mode=$RESOLVED_DRIFT_GATE_MODE expected=warn (overridden)" >&2; exit 1; }
  [[ "$RESOLVED_WARN_POLICY" == "advisory" ]] || { echo "  FAIL: warn_policy=$RESOLVED_WARN_POLICY expected=advisory (not overridden)" >&2; exit 1; }
  [[ "$RESOLVED_SESSION_CLOSEOUT_SLA_HOURS" == "72" ]] || { echo "  FAIL: sla=$RESOLVED_SESSION_CLOSEOUT_SLA_HOURS expected=72 (overridden)" >&2; exit 1; }
) && pass "per-knob override" || fail "per-knob override"

# ── T6: Permissive preset — Phase B knobs ──
echo ""
echo "T6: SPINE_POLICY_PRESET=permissive → Phase B knob values"
(
  unset SPINE_TENANT_PROFILE
  SP="$ROOT"
  SPINE_POLICY_PRESET="permissive"
  export SP SPINE_POLICY_PRESET
  source "$ROOT/ops/lib/resolve-policy.sh"
  resolve_policy_knobs
  [[ "$RESOLVED_STALE_SSOT_MAX_DAYS" == "30" ]] || { echo "  FAIL: stale_ssot=$RESOLVED_STALE_SSOT_MAX_DAYS expected=30" >&2; exit 1; }
  [[ "$RESOLVED_GAP_AUTO_CLAIM" == "true" ]] || { echo "  FAIL: gap_auto_claim=$RESOLVED_GAP_AUTO_CLAIM expected=true" >&2; exit 1; }
  [[ "$RESOLVED_PROPOSAL_REQUIRED" == "false" ]] || { echo "  FAIL: proposal_required=$RESOLVED_PROPOSAL_REQUIRED expected=false" >&2; exit 1; }
  [[ "$RESOLVED_RECEIPT_RETENTION_DAYS" == "7" ]] || { echo "  FAIL: receipt_retention=$RESOLVED_RECEIPT_RETENTION_DAYS expected=7" >&2; exit 1; }
  [[ "$RESOLVED_COMMIT_SIGN_REQUIRED" == "false" ]] || { echo "  FAIL: commit_sign=$RESOLVED_COMMIT_SIGN_REQUIRED expected=false" >&2; exit 1; }
  [[ "$RESOLVED_MULTI_AGENT_WRITES" == "direct" ]] || { echo "  FAIL: multi_agent=$RESOLVED_MULTI_AGENT_WRITES expected=direct" >&2; exit 1; }
) && pass "permissive Phase B knobs" || fail "permissive Phase B knobs"

# ── T7: Per-knob Phase B overrides in tenant profile ──
echo ""
echo "T7: Per-knob Phase B overrides in tenant profile"
(
  unset SPINE_POLICY_PRESET
  SP="$ROOT"
  TMP_PROFILE="$(mktemp /tmp/tenant-test-pb.XXXXXX.yaml)"
  cat > "$TMP_PROFILE" <<'YAML'
policy:
  preset: balanced
  overrides:
    stale_ssot_max_days: 7
    gap_auto_claim: false
    receipt_retention_days: 60
YAML
  SPINE_TENANT_PROFILE="$TMP_PROFILE"
  export SP SPINE_TENANT_PROFILE
  source "$ROOT/ops/lib/resolve-policy.sh"
  resolve_policy_knobs
  rm -f "$TMP_PROFILE"
  [[ "$RESOLVED_STALE_SSOT_MAX_DAYS" == "7" ]] || { echo "  FAIL: stale_ssot=$RESOLVED_STALE_SSOT_MAX_DAYS expected=7 (overridden)" >&2; exit 1; }
  [[ "$RESOLVED_GAP_AUTO_CLAIM" == "false" ]] || { echo "  FAIL: gap_auto_claim=$RESOLVED_GAP_AUTO_CLAIM expected=false (overridden)" >&2; exit 1; }
  [[ "$RESOLVED_RECEIPT_RETENTION_DAYS" == "60" ]] || { echo "  FAIL: receipt_retention=$RESOLVED_RECEIPT_RETENTION_DAYS expected=60 (overridden)" >&2; exit 1; }
  [[ "$RESOLVED_PROPOSAL_REQUIRED" == "false" ]] || { echo "  FAIL: proposal_required=$RESOLVED_PROPOSAL_REQUIRED expected=false (not overridden)" >&2; exit 1; }
) && pass "Phase B per-knob overrides" || fail "Phase B per-knob overrides"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
