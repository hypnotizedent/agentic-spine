#!/usr/bin/env bash
# aof-policy-show — Show current policy preset with all 10 knob values.
set -euo pipefail

SP="${SPINE_ROOT:-${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}}"

echo "═══════════════════════════════════════"
echo "  AOF POLICY"
echo "═══════════════════════════════════════"
echo ""

# Source resolver and call it
source "$SP/ops/lib/resolve-policy.sh" 2>/dev/null || {
  echo "ERROR: resolve-policy.sh not found"
  exit 1
}
resolve_policy_knobs

echo "Active preset:  $RESOLVED_POLICY_PRESET"
echo ""
echo "Knobs:"
echo "  drift_gate_mode:          $RESOLVED_DRIFT_GATE_MODE"
echo "  warn_policy:              $RESOLVED_WARN_POLICY"
echo "  approval_default:         $RESOLVED_APPROVAL_DEFAULT"
echo "  session_closeout_sla_hours: $RESOLVED_SESSION_CLOSEOUT_SLA_HOURS"
echo "  stale_ssot_max_days:      $RESOLVED_STALE_SSOT_MAX_DAYS"
echo "  gap_auto_claim:           $RESOLVED_GAP_AUTO_CLAIM"
echo "  proposal_required:        $RESOLVED_PROPOSAL_REQUIRED"
echo "  receipt_retention_days:   $RESOLVED_RECEIPT_RETENTION_DAYS"
echo "  commit_sign_required:     $RESOLVED_COMMIT_SIGN_REQUIRED"
echo "  multi_agent_writes:       $RESOLVED_MULTI_AGENT_WRITES"

# ── Discovery chain trace ──
echo ""
echo "Discovery chain:"
if [[ -n "${SPINE_POLICY_PRESET:-}" ]]; then
  echo "  Source: SPINE_POLICY_PRESET env var"
elif [[ -n "${SPINE_TENANT_PROFILE:-}" ]]; then
  echo "  Source: SPINE_TENANT_PROFILE env var ($SPINE_TENANT_PROFILE)"
elif [[ -f "$SP/ops/bindings/tenant.profile.yaml" ]]; then
  echo "  Source: tenant.profile.yaml"
else
  echo "  Source: default (balanced)"
fi

# ── Available presets ──
presets_file="$SP/ops/bindings/policy.presets.yaml"
if [[ -f "$presets_file" ]]; then
  echo ""
  echo "Available presets:"
  yq -r '.presets | keys | .[]' "$presets_file" 2>/dev/null | while read -r p; do
    marker=""
    [[ "$p" == "$RESOLVED_POLICY_PRESET" ]] && marker=" (active)"
    echo "  - $p$marker"
  done
fi

echo ""
echo "═══════════════════════════════════════"
