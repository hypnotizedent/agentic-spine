#!/usr/bin/env bash
# TRIAGE: enforce local-first watcher with paid-provider circuit breaker safeguards.
# Gate: D329 — watcher-paid-provider-circuit-breaker-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
WATCHER="$ROOT/ops/runtime/inbox/hot-folder-watcher.sh"
D74="$ROOT/surfaces/verify/d74-billing-provider-lane-lock.sh"

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

echo "D329: watcher-paid-provider-circuit-breaker-lock"
echo

if [[ ! -f "$WATCHER" ]]; then
  echo "status: FAIL (missing watcher script: $WATCHER)"
  exit 1
fi

if [[ ! -f "$D74" ]]; then
  echo "status: FAIL (missing D74 guard: $D74)"
  exit 1
fi

if rg -q 'WATCHER_PROVIDER="\$\{SPINE_WATCHER_PROVIDER:-local\}"' "$WATCHER"; then
  check "watcher defaults to local provider" "PASS"
else
  check "watcher defaults to local provider" "FAIL"
fi

if rg -q 'WATCHER_ALLOW_PAID_PROVIDER="\$\{SPINE_WATCHER_ALLOW_PAID_PROVIDER:-0\}"' "$WATCHER"; then
  check "watcher requires explicit paid-provider override" "PASS"
else
  check "watcher requires explicit paid-provider override" "FAIL"
fi

if rg -q 'WATCHER_PAID_CIRCUIT_TTL_SECONDS="\$\{SPINE_WATCHER_PAID_CIRCUIT_TTL_SECONDS:-21600\}"' "$WATCHER"; then
  check "watcher defines paid circuit TTL" "PASS"
else
  check "watcher defines paid circuit TTL" "FAIL"
fi

if rg -q 'CIRCUIT_OPEN_FILE="\$\{STATE_DIR\}/watcher-paid-provider\.circuit\.open"' "$WATCHER"; then
  check "watcher defines circuit state file path under runtime state" "PASS"
else
  check "watcher defines circuit state file path under runtime state" "FAIL"
fi

if rg -q 'open_paid_provider_circuit\(' "$WATCHER" \
  && rg -q 'paid_provider_circuit_open\(' "$WATCHER"; then
  check "watcher implements paid-provider circuit open/check functions" "PASS"
else
  check "watcher implements paid-provider circuit open/check functions" "FAIL"
fi

if rg -q 'DISPATCH_ERROR_CLASS="paid_provider_circuit_open"' "$WATCHER"; then
  check "dispatch marks paid-provider circuit-open error class" "PASS"
else
  check "dispatch marks paid-provider circuit-open error class" "FAIL"
fi

if rg -q 'target_lane="\$PARKED"' "$WATCHER"; then
  check "paid-provider circuit-open failures route to parked lane" "PASS"
else
  check "paid-provider circuit-open failures route to parked lane" "FAIL"
fi

if rg -q 'SPINE_WATCHER_ALLOW_PAID_PROVIDER=1' "$D74"; then
  check "D74 enforces explicit paid-provider override contract" "PASS"
else
  check "D74 enforces explicit paid-provider override contract" "FAIL"
fi

echo
echo "summary: ${pass}/${total} checks passed"
if [[ $fail -gt 0 ]]; then
  echo "status: FAIL"
  exit 1
fi
echo "status: PASS"
