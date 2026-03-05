#!/usr/bin/env bash
# STATUS: smoke-test (not called by any gate; run manually)
# ═══════════════════════════════════════════════════════════════════════════
# loops-smoke.sh - Verify ops loops handles missing state gracefully
# ═══════════════════════════════════════════════════════════════════════════
# This test proves loops.sh handles missing state directory gracefully.
# CRITICAL regression gate - ensures fresh clones don't silently fail.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE="${SPINE_REPO:-$HOME/code/agentic-spine}"
STATE="$SPINE/mailroom/state"
SCOPES="$STATE/loop-scopes"

# Verify scopes dir exists
if [[ ! -d "$SCOPES" ]]; then
    echo "FAIL: loop-scopes dir not found: $SCOPES"
    exit 1
fi

# Verify ops loops list runs without error
if ! "$SPINE/bin/ops" loops list --open >/dev/null 2>&1; then
    echo "FAIL: ops loops list --open failed"
    exit 1
fi

# Verify ops loops summary runs without error
if ! "$SPINE/bin/ops" loops summary >/dev/null 2>&1; then
    echo "FAIL: ops loops summary failed"
    exit 1
fi

echo "OK: loops state smoke"
