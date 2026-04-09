#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# drift-gate.sh - Constitutional drift detector (v3.0)
# ═══════════════════════════════════════════════════════════════
#
# Enforces the Minimal Spine Constitution.
# Run after any change. Must pass before merge.
#
# Exit: 0 = PASS, 1 = FAIL
#
# Warning severity contract:
#   WARN_POLICY=advisory (default) — warnings reported, exit 0
#   WARN_POLICY=strict             — warnings escalate to FAIL (exit 1)
#
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

# Prefer BASH_SOURCE-relative resolution to avoid ambient SPINE_ROOT pollution.
_DG_COMPUTED="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -n "${SPINE_ROOT:-}" && "${SPINE_ROOT}" != "$_DG_COMPUTED" ]]; then
  echo "WARN: ambient SPINE_ROOT=$SPINE_ROOT disagrees with computed=$_DG_COMPUTED (using computed)" >&2
fi
SP="$_DG_COMPUTED"
RT="${SPINE_REPO:-$SP}"
cd "$SP"
source "$SP/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths
RECEIPTS_ROOT="${SPINE_RECEIPTS:-$HOME/code/.evidence/spine/sessions}"

# Resolve active policy preset (balanced defaults if unset)
source "$SP/ops/lib/resolve-policy.sh"
resolve_policy_knobs

# ── Retired gate skip (registry-driven) ──
# Build set of retired gate IDs at startup. Gates in this set are skipped entirely.
REGISTRY="$SP/ops/bindings/gate.registry.yaml"
TOPOLOGY="$SP/ops/bindings/gate.execution.topology.yaml"
RETIRED_GATES=" "
RETIRED_SKIP_COUNT=0
if [[ -f "$REGISTRY" ]] && command -v yq >/dev/null 2>&1; then
  while IFS= read -r gid; do
    [[ -n "$gid" && "$gid" != "null" ]] && RETIRED_GATES="${RETIRED_GATES}${gid} "
  done < <(yq e '.gates[] | select(.retired == true) | .id' "$REGISTRY" 2>/dev/null)
fi

is_retired() {
  [[ "$RETIRED_GATES" == *" $1 "* ]]
}

FAIL=0
WARN_COUNT=0
CURRENT_GATE=""
L1_FAIL_IDS=" "
L1_WARN_IDS=" "
L2_FAIL_IDS=" "
L2_WARN_IDS=" "
L3_FAIL_IDS=" "
L3_WARN_IDS=" "

append_gate_id() {
  local var_name="$1"
  local gate_id="$2"
  local current
  eval "current=\"\${$var_name}\""
  if [[ "$current" != *" $gate_id "* ]]; then
    eval "$var_name=\"${current}${gate_id} \""
  fi
}

remove_gate_id() {
  local var_name="$1"
  local gate_id="$2"
  local current
  eval "current=\"\${$var_name}\""
  current="${current// $gate_id / }"
  eval "$var_name=\"${current}\""
}

trim_gate_ids() {
  local values="$1"
  values="${values# }"
  values="${values% }"
  printf '%s\n' "${values// /, }"
}

resolve_gate_class() {
  local gate_id="$1"
  if [[ ! -f "$REGISTRY" ]] || ! command -v yq >/dev/null 2>&1; then
    return 0
  fi
  yq e -r ".gates[] | select(.id == \"$gate_id\") | .gate_class // \"\"" "$REGISTRY" 2>/dev/null || true
}

resolve_gate_layer() {
  local gate_id="$1"
  local layer="" primary_domain=""

  if [[ -f "$REGISTRY" ]] && command -v yq >/dev/null 2>&1; then
    layer="$(yq e -r ".gates[] | select(.id == \"$gate_id\") | .layer // \"\"" "$REGISTRY" 2>/dev/null || true)"
    if [[ -n "$layer" && "$layer" != "null" ]]; then
      printf '%s\n' "$layer"
      return 0
    fi
  fi

  if [[ -f "$TOPOLOGY" ]] && command -v yq >/dev/null 2>&1; then
    if yq e -r '.core_mode.core_gate_ids[]?' "$TOPOLOGY" 2>/dev/null | grep -qx "$gate_id"; then
      printf '%s\n' "L1_engine"
      return 0
    fi
    primary_domain="$(yq e -r ".gate_assignments[] | select(.gate_id == \"$gate_id\") | .primary_domain // \"\"" "$TOPOLOGY" 2>/dev/null || true)"
    if [[ -n "$primary_domain" && "$primary_domain" != "null" ]]; then
      layer="$(yq e -r ".domain_metadata[] | select(.domain_id == \"$primary_domain\") | .layer // \"\"" "$TOPOLOGY" 2>/dev/null || true)"
      if [[ -n "$layer" && "$layer" != "null" ]]; then
        printf '%s\n' "$layer"
        return 0
      fi
    fi
  fi

  printf '%s\n' "L2_shared_infrastructure"
}

record_gate_result() {
  local gate_id="$1"
  local severity="$2"
  local gate_class layer fail_var warn_var fail_ids

  [[ -n "$gate_id" ]] || return 0
  gate_class="$(resolve_gate_class "$gate_id")"
  if [[ "$severity" == "warn" && "$gate_class" == "advisory" ]]; then
    return 0
  fi
  layer="$(resolve_gate_layer "$gate_id")"
  case "$layer" in
    L1_engine)
      fail_var="L1_FAIL_IDS"
      warn_var="L1_WARN_IDS"
      ;;
    L3_product_runtime)
      fail_var="L3_FAIL_IDS"
      warn_var="L3_WARN_IDS"
      ;;
    *)
      fail_var="L2_FAIL_IDS"
      warn_var="L2_WARN_IDS"
      ;;
  esac

  eval "fail_ids=\"\${$fail_var}\""
  if [[ "$severity" == "fail" ]]; then
    append_gate_id "$fail_var" "$gate_id"
    remove_gate_id "$warn_var" "$gate_id"
    return 0
  fi

  if [[ "$fail_ids" != *" $gate_id "* ]]; then
    append_gate_id "$warn_var" "$gate_id"
  fi
}

resolve_gate_hold_posture() {
  local gate_id="$1"
  if [[ ! -f "$REGISTRY" ]] || ! command -v yq >/dev/null 2>&1; then
    return 0
  fi
  yq e -r ".gates[] | select(.id == \"$gate_id\") | .enforcement_decision.posture // \"\"" "$REGISTRY" 2>/dev/null || true
}

resolve_gate_hold_as_of() {
  local gate_id="$1"
  if [[ ! -f "$REGISTRY" ]] || ! command -v yq >/dev/null 2>&1; then
    return 0
  fi
  yq e -r ".gates[] | select(.id == \"$gate_id\") | .enforcement_decision.as_of // \"\"" "$REGISTRY" 2>/dev/null || true
}

print_layer_status() {
  local layer="$1"
  local fail_var warn_var fail_ids warn_ids

  case "$layer" in
    L1_engine)
      fail_var="L1_FAIL_IDS"
      warn_var="L1_WARN_IDS"
      ;;
    L2_shared_infrastructure)
      fail_var="L2_FAIL_IDS"
      warn_var="L2_WARN_IDS"
      ;;
    *)
      fail_var="L3_FAIL_IDS"
      warn_var="L3_WARN_IDS"
      ;;
  esac

  eval "fail_ids=\"\${$fail_var}\""
  eval "warn_ids=\"\${$warn_var}\""
  fail_ids="$(trim_gate_ids "$fail_ids")"
  warn_ids="$(trim_gate_ids "$warn_ids")"

  if [[ -n "$fail_ids" ]]; then
    echo "  $layer: RESIDUE (fail: $fail_ids)"
  elif [[ -n "$warn_ids" ]]; then
    echo "  $layer: RESIDUE (warn: $warn_ids)"
  else
    echo "  $layer: CLEAN"
  fi
}

pass(){ echo "PASS"; }
fail(){ echo "FAIL $*"; FAIL=1; record_gate_result "${CURRENT_GATE:-}" "fail"; }
warn(){ echo "WARN $*"; WARN_COUNT=$((WARN_COUNT + 1)); record_gate_result "${CURRENT_GATE:-}" "warn"; }

# ── AOF scoped gate enforcement (v0.2) ──
# When .environment.yaml exists, read the tier and only enforce gate categories
# declared for that tier in drift-gates.scoped.yaml. Out-of-scope gates downgrade to warn.
SCOPED_GATES="$SP/ops/bindings/drift-gates.scoped.yaml"
ENV_CONTRACT="$SP/.environment.yaml"
AOF_TIER=""
AOF_SCOPED=0
AOF_OUT_OF_SCOPE_GATES=""
AOF_FAIL_ACTION="block"

if [[ -f "$ENV_CONTRACT" && -f "$SCOPED_GATES" ]]; then
  AOF_TIER="$(yq -r '.environment.tier // ""' "$ENV_CONTRACT" 2>/dev/null || true)"
  if [[ -n "$AOF_TIER" ]]; then
    AOF_SCOPED=1
    # Read fail_action for this tier (block or warn)
    AOF_FAIL_ACTION="$(yq -r ".environment_tiers.$AOF_TIER.fail_action // \"block\"" "$SCOPED_GATES" 2>/dev/null || echo block)"
    # Pre-compute enforced categories for this tier
    _aof_enforced=""
    while IFS= read -r cat; do
      [[ -z "$cat" || "$cat" == "null" ]] && continue
      _aof_enforced="${_aof_enforced} ${cat} "
    done < <(yq -r ".environment_tiers.$AOF_TIER.enforce[]?" "$SCOPED_GATES" 2>/dev/null || true)
    # Pre-compute out-of-scope D-gates: gates in categories NOT in enforce list
    _all_cats="identity environment receipts services spine_core"
    for _cat in $_all_cats; do
      if [[ "$_aof_enforced" != *" $_cat "* ]]; then
        # This category is NOT enforced — collect its D-gates
        while IFS= read -r _gate; do
          [[ -z "$_gate" || "$_gate" == "null" ]] && continue
          AOF_OUT_OF_SCOPE_GATES="${AOF_OUT_OF_SCOPE_GATES} ${_gate} "
        done < <(yq -r ".gate_to_legacy_mapping.$_cat[]?" "$SCOPED_GATES" 2>/dev/null || true)
      fi
    done
  fi
fi

# Check if a D-gate is in scope for the current tier.
# Returns 0 (in scope / enforce), 1 (out of scope / downgrade to warn).
is_gate_in_scope() {
  [[ "$AOF_SCOPED" -eq 0 ]] && return 0
  local gate_id="$1"
  if [[ "$AOF_OUT_OF_SCOPE_GATES" == *" $gate_id "* ]]; then
    return 1
  fi
  return 0
}

DRIFT_VERBOSE="${DRIFT_VERBOSE:-0}"
WARN_POLICY="${WARN_POLICY:-$RESOLVED_WARN_POLICY}"

# Scope-aware fail: downgrade to warn when gate is out-of-scope or tier fail_action=warn.
scoped_fail() {
  local gate_id="$1"; shift
  if [[ "$AOF_FAIL_ACTION" == "warn" ]]; then
    warn "$* [downgraded by fail_action=warn for tier=$AOF_TIER]"
  elif is_gate_in_scope "$gate_id"; then
    fail "$@"
  else
    warn "$* [out-of-scope for tier=$AOF_TIER]"
  fi
}

gate_script() {
  local script="$1"
  local gate_id="${2:-}"
  local tmp rc

  # Auto-detect gate ID from script path (e.g., d16-docs-quarantine.sh → D16)
  if [[ -z "$gate_id" ]]; then
    local base
    base="$(basename "$script")"
    if [[ "$base" =~ ^d([0-9]+)- ]]; then
      gate_id="D${BASH_REMATCH[1]}"
    fi
  fi

  # Skip retired gates entirely
  if [[ -n "$gate_id" ]] && is_retired "$gate_id"; then
    echo "SKIP (retired)"
    RETIRED_SKIP_COUNT=$((RETIRED_SKIP_COUNT + 1))
    return 0
  fi

  tmp="$(mktemp)"
  set +e
  bash "$script" >"$tmp" 2>&1
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    pass
    # Preserve advisory WARN lines (if any), but drop PASS noise from scripts.
    if grep -q '^WARN' "$tmp" 2>/dev/null; then
      WARN_COUNT=$((WARN_COUNT + 1))
      record_gate_result "$gate_id" "warn"
      grep '^WARN' "$tmp" 2>/dev/null || true
    fi
  else
    local hold_posture hold_as_of
    hold_posture="$(resolve_gate_hold_posture "$gate_id")"
    hold_as_of="$(resolve_gate_hold_as_of "$gate_id")"
    if [[ "$hold_posture" == "hold_report_only" ]]; then
      warn "$(basename "$script") failed (rc=$rc) [governed hold${hold_as_of:+ as_of=$hold_as_of}]"
    elif [[ "${RESOLVED_DRIFT_GATE_MODE:-fail}" == "warn" ]]; then
      warn "$(basename "$script") failed (rc=$rc) [downgraded by drift_gate_mode=warn]"
    elif [[ "$AOF_FAIL_ACTION" == "warn" ]]; then
      warn "$(basename "$script") failed (rc=$rc) [downgraded by fail_action=warn for tier=$AOF_TIER]"
    elif [[ -n "$gate_id" ]] && ! is_gate_in_scope "$gate_id"; then
      warn "$(basename "$script") failed (rc=$rc) [out-of-scope for tier=$AOF_TIER]"
    else
      fail "$script failed (rc=$rc)"
    fi
    echo "  --- output (first 200 lines): $script ---"
    sed -n '1,200p' "$tmp" | sed 's/^/  /' || true
    echo "  --- end output ---"
    # Extract triage hint from gate script (P3: self-documenting gates)
    local triage
    triage="$(grep '^# TRIAGE:' "$script" 2>/dev/null | head -1 | sed 's/^# TRIAGE: *//' || true)"
    if [[ -n "$triage" ]]; then
      echo "  TRIAGE: $triage"
    fi
  fi

  rm -f "$tmp" 2>/dev/null || true
}

echo "=== DRIFT GATE (v3.0) ==="

# D1: Top-level directory policy
if ! is_retired D1; then
CURRENT_GATE="D1"
echo -n "D1 top-level dirs... "
EXTRA="$(ls -1d */ 2>/dev/null | rg -v '^(bin|docs|fixtures|ops|surfaces)/$' || true)"
if [[ -z "$EXTRA" ]]; then pass; else scoped_fail D1 "extra dirs: $(echo "$EXTRA" | tr '\n' ' ')"; fi
else echo "D1 top-level dirs... SKIP (retired)"; RETIRED_SKIP_COUNT=$((RETIRED_SKIP_COUNT + 1)); fi

# D2: No runs/ trace
if ! is_retired D2; then
CURRENT_GATE="D2"
echo -n "D2 one trace (no runs/)... "
if [[ ! -d runs ]]; then pass; else scoped_fail D2 "runs/ exists"; fi
else echo "D2 one trace (no runs/)... SKIP (retired)"; RETIRED_SKIP_COUNT=$((RETIRED_SKIP_COUNT + 1)); fi

# D3: Entrypoint smoke
# TRIAGE: bin/ops entrypoint smoke. Check bin/ops exists and is executable.
CURRENT_GATE="D3"
echo -n "D3 entrypoint smoke... "
if [[ -x "$SP/surfaces/verify/d3-entrypoint-smoke.sh" ]]; then
  gate_script "$SP/surfaces/verify/d3-entrypoint-smoke.sh" "D3"
else
  scoped_fail D3 "d3-entrypoint-smoke script missing"
fi

# D4: Watcher (launchd canonical; warn only, no fail)
if ! is_retired D4; then
CURRENT_GATE="D4"
echo -n "D4 watcher... "
WATCHER_PRINT="$(launchctl print "gui/$(id -u)/com.ronny.agent-inbox" 2>/dev/null || true)"
if [[ -n "$WATCHER_PRINT" ]]; then
  WATCHER_STATE="$(echo "$WATCHER_PRINT" | awk -F' = ' '/state =/{print $2; exit}')"
  WATCHER_PID="$(echo "$WATCHER_PRINT" | awk '/pid =/{print $3; exit}')"
  if [[ "$WATCHER_STATE" == "running" && -n "$WATCHER_PID" ]]; then
    pass
  else
    warn "(loaded but state=$WATCHER_STATE pid=${WATCHER_PID:-none})"
  fi
else
  WATCHER_INFO="$(launchctl list com.ronny.agent-inbox 2>/dev/null || true)"
  if [[ -n "$WATCHER_INFO" ]]; then
    WATCHER_PID="$(echo "$WATCHER_INFO" | sed -n 's/.*"PID" = \([0-9]*\).*/\1/p')"
    if [[ -n "$WATCHER_PID" ]]; then
      pass
    else
      warn "(loaded but no PID)"
    fi
  else
    warn "(launchd service not loaded)"
  fi
fi
else echo "D4 watcher... SKIP (retired)"; RETIRED_SKIP_COUNT=$((RETIRED_SKIP_COUNT + 1)); fi

# D5: No executable ~/agent coupling
if ! is_retired D5; then
CURRENT_GATE="D5"
echo -n "D5 no legacy coupling... "
COUPLE="$(rg -n '(\$HOME/agent|~/agent)' bin ops ops/plugins/core/agent/bin surfaces/verify 2>/dev/null \
  | rg -v '^[[:space:]]*#' \
  | rg -v 'foundation-gate.sh' \
  | rg -v 'drift-gate.sh' \
  | rg -v 'cloudflare-drift-gate.sh' \
  | rg -v 'github-actions-gate.sh' \
  | rg -v 'd18-docker-compose-drift.sh' \
  | rg -v 'd19-backup-drift.sh' \
  | rg -v 'd20-secrets-drift.sh' \
  | rg -v 'd22-nodes-drift.sh' \
  | rg -v 'd23-health-drift.sh' \
  | rg -v 'd24-github-labels-drift.sh' \
  | rg -v 'gate.registry.yaml' || true)"
if [[ -z "$COUPLE" ]]; then pass; else fail "legacy coupling found"; fi
else echo "D5 no legacy coupling... SKIP (retired)"; RETIRED_SKIP_COUNT=$((RETIRED_SKIP_COUNT + 1)); fi

# D6: Receipts exist (latest 5 have receipt.md)
if ! is_retired D6; then
CURRENT_GATE="D6"
echo -n "D6 receipts exist... "
MISSING=0
COUNT=0
for s in $(ls -1t "$RECEIPTS_ROOT" 2>/dev/null); do
  [[ -f "$RECEIPTS_ROOT/$s/receipt.md" ]] || MISSING=$((MISSING+1))
  COUNT=$((COUNT+1))
  [[ "$COUNT" -ge 5 ]] && break
done
if [[ "$MISSING" -eq 0 ]]; then pass; else scoped_fail D6 "$MISSING missing receipt.md"; fi
else echo "D6 receipts exist... SKIP (retired)"; RETIRED_SKIP_COUNT=$((RETIRED_SKIP_COUNT + 1)); fi

# D7: Executables only in four zones
if ! is_retired D7; then
CURRENT_GATE="D7"
echo -n "D7 executables bounded... "
BAD="$(find . -type f -name "*.sh" \
  | rg -v '^\./(bin/|ops/|surfaces/verify/)' \
  | rg -v '^\./(_imports/|docs/|mailroom/|\.git/|\.spine/|\.archive/|\.worktrees/)' || true)"
if [[ -z "$BAD" ]]; then pass; else scoped_fail D7 "out-of-bounds: $(echo "$BAD" | wc -l | tr -d ' ')"; fi
else echo "D7 executables bounded... SKIP (retired)"; RETIRED_SKIP_COUNT=$((RETIRED_SKIP_COUNT + 1)); fi

# D8: No backup clutter (recursive — .bak and fix_bak anywhere in live surfaces)
if ! is_retired D8; then
CURRENT_GATE="D8"
echo -n "D8 no backup clutter... "
BK="$(find bin ops -type f 2>/dev/null | rg '\.bak$|fix_bak' || true)"
if [[ -z "$BK" ]]; then pass; else fail "backup files in live surfaces: $(echo "$BK" | tr '\n' ' ')"; fi
else echo "D8 no backup clutter... SKIP (retired)"; RETIRED_SKIP_COUNT=$((RETIRED_SKIP_COUNT + 1)); fi

# D10: No spurious top-level logs (must be under mailroom/)
if ! is_retired D10; then
CURRENT_GATE="D10"
echo -n "D10 logs under mailroom... "
if [[ -d "$SP/logs" ]]; then
  fail "spurious \$SPINE/logs exists (should be mailroom/logs)"
else
  pass
fi
else echo "D10 logs under mailroom... SKIP (retired)"; RETIRED_SKIP_COUNT=$((RETIRED_SKIP_COUNT + 1)); fi

# D11: ~/agent must be symlink to mailroom (if exists)
if ! is_retired D11; then
CURRENT_GATE="D11"
echo -n "D11 home surface... "
if [[ -e "$HOME/agent" ]]; then
  if [[ -L "$HOME/agent" ]]; then
    TARGET="$(readlink "$HOME/agent")"
    if [[ "$TARGET" == *"agentic-spine/mailroom"* ]]; then
      pass
    else
      fail "~/agent symlink points to wrong target: $TARGET"
    fi
  else
    fail "~/agent is a directory (should be symlink to mailroom)"
  fi
else
  pass
fi
else echo "D11 home surface... SKIP (retired)"; RETIRED_SKIP_COUNT=$((RETIRED_SKIP_COUNT + 1)); fi

# D12: CORE_LOCK.md must exist (repo validity marker)
if ! is_retired D12; then
CURRENT_GATE="D12"
echo -n "D12 core lock exists... "
if [[ -f "$SP/docs/core/CORE_LOCK.md" ]]; then pass; else scoped_fail D12 "docs/core/CORE_LOCK.md missing"; fi
else echo "D12 core lock exists... SKIP (retired)"; RETIRED_SKIP_COUNT=$((RETIRED_SKIP_COUNT + 1)); fi

# D9: Receipt stamps (STRICT - required fields for all new receipts)
if ! is_retired D9; then
CURRENT_GATE="D9"
echo -n "D9 receipt stamps... "
LATEST=""
for s in $(ls -1t "$RECEIPTS_ROOT" 2>/dev/null); do
  LATEST="$s"
  break
done
if [[ -n "$LATEST" ]] && [[ -f "$RECEIPTS_ROOT/$LATEST/receipt.md" ]]; then
  STAMP_FILE="$RECEIPTS_ROOT/$LATEST/receipt.md"

  # Check for required fields (core-v1.0 contract)
  HAS_RUN_ID=$(rg -q "Run ID" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_GENERATED=$(rg -q "Generated" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_STATUS=$(rg -q "Status" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_MODEL=$(rg -q "Model" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_INPUTS=$(rg -q "Inputs" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_OUTPUTS=$(rg -q "Outputs" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)

  MISSING=""
  [[ "$HAS_RUN_ID" == "0" ]] && MISSING+="Run_ID "
  [[ "$HAS_GENERATED" == "0" ]] && MISSING+="Generated "
  [[ "$HAS_STATUS" == "0" ]] && MISSING+="Status "
  [[ "$HAS_MODEL" == "0" ]] && MISSING+="Model "
  [[ "$HAS_INPUTS" == "0" ]] && MISSING+="Inputs "
  [[ "$HAS_OUTPUTS" == "0" ]] && MISSING+="Outputs "

  if [[ -z "$MISSING" ]]; then
    pass
  else
    fail "latest receipt missing: $MISSING"
    echo "  TRIAGE: Latest receipt missing fields: $MISSING. Check ops/cap.sh receipt template."
  fi
else
  warn "no receipts to check"
fi
else echo "D9 receipt stamps... SKIP (retired)"; RETIRED_SKIP_COUNT=$((RETIRED_SKIP_COUNT + 1)); fi

# D13: API capability secrets preconditions (locked rule)
CURRENT_GATE="D13"
echo -n "D13 api capability preconditions... "
if [[ -x "$SP/surfaces/verify/api-preconditions.sh" ]]; then
  gate_script "$SP/surfaces/verify/api-preconditions.sh" "D13"
else
  warn "api-preconditions verifier not present"
fi
CURRENT_GATE="D19"
echo -n "D19 backup drift gate... "
if [[ -x "$SP/surfaces/verify/d19-backup-drift.sh" ]]; then
  gate_script "$SP/surfaces/verify/d19-backup-drift.sh"
else
  warn "backup drift gate not present"
fi

# D20 / D55: Secrets readiness (verbose runs subchecks; default runs composite)
if [[ "${DRIFT_VERBOSE}" == "1" ]]; then
  CURRENT_GATE="D20"
  echo -n "D20 secrets drift gate... "
  if [[ -x "$SP/surfaces/verify/d20-secrets-drift.sh" ]]; then
    gate_script "$SP/surfaces/verify/d20-secrets-drift.sh"
  else
    warn "secrets drift gate not present"
  fi
else
  CURRENT_GATE="D55"
  echo -n "D55 secrets runtime readiness lock... "
  if [[ -x "$SP/surfaces/verify/d55-secrets-runtime-readiness-lock.sh" ]]; then
    gate_script "$SP/surfaces/verify/d55-secrets-runtime-readiness-lock.sh"
  else
    warn "secrets runtime readiness lock gate not present"
  fi
fi

# D25: Secrets CLI canonical lock (verbose only; default runs via D55 composite)
if [[ "${DRIFT_VERBOSE}" == "1" ]]; then
  CURRENT_GATE="D25"
  echo -n "D25 secrets cli canonical lock... "
  if [[ -x "$SP/surfaces/verify/d25-secrets-cli-canonical-lock.sh" ]]; then
    gate_script "$SP/surfaces/verify/d25-secrets-cli-canonical-lock.sh"
  else
    warn "secrets cli canonical lock gate not present"
  fi
fi

# D34: Loop ledger integrity lock (summary must match deduped counts)
CURRENT_GATE="D34"
echo -n "D34 loop ledger integrity lock... "
if [[ -x "$SP/surfaces/verify/d34-loop-ledger-integrity-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d34-loop-ledger-integrity-lock.sh" "D34"
else
  warn "loop ledger integrity lock gate not present"
fi

# D35: Infra relocation parity lock (cross-SSOT consistency for service moves)
CURRENT_GATE="D35"
echo -n "D35 infra relocation parity lock... "
if [[ -x "$SP/surfaces/verify/d35-infra-relocation-parity-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d35-infra-relocation-parity-lock.sh"
else
  warn "infra relocation parity lock gate not present"
fi
CURRENT_GATE="D43"
echo -n "D43 secrets namespace lock... "
if [[ -x "$SP/surfaces/verify/d43-secrets-namespace-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d43-secrets-namespace-lock.sh"
else
  warn "secrets namespace lock gate not present"
fi
CURRENT_GATE="D54"
echo -n "D54 ssot ip parity lock... "
if [[ -x "$SP/surfaces/verify/d54-ssot-ip-parity-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d54-ssot-ip-parity-lock.sh" "D54"
else
  warn "ssot ip parity lock gate not present"
fi

# D58: SSOT freshness lock (last_reviewed date enforcement)
# Wire stale_ssot_max_days from policy preset (env var override still takes precedence)
export SSOT_FRESHNESS_DAYS="${SSOT_FRESHNESS_DAYS:-$RESOLVED_STALE_SSOT_MAX_DAYS}"

# D62 is publication-only and intentionally excluded from operational drift-gate.
# Use surfaces/verify/d62-git-remote-parity-lock.sh during explicit publication review.

# D63: Capabilities metadata lock (registry integrity)
CURRENT_GATE="D63"
echo -n "D63 capabilities metadata lock... "
if [[ -x "$SP/surfaces/verify/d63-capabilities-metadata-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d63-capabilities-metadata-lock.sh" "D63"
else
  warn "capabilities metadata lock gate not present"
fi
CURRENT_GATE="D69"
echo -n "D69 VM creation governance lock... "
if [[ -x "$SP/surfaces/verify/d69-vm-creation-governance-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d69-vm-creation-governance-lock.sh"
else
  warn "VM creation governance lock gate not present"
fi
CURRENT_GATE="D75"
echo -n "D75 gap registry mutation lock... "
if [[ -x "$SP/surfaces/verify/d75-gap-registry-mutation-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d75-gap-registry-mutation-lock.sh"
else
  warn "Gap registry mutation lock gate not present"
fi
CURRENT_GATE="D88"
echo -n "D88 RAG remote reindex governance lock... "
if [[ -x "$SP/surfaces/verify/d88-rag-remote-reindex-governance-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d88-rag-remote-reindex-governance-lock.sh"
else
  warn "RAG remote reindex governance lock gate not present"
fi
CURRENT_GATE="D91"
echo -n "D91 AOF product foundation lock... "
if [[ -x "$SP/surfaces/verify/d91-aof-product-foundation-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d91-aof-product-foundation-lock.sh"
else
  warn "AOF product foundation lock gate not present"
fi

# D92: HA config version control
CURRENT_GATE="D92"
echo -n "D92 HA config version control... "
if [[ -x "$SP/surfaces/verify/d92-ha-config-version-control.sh" ]]; then
  gate_script "$SP/surfaces/verify/d92-ha-config-version-control.sh"
else
  warn "HA config version control gate not present"
fi

# D93: Tenant storage boundary lock
CURRENT_GATE="D93"
echo -n "D93 tenant storage boundary lock... "
if [[ -x "$SP/surfaces/verify/d93-tenant-storage-boundary-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d93-tenant-storage-boundary-lock.sh"
else
  warn "tenant storage boundary lock gate not present"
fi
CURRENT_GATE="D98"
echo -n "D98 Z2M device parity... "
if [[ -x "$SP/surfaces/verify/d98-z2m-device-parity.sh" ]]; then
  gate_script "$SP/surfaces/verify/d98-z2m-device-parity.sh"
else
  warn "Z2M device parity gate not present"
fi
CURRENT_GATE="D100"
echo -n "D100 VM IP parity lock... "
if [[ -x "$SP/surfaces/verify/d100-vm-ip-parity-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d100-vm-ip-parity-lock.sh"
else
  warn "VM IP parity gate not present"
fi

# D101: HA addon inventory parity
CURRENT_GATE="D101"
echo -n "D101 HA addon inventory parity... "
if [[ -x "$SP/surfaces/verify/d101-ha-addon-inventory-parity.sh" ]]; then
  gate_script "$SP/surfaces/verify/d101-ha-addon-inventory-parity.sh"
else
  warn "HA addon inventory gate not present"
fi
CURRENT_GATE="D106"
echo -n "D106 Media port collision lock... "
if [[ -x "$SP/surfaces/verify/d106-media-port-collision-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d106-media-port-collision-lock.sh"
else
  warn "Media port collision lock gate not present"
fi

CURRENT_GATE="D107"
echo -n "D107 Media NFS mount lock... "
if [[ -x "$SP/surfaces/verify/d107-media-nfs-mount-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d107-media-nfs-mount-lock.sh"
else
  warn "Media NFS mount lock gate not present"
fi
CURRENT_GATE="D116"
echo -n "D116 Mailroom bridge consumers registry... "
if [[ -x "$SP/surfaces/verify/d116-mailroom-bridge-consumers-registry-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d116-mailroom-bridge-consumers-registry-lock.sh" "D116"
else
  warn "mailroom bridge consumers registry gate not present"
fi
CURRENT_GATE="D121"
echo -n "D121 Fabric boundary lock... "
if [[ -x "$SP/surfaces/verify/d121-fabric-boundary-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d121-fabric-boundary-lock.sh" "D121"
else
  warn "fabric boundary lock gate not present"
fi
CURRENT_GATE="D124"
echo -n "D124 Entry surface parity lock... "
if [[ -x "$SP/surfaces/verify/d124-entry-surface-parity-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d124-entry-surface-parity-lock.sh" "D124"
else
  warn "entry surface parity lock gate not present"
fi
CURRENT_GATE="D126"
echo -n "D126 Workbench implementation path lock... "
if [[ -x "$SP/surfaces/verify/d126-workbench-implementation-path-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d126-workbench-implementation-path-lock.sh" "D126"
else
  warn "workbench implementation path lock gate not present"
fi

CURRENT_GATE="D127"
echo -n "D127 Domain assignment drift lock... "
if [[ -x "$SP/surfaces/verify/d127-domain-assignment-drift-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d127-domain-assignment-drift-lock.sh" "D127"
else
  warn "domain assignment drift lock gate not present"
fi
CURRENT_GATE="D398"
echo -n "D398 Repo-local evidence write target lock... "
if [[ -x "$SP/surfaces/verify/d398-repo-local-evidence-write-target-lock.sh" ]]; then
  gate_script "$SP/surfaces/verify/d398-repo-local-evidence-write-target-lock.sh" "D398"
else
  warn "repo-local evidence write target lock gate not present"
fi

echo
if [[ "$WARN_POLICY" == "strict" && "$WARN_COUNT" -gt 0 ]]; then
  FAIL=1
fi
echo "LAYER SUMMARY:"
print_layer_status "L1_engine"
print_layer_status "L2_shared_infrastructure"
print_layer_status "L3_product_runtime"
echo
if [[ "$FAIL" -eq 0 ]]; then
  if [[ "$WARN_COUNT" -gt 0 ]]; then
    echo "DRIFT GATE: PASS ($WARN_COUNT warning(s) — review WARN lines above)"
  else
    echo "DRIFT GATE: PASS"
  fi
else
  echo "DRIFT GATE: FAIL"
fi
if [[ "$WARN_COUNT" -gt 0 ]]; then
  echo "  WARNINGS: $WARN_COUNT gate(s) reported warnings (policy=$WARN_POLICY)"
fi
if [[ "$RETIRED_SKIP_COUNT" -gt 0 ]]; then
  echo "  RETIRED: $RETIRED_SKIP_COUNT gate(s) skipped (registry-driven)"
fi
exit "$FAIL"
