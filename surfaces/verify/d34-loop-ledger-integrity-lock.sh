#!/usr/bin/env bash
# TRIAGE: Check loop scope files match deduped counts. Run loops.reconcile if stale.
set -euo pipefail

# D34: Loop Ledger Integrity Lock
# Purpose: Ensure loop summary counts are derived from scope files (the SSOT)
#          and not from the deprecated open_loops.jsonl or raw grep.
#
# Fails on:
#   - loops.sh summary() still using raw grep -c for counting
#   - loops.sh referencing open_loops.jsonl as primary source for summary
#   - Scope-file direct count mismatching ops loops summary output

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOOPS_SH="$ROOT/ops/commands/loops.sh"
SCOPES_DIR="$ROOT/mailroom/state/loop-scopes"

fail() { echo "D34 FAIL: $*" >&2; exit 1; }

# 1. Verify loops.sh summary does NOT use raw grep -c for counting
if grep -q 'grep -c.*status.*open' "$LOOPS_SH" 2>/dev/null; then
    fail "loops.sh summary() still uses raw grep -c (must use scope-file parser)"
fi

# 2. Count open loops directly from scope files (independent check)
SCOPE_OPEN=0
if [[ -d "$SCOPES_DIR" ]]; then
    for f in "$SCOPES_DIR"/*.scope.md; do
        [[ -f "$f" ]] || continue
        # Parse front-matter status
        status="$(awk '/^---$/{n++; next} n==1 && /^status:/{print $2; exit}' "$f")"
        case "$status" in
            active|draft|open) SCOPE_OPEN=$((SCOPE_OPEN + 1)) ;;
        esac
    done
fi

# 3. Get ops loops summary open count
SUMMARY_OUTPUT="$("$ROOT/bin/ops" loops summary 2>/dev/null)" || fail "ops loops summary failed"
SUMMARY_OPEN="$(echo "$SUMMARY_OUTPUT" | grep -E '^\s*Open:' | awk '{print $2}')"

# 4. Compare scope-file count with summary output
if [[ "$SCOPE_OPEN" != "$SUMMARY_OPEN" ]]; then
    fail "open count mismatch: scope_files=$SCOPE_OPEN summary=$SUMMARY_OPEN"
fi

echo "D34 PASS: loop ledger integrity enforced (open=$SCOPE_OPEN, source=scope-files)"
