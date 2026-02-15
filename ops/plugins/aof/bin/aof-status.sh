#!/usr/bin/env bash
# aof-status — AOF health summary: contract state, gates, caps, policy.
set -euo pipefail

SP="${SPINE_ROOT:-${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}}"
SCHEMA_VERSION="1.1.0"
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
JSON_MODE=0

if [[ "${1:-}" == "--json" ]]; then
  JSON_MODE=1
  shift
fi

if [[ "$#" -gt 0 ]]; then
  echo "Usage: aof-status.sh [--json]" >&2
  exit 1
fi

ENV_CONTRACT="$SP/.environment.yaml"
contract_present=false
name=""
tier=""
ack_state="not_applicable"
if [[ -f "$ENV_CONTRACT" ]]; then
  contract_present=true
  tier="$(yq -r '.environment.tier // "unknown"' "$ENV_CONTRACT" 2>/dev/null || echo unknown)"
  name="$(yq -r '.environment.name // "unknown"' "$ENV_CONTRACT" 2>/dev/null || echo unknown)"
  today="$(date +%Y%m%d)"
  if [[ -f "$SP/.contract_read_$today" ]]; then
    ack_state="current"
  else
    ack_state="stale"
  fi
fi

source "$SP/ops/lib/resolve-policy.sh" 2>/dev/null && resolve_policy_knobs 2>/dev/null || true
policy_preset="${RESOLVED_POLICY_PRESET:-balanced}"
policy_gate_mode="${RESOLVED_DRIFT_GATE_MODE:-fail}"
policy_approval="${RESOLVED_APPROVAL_DEFAULT:-auto}"

cap_count="$(grep -c '^  [a-z]' "$SP/ops/capabilities.yaml" 2>/dev/null || true)"
aof_cap_count="$(grep -c '^  aof\.' "$SP/ops/capabilities.yaml" 2>/dev/null || true)"
gate_total="$(yq -r '.gate_count.total // 0' "$SP/ops/bindings/gate.registry.yaml" 2>/dev/null || echo 0)"
gate_active="$(yq -r '.gate_count.active // 0' "$SP/ops/bindings/gate.registry.yaml" 2>/dev/null || echo 0)"
open_gaps="$(grep -c 'status: open' "$SP/ops/bindings/operational.gaps.yaml" 2>/dev/null || true)"
open_loops="$(find "$SP/mailroom/state/loop-scopes" -name '*.scope.md' -exec grep -l 'status: open' {} + 2>/dev/null | wc -l | tr -d ' ')"
tenant_profile_path="$SP/ops/bindings/tenant.profile.yaml"
tenant_bound=false
if [[ -f "$tenant_profile_path" ]]; then
  tenant_bound=true
fi

if [[ "$JSON_MODE" -eq 1 ]]; then
  jq -n \
    --arg capability "aof.status" \
    --arg schema_version "$SCHEMA_VERSION" \
    --arg generated_at "$GENERATED_AT" \
    --arg status "ok" \
    --argjson contract_present "$contract_present" \
    --arg environment_name "$name" \
    --arg tier "$tier" \
    --arg ack_state "$ack_state" \
    --arg policy_preset "$policy_preset" \
    --arg policy_gate_mode "$policy_gate_mode" \
    --arg policy_approval "$policy_approval" \
    --argjson cap_count "${cap_count:-0}" \
    --argjson aof_cap_count "${aof_cap_count:-0}" \
    --argjson gate_total "${gate_total:-0}" \
    --argjson gate_active "${gate_active:-0}" \
    --argjson open_gaps "${open_gaps:-0}" \
    --argjson open_loops "${open_loops:-0}" \
    --argjson tenant_bound "$tenant_bound" \
    --arg tenant_profile_path "$tenant_profile_path" \
    '{
      capability: $capability,
      schema_version: $schema_version,
      generated_at: $generated_at,
      status: $status,
      data: {
        contract: {
          present: $contract_present,
          environment: (if $environment_name == "" then null else $environment_name end),
          tier: (if $tier == "" then null else $tier end),
          ack_state: $ack_state
        },
        policy: {
          preset: $policy_preset,
          drift_gate_mode: $policy_gate_mode,
          approval_default: $policy_approval
        },
        counts: {
          capabilities_total: $cap_count,
          capabilities_aof: $aof_cap_count,
          gates_total: $gate_total,
          gates_active: $gate_active,
          open_gaps: $open_gaps,
          open_loops: $open_loops
        },
        tenant: {
          bound: $tenant_bound,
          profile_path: $tenant_profile_path
        }
      }
    }'
  exit 0
fi

echo "═══════════════════════════════════════"
echo "  AOF STATUS"
echo "═══════════════════════════════════════"
echo ""

# ── Contract state ──
if [[ "$contract_present" == true ]]; then
  echo "Contract:    present"
  echo "Environment: $name"
  echo "Tier:        $tier"
  if [[ "$ack_state" == "current" ]]; then
    echo "Ack:         current (today)"
  else
    echo "Ack:         STALE (not acknowledged today)"
  fi
else
  echo "Contract:    not present (no .environment.yaml)"
fi
echo ""

# ── Policy ──
echo "Policy:      $policy_preset"
echo "Gate mode:   $policy_gate_mode"
echo "Approval:    $policy_approval"
echo ""

# ── Capability count ──
echo "Capabilities: $cap_count total, $aof_cap_count aof.*"

# ── Gate count ──
echo "Gates:        $gate_total total, $gate_active active"

# ── Open gaps/loops ──
echo "Open gaps:    $open_gaps"
echo "Open loops:   $open_loops"

# ── Tenant profile ──
if [[ "$tenant_bound" == true ]]; then
  echo "Tenant:       bound"
else
  echo "Tenant:       not bound (use fixtures/tenant.sample.yaml as template)"
fi
echo ""
echo "═══════════════════════════════════════"
