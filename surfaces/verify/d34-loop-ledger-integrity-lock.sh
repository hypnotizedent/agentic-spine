#!/usr/bin/env bash
set -euo pipefail

# D34: Loop Ledger Integrity Lock
# Purpose: Ensure loop summary counts match deduped reducer output.
#          Prevents regression to raw append-only counting behavior.
#
# Fails on:
#   - Mismatch between reducer --counts open and loops summary Open
#   - loops.sh summary regressing to grep-based raw counts

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REDUCER="$ROOT/ops/plugins/loops/bin/loops-ledger-reduce"
LOOPS_SH="$ROOT/ops/commands/loops.sh"

fail() { echo "D34 FAIL: $*" >&2; exit 1; }

# Require reducer exists
[[ -x "$REDUCER" ]] || fail "loops-ledger-reduce not found or not executable"

# Get canonical counts from reducer
REDUCER_JSON="$("$REDUCER" --counts 2>/dev/null)" || fail "reducer --counts failed"
REDUCER_OPEN="$(echo "$REDUCER_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['open'])")"

# Get summary output from loops.sh
SUMMARY_OUTPUT="$("$ROOT/bin/ops" loops summary 2>/dev/null)" || fail "ops loops summary failed"
SUMMARY_OPEN="$(echo "$SUMMARY_OUTPUT" | grep -E "^Open:" | awk '{print $2}')"

# Compare counts
if [[ "$REDUCER_OPEN" != "$SUMMARY_OPEN" ]]; then
    fail "open count mismatch: reducer=$REDUCER_OPEN summary=$SUMMARY_OPEN (summary may be using raw grep counts)"
fi

# Verify loops.sh uses reducer (not raw grep -c)
if grep -q 'grep -c.*status.*open' "$LOOPS_SH" 2>/dev/null; then
    fail "loops.sh summary() still uses raw grep -c (must use reducer)"
fi

echo "D34 PASS: loop ledger integrity enforced (open=$REDUCER_OPEN)"
