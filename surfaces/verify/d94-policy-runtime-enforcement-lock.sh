#!/usr/bin/env bash
# TRIAGE: Policy runtime contract missing or incomplete — check ops/bindings/policy.runtime.contract.yaml
# D94: policy-runtime-enforcement-lock
# Enforces: policy runtime contract binding exists with all 11 knobs declared and enforcement status
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

CONTRACT="$ROOT/ops/bindings/policy.runtime.contract.yaml"
PRESETS="$ROOT/ops/bindings/policy.presets.yaml"
AUDIT_SCRIPT="$ROOT/ops/plugins/policy/bin/policy-runtime-audit"

command -v jq >/dev/null 2>&1 || { err "jq is required for D94 policy audit parsing"; echo "D94 FAIL: $ERRORS check(s) failed"; exit 1; }

# ── Check 1: Contract exists ──
if [[ ! -f "$CONTRACT" ]]; then
  err "policy.runtime.contract.yaml does not exist"
  echo "D94 FAIL: $ERRORS check(s) failed"
  exit 1
fi
ok "contract binding exists"

# ── Check 2: Version field present ──
if grep -q '^version:' "$CONTRACT"; then
  ok "version field present"
else
  err "version field missing from contract"
fi

# ── Check 3: All 11 policy knobs declared ──
REQUIRED_KNOBS=(
  drift_gate_mode
  approval_default
  session_closeout_sla_hours
  warn_policy
  stale_ssot_max_days
  gap_auto_claim
  proposal_required
  receipt_retention_days
  commit_sign_required
  multi_agent_writes
  multi_agent_writes_when_multi_session
)
for knob in "${REQUIRED_KNOBS[@]}"; do
  if grep -q "^  ${knob}:" "$CONTRACT"; then
    ok "knob $knob declared"
  else
    err "knob $knob not declared in contract"
  fi
done

# ── Check 4: Each knob has enforcement_point and wired status ──
for knob in "${REQUIRED_KNOBS[@]}"; do
  if grep -q "^  ${knob}:" "$CONTRACT"; then
    block="$(sed -n "/^  ${knob}:/,/^  [a-z]/p" "$CONTRACT" | head -20)"
    if echo "$block" | grep -q "enforcement_point:"; then
      ok "$knob has enforcement_point"
    else
      err "$knob missing enforcement_point"
    fi
    if echo "$block" | grep -q "wired:"; then
      ok "$knob has wired status"
    else
      err "$knob missing wired status"
    fi
  fi
done

# ── Check 5: Wired knobs reference valid source files ──
# Handle both string format (wired_in: "file") and list format (wired_in:\n  - "file")
# Scope to knobs section only (before enforcement:) to avoid matching enforcement checks
knobs_section="$(sed -n '/^knobs:/,/^enforcement:/p' "$CONTRACT")"
while IFS= read -r line; do
  if echo "$line" | grep -q '^ *- '; then
    # List entry: - "file"
    file_ref="$(echo "$line" | sed 's/.*- *"//' | sed 's/".*//')"
  elif echo "$line" | grep -q 'wired_in:.*"'; then
    # Inline string: wired_in: "file" or wired_in: "file (note)"
    file_ref="$(echo "$line" | sed 's/.*wired_in: *"//' | sed 's/".*//')"
  else
    continue
  fi
  # Strip any parenthetical suffix like " (D58 SSOT_FRESHNESS_DAYS)"
  file_ref="$(echo "$file_ref" | sed 's/ (.*//')"
  if [[ -n "$file_ref" && "$file_ref" != "null" ]]; then
    if [[ -f "$ROOT/$file_ref" ]]; then
      ok "wired_in reference valid: $file_ref"
    else
      err "wired_in reference invalid: $file_ref"
    fi
  fi
done < <(echo "$knobs_section" | grep -E '(wired_in:.*"|^ *- ")' | grep -v 'null')

# ── Check 6: Presets binding exists ──
if [[ -f "$PRESETS" ]]; then
  ok "policy.presets.yaml exists"
else
  err "policy.presets.yaml does not exist"
fi

# ── Check 7: Enforcement section present ──
if grep -q '^enforcement:' "$CONTRACT"; then
  ok "enforcement section present"
else
  err "enforcement section missing"
fi

# ── Check 8: Product doc exists ──
if [[ -f "$ROOT/docs/product/AOF_POLICY_RUNTIME_ENFORCEMENT.md" ]]; then
  ok "product doc exists"
else
  err "docs/product/AOF_POLICY_RUNTIME_ENFORCEMENT.md does not exist"
fi

# ── Check 9: Policy runtime audit trail is machine-verifiable ──
if [[ -x "$AUDIT_SCRIPT" ]]; then
  ok "policy.runtime.audit script exists"
  if audit_json="$("$AUDIT_SCRIPT" --json 2>/dev/null)"; then
    if jq -e '.status == "pass"' >/dev/null <<<"$audit_json"; then
      ok "policy.runtime.audit status is pass"
    else
      err "policy.runtime.audit did not report pass status"
    fi

    if jq -e '.summary.total_knobs == 11' >/dev/null <<<"$audit_json"; then
      ok "policy.runtime.audit reports 11 knobs"
    else
      err "policy.runtime.audit knob summary mismatch"
    fi

    if jq -e '.history.available == true' >/dev/null <<<"$audit_json"; then
      ok "policy.runtime.audit history backend available"
    else
      err "policy.runtime.audit history backend unavailable"
    fi

    if jq -e '.history.entry_count >= 1' >/dev/null <<<"$audit_json"; then
      ok "policy.runtime.audit has at least one history entry"
    else
      err "policy.runtime.audit history is empty"
    fi

    for tracked in \
      "ops/bindings/policy.presets.yaml" \
      "ops/bindings/tenant.profile.yaml" \
      "ops/bindings/policy.runtime.contract.yaml" \
      "ops/lib/resolve-policy.sh"; do
      if jq -e --arg tracked "$tracked" '.history.tracked_paths | index($tracked) != null' >/dev/null <<<"$audit_json"; then
        ok "policy.runtime.audit tracks $tracked"
      else
        err "policy.runtime.audit missing tracked path: $tracked"
      fi
    done
  else
    err "policy.runtime.audit --json failed"
  fi
else
  err "ops/plugins/policy/bin/policy-runtime-audit is not executable or missing"
fi

# ── Result ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D94 FAIL: $ERRORS check(s) failed"
  exit 1
fi
exit 0
