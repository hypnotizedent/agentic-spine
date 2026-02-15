#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# resolve-policy.sh - Shared policy preset resolver for AOF
# ═══════════════════════════════════════════════════════════════
#
# Sourced by drift-gate.sh and cap.sh. Exports resolved knob values
# based on the active policy preset.
#
# Discovery chain (first match wins):
#   1. SPINE_POLICY_PRESET env var (direct preset name)
#   2. SPINE_TENANT_PROFILE env var (path to tenant profile YAML)
#   3. $SP/ops/bindings/tenant.profile.yaml (well-known active profile)
#   4. Default: "balanced" (matches current hardcoded behavior)
#
# Exports:
#   RESOLVED_POLICY_PRESET            preset name
#   RESOLVED_DRIFT_GATE_MODE          fail|warn
#   RESOLVED_WARN_POLICY              strict|advisory
#   RESOLVED_APPROVAL_DEFAULT         auto|manual
#   RESOLVED_SESSION_CLOSEOUT_SLA_HOURS  integer
#   RESOLVED_STALE_SSOT_MAX_DAYS      integer
#   RESOLVED_GAP_AUTO_CLAIM           true|false
#   RESOLVED_PROPOSAL_REQUIRED        true|false
#   RESOLVED_RECEIPT_RETENTION_DAYS   integer
#   RESOLVED_COMMIT_SIGN_REQUIRED     true|false
#   RESOLVED_MULTI_AGENT_WRITES       proposal-only|direct
#
# ═══════════════════════════════════════════════════════════════

# Balanced defaults (matches current hardcoded behavior — zero behavioral change)
_BALANCED_DRIFT_GATE_MODE="fail"
_BALANCED_WARN_POLICY="advisory"
_BALANCED_APPROVAL_DEFAULT="auto"
_BALANCED_SESSION_CLOSEOUT_SLA_HOURS="48"
_BALANCED_STALE_SSOT_MAX_DAYS="14"
_BALANCED_GAP_AUTO_CLAIM="true"
_BALANCED_PROPOSAL_REQUIRED="false"
_BALANCED_RECEIPT_RETENTION_DAYS="30"
_BALANCED_COMMIT_SIGN_REQUIRED="false"
_BALANCED_MULTI_AGENT_WRITES="direct"

resolve_policy_knobs() {
  local sp="${SP:-${SPINE_ROOT:-${SPINE_CODE:-$HOME/code/agentic-spine}}}"
  local presets_file="$sp/ops/bindings/policy.presets.yaml"
  local preset_name=""
  local profile_path=""

  # ── Step 1: Determine preset name via discovery chain ──
  if [[ -n "${SPINE_POLICY_PRESET:-}" ]]; then
    preset_name="$SPINE_POLICY_PRESET"
  elif [[ -n "${SPINE_TENANT_PROFILE:-}" ]]; then
    profile_path="$SPINE_TENANT_PROFILE"
  elif [[ -f "$sp/ops/bindings/tenant.profile.yaml" ]]; then
    profile_path="$sp/ops/bindings/tenant.profile.yaml"
  fi

  # Extract preset name from profile if we have one
  if [[ -z "$preset_name" && -n "$profile_path" && -f "$profile_path" ]]; then
    if command -v yq >/dev/null 2>&1; then
      preset_name="$(yq e '.policy.preset // ""' "$profile_path" 2>/dev/null || true)"
    fi
  fi

  # Fall back to balanced
  if [[ -z "$preset_name" ]]; then
    preset_name="balanced"
  fi

  # ── Step 2: Read knob values from presets file ──
  local drift_gate_mode="$_BALANCED_DRIFT_GATE_MODE"
  local warn_policy="$_BALANCED_WARN_POLICY"
  local approval_default="$_BALANCED_APPROVAL_DEFAULT"
  local session_closeout_sla_hours="$_BALANCED_SESSION_CLOSEOUT_SLA_HOURS"
  local stale_ssot_max_days="$_BALANCED_STALE_SSOT_MAX_DAYS"
  local gap_auto_claim="$_BALANCED_GAP_AUTO_CLAIM"
  local proposal_required="$_BALANCED_PROPOSAL_REQUIRED"
  local receipt_retention_days="$_BALANCED_RECEIPT_RETENTION_DAYS"
  local commit_sign_required="$_BALANCED_COMMIT_SIGN_REQUIRED"
  local multi_agent_writes="$_BALANCED_MULTI_AGENT_WRITES"

  if [[ -f "$presets_file" ]] && command -v yq >/dev/null 2>&1; then
    local prefix=".presets.${preset_name}.knobs"
    local val

    val="$(yq e "${prefix}.drift_gate_mode // \"\"" "$presets_file" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && drift_gate_mode="$val"

    val="$(yq e "${prefix}.warn_policy // \"\"" "$presets_file" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && warn_policy="$val"

    val="$(yq e "${prefix}.approval_default // \"\"" "$presets_file" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && approval_default="$val"

    val="$(yq e "${prefix}.session_closeout_sla_hours // \"\"" "$presets_file" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && session_closeout_sla_hours="$val"

    val="$(yq e "${prefix}.stale_ssot_max_days // \"\"" "$presets_file" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && stale_ssot_max_days="$val"

    # Boolean knobs: use direct read (not //) since yq treats false as falsy
    val="$(yq e "${prefix}.gap_auto_claim" "$presets_file" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && gap_auto_claim="$val"

    val="$(yq e "${prefix}.proposal_required" "$presets_file" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && proposal_required="$val"

    val="$(yq e "${prefix}.receipt_retention_days // \"\"" "$presets_file" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && receipt_retention_days="$val"

    val="$(yq e "${prefix}.commit_sign_required" "$presets_file" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && commit_sign_required="$val"

    val="$(yq e "${prefix}.multi_agent_writes // \"\"" "$presets_file" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && multi_agent_writes="$val"
  fi

  # ── Step 3: Apply per-knob overrides from tenant profile ──
  if [[ -n "$profile_path" && -f "$profile_path" ]] && command -v yq >/dev/null 2>&1; then
    local val

    val="$(yq e '.policy.overrides.drift_gate_mode // ""' "$profile_path" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && drift_gate_mode="$val"

    val="$(yq e '.policy.overrides.warn_policy // ""' "$profile_path" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && warn_policy="$val"

    val="$(yq e '.policy.overrides.approval_default // ""' "$profile_path" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && approval_default="$val"

    val="$(yq e '.policy.overrides.session_closeout_sla_hours // ""' "$profile_path" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && session_closeout_sla_hours="$val"

    val="$(yq e '.policy.overrides.stale_ssot_max_days // ""' "$profile_path" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && stale_ssot_max_days="$val"

    # Boolean knobs: use direct read (not //) since yq treats false as falsy
    val="$(yq e '.policy.overrides.gap_auto_claim' "$profile_path" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && gap_auto_claim="$val"

    val="$(yq e '.policy.overrides.proposal_required' "$profile_path" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && proposal_required="$val"

    val="$(yq e '.policy.overrides.receipt_retention_days // ""' "$profile_path" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && receipt_retention_days="$val"

    val="$(yq e '.policy.overrides.commit_sign_required' "$profile_path" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && commit_sign_required="$val"

    val="$(yq e '.policy.overrides.multi_agent_writes // ""' "$profile_path" 2>/dev/null || true)"
    [[ -n "$val" && "$val" != "null" ]] && multi_agent_writes="$val"
  fi

  # ── Step 4: Export resolved values ──
  export RESOLVED_POLICY_PRESET="$preset_name"
  export RESOLVED_DRIFT_GATE_MODE="$drift_gate_mode"
  export RESOLVED_WARN_POLICY="$warn_policy"
  export RESOLVED_APPROVAL_DEFAULT="$approval_default"
  export RESOLVED_SESSION_CLOSEOUT_SLA_HOURS="$session_closeout_sla_hours"
  export RESOLVED_STALE_SSOT_MAX_DAYS="$stale_ssot_max_days"
  export RESOLVED_GAP_AUTO_CLAIM="$gap_auto_claim"
  export RESOLVED_PROPOSAL_REQUIRED="$proposal_required"
  export RESOLVED_RECEIPT_RETENTION_DAYS="$receipt_retention_days"
  export RESOLVED_COMMIT_SIGN_REQUIRED="$commit_sign_required"
  export RESOLVED_MULTI_AGENT_WRITES="$multi_agent_writes"
}
