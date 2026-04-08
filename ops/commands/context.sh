#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops context - Read-only L1 visibility surface for fresh terminals
# ═══════════════════════════════════════════════════════════════════════════
#
# Runs spine-engine-joined-state and prints a one-screen summary of
# terminal identity, runtime paths, open work, verify status, and
# engine coherence.
#
# This is informational only. It does not mutate state, attach loops,
# or dispatch work. If joined-state fails, this command prints a
# degraded notice and exits 0 so terminal birth is never blocked.
#
# Usage:
#   ops context
#
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JOINED_STATE_BIN="$SPINE_ROOT/ops/plugins/core/lifecycle/bin/spine-engine-joined-state"

# ── Collect identity from environment ─────────────────────────────────────
TERMINAL_ROLE="${OPS_TERMINAL_ROLE:-<none>}"
RUNTIME_ROLE="${SPINE_RUNTIME_ROLE:-<none>}"
LOOP_ID="${SPINE_LOOP_ID:-<none>}"

# ── Run joined-state (best-effort) ───────────────────────────────────────
JOINED_JSON=""
JOINED_ERR=""
if [[ -x "$JOINED_STATE_BIN" ]] || [[ -f "$JOINED_STATE_BIN" ]]; then
  JOINED_JSON="$(python3 "$JOINED_STATE_BIN" --json --no-write 2>/dev/null)" || {
    JOINED_ERR="joined-state failed (exit $?)"
    JOINED_JSON=""
  }
else
  JOINED_ERR="joined-state binary not found"
fi

# ── Extract fields from JSON ─────────────────────────────────────────────
jq_val() {
  local expr="$1"
  local default="${2:-}"
  if [[ -n "$JOINED_JSON" ]] && command -v jq >/dev/null 2>&1; then
    local val
    val="$(printf '%s' "$JOINED_JSON" | jq -r "if $expr == null then \"__null__\" else ($expr | tostring) end" 2>/dev/null || true)"
    if [[ -n "$val" && "$val" != "__null__" ]]; then
      printf '%s' "$val"
      return
    fi
  fi
  printf '%s' "$default"
}

STATE_ROOT="$(jq_val '.paths.state_root' 'unknown')"
EVIDENCE_ROOT="$(jq_val '.paths.receipts_root' 'unknown')"
OPEN_LOOPS="$(jq_val '.summary.open_loops' '?')"
OPEN_GAPS="$(jq_val '.summary.open_gaps' '?')"
ACTIVE_WAVES="$(jq_val '.summary.active_waves' '?')"
VERIFY_STATUS="$(jq_val '.summary.latest_fast_verify_status' 'unknown')"
GAP_AUTHORITY="$(jq_val '.summary.gap_authority_status' 'unknown')"
GAP_MATCH="$(jq_val '.summary.gap_projection_match' 'unknown')"
COHERENCE="$(jq_val '.summary.engine_coherence_needs_attention' 'unknown')"
FORCE_CLOSES="$(jq_val '.summary.recent_force_closes' '?')"
DOD_OVERRIDES="$(jq_val '.summary.recent_dod_overrides' '?')"

# ── Build warning line ───────────────────────────────────────────────────
WARNINGS=""
if [[ -n "$JOINED_ERR" ]]; then
  WARNINGS="$JOINED_ERR"
elif [[ "$COHERENCE" == "true" ]]; then
  W_PARTS=()
  [[ "$ACTIVE_WAVES" == "0" || "$ACTIVE_WAVES" == "?" ]] || W_PARTS+=("${ACTIVE_WAVES} active waves")
  [[ "$GAP_MATCH" == "true" || "$GAP_MATCH" == "unknown" ]] || W_PARTS+=("gap projection mismatch")
  [[ "$FORCE_CLOSES" == "0" || "$FORCE_CLOSES" == "?" ]] || W_PARTS+=("${FORCE_CLOSES} recent force-closes")
  [[ "$DOD_OVERRIDES" == "0" || "$DOD_OVERRIDES" == "?" ]] || W_PARTS+=("${DOD_OVERRIDES} recent DoD overrides")
  if [[ ${#W_PARTS[@]} -gt 0 ]]; then
    WARNINGS="$(printf '%s' "${W_PARTS[0]}"; for w in "${W_PARTS[@]:1}"; do printf ', %s' "$w"; done)"
  else
    WARNINGS="engine coherence needs attention"
  fi
fi

# ── Print ────────────────────────────────────────────────────────────────
echo "─── spine context ───────────────────────────────────"
printf "  terminal:       %s\n" "$TERMINAL_ROLE"
printf "  runtime role:   %s\n" "$RUNTIME_ROLE"
printf "  loop:           %s\n" "$LOOP_ID"
printf "  state root:     %s\n" "$STATE_ROOT"
printf "  evidence root:  %s\n" "$EVIDENCE_ROOT"
echo "─── open work ──────────────────────────────────────"
printf "  open loops:     %s\n" "$OPEN_LOOPS"
printf "  open gaps:      %s\n" "$OPEN_GAPS"
printf "  active waves:   %s\n" "$ACTIVE_WAVES"
echo "─── verify / coherence ─────────────────────────────"
printf "  fast verify:    %s\n" "$VERIFY_STATUS"
printf "  gap authority:  %s\n" "$GAP_AUTHORITY"
printf "  gap parity:     %s\n" "$(case "$GAP_MATCH" in true) echo "match";; false) echo "MISMATCH";; *) echo "unknown";; esac)"
printf "  coherence:      %s\n" "$([ "$COHERENCE" == "true" ] && echo "NEEDS ATTENTION" || echo "ok")"
if [[ -n "$WARNINGS" ]]; then
  echo "─── warning ────────────────────────────────────────"
  printf "  %s\n" "$WARNINGS"
fi
echo "─────────────────────────────────────────────────────"
