#!/usr/bin/env bash
# foundation-gate.sh - Foundation regression gate (fail-proof)
# Usage: ./foundation-gate.sh [--watcher-warn|--watcher-fail]
#
# Tier 0 gate: All checks must pass or script exits
# Exit status: 0 = PASS, 1 = FAIL

set -euo pipefail

SP="${SPINE_ROOT:-$HOME/Code/agentic-spine}"
cd "$SP"

# Result functions
fail() { echo "FAIL: $*"; exit 1; }
warn() { echo "WARN: $*"; }

START=$(date +%s)

echo "=== SPINE FOUNDATION GATE ==="

# T0: Entrypoints
echo "T0: Entrypoints"
test -x ./bin/ops && echo "OK: bin/ops" || fail "bin/ops missing/not executable"
if test -x ./cli/bin/spine; then 
  echo "OK: cli/bin/spine"
else
  warn "cli/bin/spine missing"
fi

# T1: Dispatch
echo "T1: Dispatch"
./bin/ops preflight >/dev/null && echo "OK: ops preflight" || fail "ops preflight failed"

# T2: Watcher targets spine mailroom
echo "T2: Watcher targets spine mailroom"
if pgrep -fl "fswatch.*agentic-spine/mailroom/inbox/queued" >/dev/null; then 
  echo "OK: watcher ok"
else
  if [[ "${SPINE_GATE_WATCHER:-fail}" == "warn" ]]; then
    warn "watcher not detected (set SPINE_GATE_WATCHER=warn to allow)"
  else
    fail "watcher not detected (set SPINE_GATE_WATCHER=warn to allow)"
  fi
fi

# T3: No executable legacy ~/agent coupling in runnable areas
echo "T3: No legacy ~/agent coupling in runnable code"
if rg -n '(\$HOME/agent|~/agent)' bin ops agents/active surfaces cli \
  | rg -v '^[[:space:]]*#' | rg -v 'foundation-gate.sh' >/dev/null; then
  echo "Executable legacy coupling found:"
  rg -n '(\$HOME/agent|~/agent)' bin ops agents/active surfaces cli | rg -v '^[[:space:]]*#' | rg -v 'foundation-gate.sh'
  exit 1
else
  echo "OK: no executable legacy coupling"
fi

# T4: Receipts canon (latest 5 must have receipt.md)
echo "T4: Receipts canon (latest 5)"
LATEST_FIVE=$(ls -1t receipts/sessions 2>/dev/null | head -n 5 || true)
FOUND=0
for s in $LATEST_FIVE; do
  [[ "$s" != "" ]] || continue
  test -f "receipts/sessions/$s/receipt.md" || fail "$s missing receipt.md"
  FOUND=1
done
[[ $FOUND -eq 0 ]] && fail "no receipts/sessions entries found"
echo "OK: latest 5 sessions all have receipt.md"

# T5: Kernel contracts (authoritative docs must exist)
echo "T5: Kernel contracts"
bash "$SP/surfaces/verify/contracts-gate.sh" || fail "contracts-gate failed"

# T6: Verify surfaces capability
echo "T6: Verify surfaces capability"
./bin/ops verify >/dev/null && echo "OK: ops verify" || fail "ops verify failed"

END=$(date +%s)
ELAPSED=$((END - START))

echo
echo "=== SUMMARY ==="
echo "Time elapsed: ${ELAPSED}s (must be < 60s)"
[[ "$ELAPSED" -lt 60 ]] || fail "gate exceeded 60s"
echo "All tiers: PASS"
echo "Foundation gate: GREEN - safe to proceed with work"

# T6: no drift roots under HOME
bash "$SP/surfaces/verify/no-drift-roots-gate.sh" || fail "no-drift-roots gate failed"
