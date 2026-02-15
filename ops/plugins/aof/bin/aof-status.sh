#!/usr/bin/env bash
# aof-status — AOF health summary: contract state, gates, caps, policy.
set -euo pipefail

SP="${SPINE_ROOT:-${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}}"

echo "═══════════════════════════════════════"
echo "  AOF STATUS"
echo "═══════════════════════════════════════"
echo ""

# ── Contract state ──
ENV_CONTRACT="$SP/.environment.yaml"
if [[ -f "$ENV_CONTRACT" ]]; then
  tier="$(yq -r '.environment.tier // "unknown"' "$ENV_CONTRACT" 2>/dev/null || echo unknown)"
  name="$(yq -r '.environment.name // "unknown"' "$ENV_CONTRACT" 2>/dev/null || echo unknown)"
  echo "Contract:    present"
  echo "Environment: $name"
  echo "Tier:        $tier"
  # Check ack status
  today="$(date +%Y%m%d)"
  if [[ -f "$SP/.contract_read_$today" ]]; then
    echo "Ack:         current (today)"
  else
    echo "Ack:         STALE (not acknowledged today)"
  fi
else
  echo "Contract:    not present (no .environment.yaml)"
fi
echo ""

# ── Policy ──
source "$SP/ops/lib/resolve-policy.sh" 2>/dev/null && resolve_policy_knobs 2>/dev/null || true
echo "Policy:      ${RESOLVED_POLICY_PRESET:-balanced}"
echo "Gate mode:   ${RESOLVED_DRIFT_GATE_MODE:-fail}"
echo "Approval:    ${RESOLVED_APPROVAL_DEFAULT:-auto}"
echo ""

# ── Capability count ──
cap_count="$(grep -c '^  [a-z]' "$SP/ops/capabilities.yaml" 2>/dev/null || echo 0)"
aof_cap_count="$(grep -c '^  aof\.' "$SP/ops/capabilities.yaml" 2>/dev/null || echo 0)"
echo "Capabilities: $cap_count total, $aof_cap_count aof.*"

# ── Gate count ──
gate_total="$(yq -r '.gate_count.total // 0' "$SP/ops/bindings/gate.registry.yaml" 2>/dev/null || echo 0)"
gate_active="$(yq -r '.gate_count.active // 0' "$SP/ops/bindings/gate.registry.yaml" 2>/dev/null || echo 0)"
echo "Gates:        $gate_total total, $gate_active active"

# ── Open gaps/loops ──
open_gaps="$(grep -c 'status: open' "$SP/ops/bindings/operational.gaps.yaml" 2>/dev/null || echo 0)"
open_loops="$(find "$SP/mailroom/state/loop-scopes" -name '*.scope.md' -exec grep -l 'status: open' {} \; 2>/dev/null | wc -l | tr -d ' ')"
echo "Open gaps:    $open_gaps"
echo "Open loops:   $open_loops"

# ── Tenant profile ──
if [[ -f "$SP/ops/bindings/tenant.profile.yaml" ]]; then
  echo "Tenant:       bound"
else
  echo "Tenant:       not bound (use fixtures/tenant.sample.yaml as template)"
fi
echo ""
echo "═══════════════════════════════════════"
