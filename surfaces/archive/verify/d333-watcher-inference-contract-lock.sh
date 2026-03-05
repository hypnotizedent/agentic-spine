#!/usr/bin/env bash
# TRIAGE: enforce self-hosted watcher inference contract completeness and cross-reference parity.
# Gate: D333 — watcher-inference-contract-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/mailroom.watcher.inference.contract.yaml"
RUNBOOK="$ROOT/docs/governance/MAILROOM_WATCHER_INFERENCE_RUNBOOK.md"
WATCHER="$ROOT/ops/runtime/inbox/hot-folder-watcher.sh"

fail=0
pass=0
total=0

check() {
  local label="$1"
  local result="$2"
  total=$((total + 1))
  if [[ "$result" == "PASS" ]]; then
    echo "  PASS: $label"
    pass=$((pass + 1))
  else
    echo "  FAIL: $label"
    fail=$((fail + 1))
  fi
}

echo "D333: watcher-inference-contract-lock"
echo

# 1. Contract file exists
if [[ -f "$CONTRACT" ]]; then
  check "inference contract exists" "PASS"
else
  check "inference contract exists" "FAIL"
  echo "status: FAIL (missing: $CONTRACT)"
  exit 1
fi

# 2. Runbook exists
if [[ -f "$RUNBOOK" ]]; then
  check "inference runbook exists" "PASS"
else
  check "inference runbook exists" "FAIL"
fi

# 3. Contract has provider_mode enum with all three values
if yq -e '.provider_mode.enum' "$CONTRACT" | rg -q 'local_default' \
  && yq -e '.provider_mode.enum' "$CONTRACT" | rq -q 'zero_llm' 2>/dev/null \
  || rg -q 'zero_llm' "$CONTRACT"; then
  if rg -q 'local_default' "$CONTRACT" \
    && rg -q 'zero_llm' "$CONTRACT" \
    && rg -q 'paid_fallback' "$CONTRACT"; then
    check "provider_mode enum has all three values" "PASS"
  else
    check "provider_mode enum has all three values" "FAIL"
  fi
else
  check "provider_mode enum has all three values" "FAIL"
fi

# 4. Contract has circuit breaker policy
if rg -q 'paid_provider_circuit_breaker:' "$CONTRACT"; then
  check "circuit breaker policy defined" "PASS"
else
  check "circuit breaker policy defined" "FAIL"
fi

# 5. Contract has budget guardrails
if rg -q 'budget_guardrails:' "$CONTRACT" \
  && rg -q 'monthly_paid_api_ceiling_usd' "$CONTRACT"; then
  check "budget guardrails with monthly ceiling defined" "PASS"
else
  check "budget guardrails with monthly ceiling defined" "FAIL"
fi

# 6. Contract has hardware profile tiers
if rg -q 'hardware_profiles:' "$CONTRACT" \
  && rg -q 'tier_minimal' "$CONTRACT" \
  && rg -q 'tier_dedicated_gpu' "$CONTRACT"; then
  check "hardware profile tiers defined" "PASS"
else
  check "hardware profile tiers defined" "FAIL"
fi

# 7. Contract has SLO acceptance criteria
if rg -q 'slo:' "$CONTRACT" \
  && rg -q 'latency:' "$CONTRACT" \
  && rg -q 'availability:' "$CONTRACT"; then
  check "SLO acceptance criteria defined" "PASS"
else
  check "SLO acceptance criteria defined" "FAIL"
fi

# 8. Contract has migration phases
if rg -q 'migration:' "$CONTRACT" \
  && rg -q 'phase_0_baseline' "$CONTRACT" \
  && rg -q 'phase_1_local_only' "$CONTRACT" \
  && rg -q 'phase_2_zero_cost' "$CONTRACT"; then
  check "migration phases (0/1/2) defined" "PASS"
else
  check "migration phases (0/1/2) defined" "FAIL"
fi

# 9. Contract has rollback policy
if rg -q 'rollback:' "$CONTRACT" \
  && rg -q 'trigger_conditions:' "$CONTRACT" \
  && rg -q 'max_rollback_time_minutes' "$CONTRACT"; then
  check "rollback policy with trigger conditions defined" "PASS"
else
  check "rollback policy with trigger conditions defined" "FAIL"
fi

# 10. Contract references watcher script
if rg -q 'hot-folder-watcher.sh' "$CONTRACT"; then
  check "contract references watcher script" "PASS"
else
  check "contract references watcher script" "FAIL"
fi

# 11. Contract references D329 (circuit breaker gate)
if rg -q 'D329' "$CONTRACT"; then
  check "contract references D329 circuit breaker gate" "PASS"
else
  check "contract references D329 circuit breaker gate" "FAIL"
fi

# 12. Runbook has rollout checklist
if rg -q 'Rollout Checklist' "$RUNBOOK"; then
  check "runbook has rollout checklist" "PASS"
else
  check "runbook has rollout checklist" "FAIL"
fi

# 13. Runbook has rollback checklist
if rg -q 'Rollback Checklist' "$RUNBOOK"; then
  check "runbook has rollback checklist" "PASS"
else
  check "runbook has rollback checklist" "FAIL"
fi

# 14. Runbook has break-glass procedure
if rg -q 'Break-Glass' "$RUNBOOK"; then
  check "runbook has break-glass procedure" "PASS"
else
  check "runbook has break-glass procedure" "FAIL"
fi

echo
echo "summary: ${pass}/${total} checks passed"
if [[ $fail -gt 0 ]]; then
  echo "status: FAIL"
  exit 1
fi
echo "status: PASS"
