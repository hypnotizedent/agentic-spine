#!/usr/bin/env bash
# posture-guard.sh — Shell enforcement library for execution posture contract.
#
# Source this file and call posture_guard_reject_growth before any mutation
# that would expand the registry (new gaps, new loops).
#
# Reads:
#   SPINE_EXECUTION_POSTURE  — active posture (discover|converge|degraded)
#   SPINE_POSTURE_OVERRIDE_REASON — break-glass override reason
#
# Returns 0 if growth is allowed, exits 1 if blocked.

posture_guard_reject_growth() {
  local caller="${1:-unknown}"
  local posture="${SPINE_EXECUTION_POSTURE:-discover}"
  local override_reason="${SPINE_POSTURE_OVERRIDE_REASON:-}"

  case "$posture" in
    discover|degraded|"")
      return 0
      ;;
    converge)
      if [[ -n "$override_reason" ]]; then
        echo "POSTURE OVERRIDE: converge guard bypassed for $caller" >&2
        echo "  reason: $override_reason" >&2
        return 0
      fi
      echo "POSTURE BLOCKED: Active execution posture is 'converge'." >&2
      echo "  Caller: $caller" >&2
      echo "  Registry growth (new gaps/loops) is denied." >&2
      echo "  Remediation:" >&2
      echo "    - Record observations in the session receipt instead" >&2
      echo "    - Or rerun with SPINE_EXECUTION_POSTURE=discover" >&2
      echo "    - Or set SPINE_POSTURE_OVERRIDE_REASON=\"<reason>\" for break-glass" >&2
      exit 1
      ;;
    *)
      echo "POSTURE WARN: unrecognized posture '$posture', treating as discover" >&2
      return 0
      ;;
  esac
}
