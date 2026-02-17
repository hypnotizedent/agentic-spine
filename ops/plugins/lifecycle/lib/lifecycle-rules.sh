# lifecycle-rules.sh — Read defaults from lifecycle.rules.yaml
#
# Exports helper functions for lifecycle rule values.
# Falls back to hardcoded defaults if SSOT is missing.
#
# Sourceable — no set -euo pipefail at top level.

_LIFECYCLE_RULES_FILE="${SP:-${SPINE_ROOT:-${SPINE_CODE:-$HOME/code/agentic-spine}}}/ops/bindings/lifecycle.rules.yaml"

_lc_read() {
  local path="$1" fallback="$2"
  if [[ -f "$_LIFECYCLE_RULES_FILE" ]] && command -v yq >/dev/null 2>&1; then
    local val
    val="$(yq e "$path" "$_LIFECYCLE_RULES_FILE" 2>/dev/null || true)"
    if [[ -n "$val" && "$val" != "null" ]]; then
      echo "$val"
      return
    fi
  fi
  echo "$fallback"
}

gap_quick_default_type()         { _lc_read '.rules.gap_quick.default_type' 'agent-behavior'; }
gap_quick_default_severity()     { _lc_read '.rules.gap_quick.default_severity' 'medium'; }
gap_quick_default_discovered_by() { _lc_read '.rules.gap_quick.default_discovered_by' 'agent-session'; }
aging_warning_days()             { _lc_read '.rules.aging.thresholds.warning_days' '7'; }
aging_critical_days()            { _lc_read '.rules.aging.thresholds.critical_days' '14'; }
loops_auto_close_enabled()       { _lc_read '.rules.loops_auto_close.enabled' 'true'; }
loops_auto_close_require_all()   { _lc_read '.rules.loops_auto_close.require_all_gaps_resolved' 'true'; }
loops_auto_close_skip_zero()     { _lc_read '.rules.loops_auto_close.skip_zero_gap_loops' 'true'; }
health_orphan_check()            { _lc_read '.rules.health.orphan_check' 'true'; }
health_aging_advisory()          { _lc_read '.rules.health.aging_advisory' 'true'; }
