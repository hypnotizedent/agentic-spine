#!/usr/bin/env bash
set -euo pipefail

# resolve-policy-test.sh — Unit tests for ops/lib/resolve-policy.sh
#
# Tests:
#   T1: No profile/preset → resolves to balanced defaults
#   T2: SPINE_POLICY_PRESET=strict → resolves strict knob values
#   T3: SPINE_TENANT_PROFILE=fixtures/tenant.sample.yaml → reads preset from profile
#   T4: Missing yq → falls back to defaults without error
#   T5: Per-knob override in tenant profile → override applied on top of preset

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

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
