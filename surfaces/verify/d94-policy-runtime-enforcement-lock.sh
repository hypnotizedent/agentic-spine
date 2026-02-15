#!/usr/bin/env bash
# TRIAGE: Policy runtime contract missing or incomplete — check ops/bindings/policy.runtime.contract.yaml
# D94: policy-runtime-enforcement-lock
# Enforces: policy runtime contract binding exists with all 10 knobs declared and enforcement status
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

CONTRACT="$ROOT/ops/bindings/policy.runtime.contract.yaml"
PRESETS="$ROOT/ops/bindings/policy.presets.yaml"

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

# ── Check 3: All 10 policy knobs declared ──
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
while IFS= read -r line; do
  file_ref="$(echo "$line" | sed 's/.*wired_in: *"//' | sed 's/".*//' | sed 's/ .*//')"
  if [[ -n "$file_ref" && "$file_ref" != "null" ]]; then
    if [[ -f "$ROOT/$file_ref" ]]; then
      ok "wired_in reference valid: $file_ref"
    else
      err "wired_in reference invalid: $file_ref"
    fi
  fi
done < <(grep 'wired_in:' "$CONTRACT" | grep -v 'null')

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

# ── Result ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D94 FAIL: $ERRORS check(s) failed"
  exit 1
fi
exit 0
