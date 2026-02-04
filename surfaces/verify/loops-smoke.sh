#!/usr/bin/env bash
# STATUS: smoke-test (not called by any gate; run manually)
# ═══════════════════════════════════════════════════════════════════════════
# loops-smoke.sh - Verify ops loops creates state dir when missing
# ═══════════════════════════════════════════════════════════════════════════
# This test proves loops.sh handles missing state directory gracefully.
# CRITICAL regression gate - ensures fresh clones don't silently fail.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE="${SPINE_REPO:-$HOME/Code/agentic-spine}"
STATE="$SPINE/mailroom/state"
LOOPS="$STATE/open_loops.jsonl"
BACKUP_DIR="/tmp/loops-smoke-backup-$$"

# Backup existing state if present
if [[ -d "$STATE" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp -r "$STATE" "$BACKUP_DIR/"
fi

cleanup() {
    # Restore state from backup
    if [[ -d "$BACKUP_DIR/state" ]]; then
        rm -rf "$STATE"
        mv "$BACKUP_DIR/state" "$STATE"
    fi
    rm -rf "$BACKUP_DIR"
}
trap cleanup EXIT

# Remove state dir to simulate fresh clone
rm -rf "$STATE"

# Run collect - should recreate state dir and loops file
if ! "$SPINE/bin/ops" loops collect >/dev/null 2>&1; then
    echo "FAIL: ops loops collect failed"
    exit 1
fi

# Verify state dir exists
if [[ ! -d "$STATE" ]]; then
    echo "FAIL: state dir not created"
    exit 1
fi

# Verify loops file exists (may be empty, but must exist)
if [[ ! -f "$LOOPS" ]]; then
    echo "FAIL: loops file not created"
    exit 1
fi

echo "OK: loops state init"
