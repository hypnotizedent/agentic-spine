#!/usr/bin/env bash
# aof-policy-show — Show current policy preset with all 11 knob values.
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
  echo "Usage: aof-policy-show.sh [--json]" >&2
  exit 1
fi

# Source resolver and call it
source "$SP/ops/lib/resolve-policy.sh" 2>/dev/null || {
  echo "ERROR: resolve-policy.sh not found"
  exit 1
}
resolve_policy_knobs

active_preset="${RESOLVED_POLICY_PRESET:-balanced}"
drift_gate_mode="${RESOLVED_DRIFT_GATE_MODE:-fail}"
warn_policy="${RESOLVED_WARN_POLICY:-advisory}"
approval_default="${RESOLVED_APPROVAL_DEFAULT:-auto}"
session_closeout_sla_hours="${RESOLVED_SESSION_CLOSEOUT_SLA_HOURS:-48}"
stale_ssot_max_days="${RESOLVED_STALE_SSOT_MAX_DAYS:-14}"
gap_auto_claim="${RESOLVED_GAP_AUTO_CLAIM:-true}"
proposal_required="${RESOLVED_PROPOSAL_REQUIRED:-false}"
receipt_retention_days="${RESOLVED_RECEIPT_RETENTION_DAYS:-90}"
commit_sign_required="${RESOLVED_COMMIT_SIGN_REQUIRED:-false}"
multi_agent_writes="${RESOLVED_MULTI_AGENT_WRITES:-direct}"
multi_agent_writes_when_multi_session="${RESOLVED_MULTI_AGENT_WRITES_WHEN_MULTI_SESSION:-proposal-only}"

discovery_source="default"
discovery_detail="balanced"
if [[ -n "${SPINE_POLICY_PRESET:-}" ]]; then
  discovery_source="env.SPINE_POLICY_PRESET"
  discovery_detail="$SPINE_POLICY_PRESET"
elif [[ -n "${SPINE_TENANT_PROFILE:-}" ]]; then
  discovery_source="env.SPINE_TENANT_PROFILE"
  discovery_detail="$SPINE_TENANT_PROFILE"
elif [[ -f "$SP/ops/bindings/tenant.profile.yaml" ]]; then
  discovery_source="tenant.profile.yaml"
  discovery_detail="$SP/ops/bindings/tenant.profile.yaml"
fi

# ── Available presets ──
presets_file="$SP/ops/bindings/policy.presets.yaml"
declare -a presets=()
if [[ -f "$presets_file" ]]; then
  mapfile -t presets < <(yq -r '.presets | keys | .[]' "$presets_file" 2>/dev/null || true)
fi

if [[ "$JSON_MODE" -eq 1 ]]; then
  presets_json="$(printf '%s\n' "${presets[@]-}" | jq -R . | jq -s 'map(select(length > 0))')"
  jq -n \
    --arg capability "aof.policy.show" \
    --arg schema_version "$SCHEMA_VERSION" \
    --arg generated_at "$GENERATED_AT" \
    --arg status "ok" \
    --arg active_preset "$active_preset" \
    --arg drift_gate_mode "$drift_gate_mode" \
    --arg warn_policy "$warn_policy" \
    --arg approval_default "$approval_default" \
    --arg session_closeout_sla_hours "$session_closeout_sla_hours" \
    --arg stale_ssot_max_days "$stale_ssot_max_days" \
    --arg gap_auto_claim "$gap_auto_claim" \
    --arg proposal_required "$proposal_required" \
    --arg receipt_retention_days "$receipt_retention_days" \
    --arg commit_sign_required "$commit_sign_required" \
    --arg multi_agent_writes "$multi_agent_writes" \
    --arg multi_agent_writes_when_multi_session "$multi_agent_writes_when_multi_session" \
    --arg discovery_source "$discovery_source" \
    --arg discovery_detail "$discovery_detail" \
    --argjson available_presets "$presets_json" \
    '{
      capability: $capability,
      schema_version: $schema_version,
      generated_at: $generated_at,
      status: $status,
      data: {
        active_preset: $active_preset,
        knobs: {
          drift_gate_mode: $drift_gate_mode,
          warn_policy: $warn_policy,
          approval_default: $approval_default,
          session_closeout_sla_hours: $session_closeout_sla_hours,
          stale_ssot_max_days: $stale_ssot_max_days,
          gap_auto_claim: $gap_auto_claim,
          proposal_required: $proposal_required,
          receipt_retention_days: $receipt_retention_days,
          commit_sign_required: $commit_sign_required,
          multi_agent_writes: $multi_agent_writes,
          multi_agent_writes_when_multi_session: $multi_agent_writes_when_multi_session
        },
        discovery: {
          source: $discovery_source,
          detail: $discovery_detail
        },
        available_presets: $available_presets
      }
    }'
  exit 0
fi

echo "═══════════════════════════════════════"
echo "  AOF POLICY"
echo "═══════════════════════════════════════"
echo ""
echo "Active preset:  $active_preset"
echo ""
echo "Knobs:"
echo "  drift_gate_mode:          $drift_gate_mode"
echo "  warn_policy:              $warn_policy"
echo "  approval_default:         $approval_default"
echo "  session_closeout_sla_hours: $session_closeout_sla_hours"
echo "  stale_ssot_max_days:      $stale_ssot_max_days"
echo "  gap_auto_claim:           $gap_auto_claim"
echo "  proposal_required:        $proposal_required"
echo "  receipt_retention_days:   $receipt_retention_days"
echo "  commit_sign_required:     $commit_sign_required"
echo "  multi_agent_writes:       $multi_agent_writes"
echo "  multi_agent_writes_when_multi_session: $multi_agent_writes_when_multi_session"
echo ""
echo "Discovery chain:"
if [[ "$discovery_source" == "env.SPINE_POLICY_PRESET" ]]; then
  echo "  Source: SPINE_POLICY_PRESET env var"
elif [[ "$discovery_source" == "env.SPINE_TENANT_PROFILE" ]]; then
  echo "  Source: SPINE_TENANT_PROFILE env var ($discovery_detail)"
elif [[ "$discovery_source" == "tenant.profile.yaml" ]]; then
  echo "  Source: tenant.profile.yaml"
else
  echo "  Source: default (balanced)"
fi

if [[ -f "$presets_file" ]]; then
  echo ""
  echo "Available presets:"
  for p in "${presets[@]-}"; do
    marker=""
    [[ "$p" == "$active_preset" ]] && marker=" (active)"
    echo "  - $p$marker"
  done
fi

echo ""
echo "═══════════════════════════════════════"
