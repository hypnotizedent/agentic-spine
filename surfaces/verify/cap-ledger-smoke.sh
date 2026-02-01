#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# cap-ledger-smoke.sh - Verify ops cap creates state dir when missing
# ═══════════════════════════════════════════════════════════════════════════
# This test proves cap.sh handles missing state directory gracefully.
# CRITICAL regression gate - ensures fresh clones don't silently fail.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE="${SPINE_REPO:-$HOME/Code/agentic-spine}"
STATE="$SPINE/mailroom/state"
LEDGER="$STATE/ledger.csv"
BACKUP_DIR="/tmp/cap-ledger-smoke-backup-$$"

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

# Run a known safe read-only capability
if ! "$SPINE/bin/ops" cap run spine.verify >/dev/null 2>&1; then
    # spine.verify may fail for other reasons, but state should still be created
    :
fi

# Verify state dir exists
if [[ ! -d "$STATE" ]]; then
    echo "FAIL: state dir not created"
    exit 1
fi

# Verify ledger file exists
if [[ ! -f "$LEDGER" ]]; then
    echo "FAIL: ledger file not created"
    exit 1
fi

echo "OK: cap ledger state init"
