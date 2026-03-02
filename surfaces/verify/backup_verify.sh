#!/bin/bash
# Backup Verification Script
# Governance: docs/runbooks/BACKUP_GOVERNANCE.md
# Issue: #622
# Purpose: Check that Tier 1 VMs have recent backups (read-only)

set -euo pipefail

# Network gate — skip cleanly when Tailscale VPN is disconnected
source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale_for "pve"

# Configuration
PVE_HOST="${PVE_HOST:-pve}"
BACKUP_PATH="/tank/backups/vzdump/dump"
MAX_AGE_HOURS="${MAX_AGE_HOURS:-24}"

# Tier 1 VMs (critical - must have backup within MAX_AGE_HOURS)
TIER1_VMIDS="${TIER1_VMIDS:-200}"

# Tier 2 VMs (important - warn if older than 48h)
TIER2_VMIDS="${TIER2_VMIDS:-201 202 203}"

echo "=== Backup Verification ==="
echo "Host: $PVE_HOST"
echo "Max age (Tier 1): ${MAX_AGE_HOURS}h"
echo "Tier 1 VMs: $TIER1_VMIDS"
echo "Tier 2 VMs: $TIER2_VMIDS"
echo ""

# Check SSH connectivity
if ! ssh -o ConnectTimeout=5 "$PVE_HOST" "echo ok" >/dev/null 2>&1; then
    echo "CRITICAL: Cannot connect to $PVE_HOST"
    exit 2
fi

NOW=$(date +%s)
ERRORS=0
WARNINGS=0

check_backup() {
    local VMID=$1
    local TIER=$2
    local MAX_AGE=$3

    # Find latest backup
    LATEST=$(ssh "$PVE_HOST" "ls -t $BACKUP_PATH/vzdump-qemu-${VMID}-*.vma.zst 2>/dev/null | head -1" || echo "")

    if [ -z "$LATEST" ]; then
        echo "CRITICAL: VM $VMID - NO BACKUP FOUND"
        return 2
    fi

    # Get backup timestamp
    BACKUP_TIME=$(ssh "$PVE_HOST" "stat -c %Y '$LATEST' 2>/dev/null" || echo "0")
    AGE_HOURS=$(( (NOW - BACKUP_TIME) / 3600 ))

    # Get backup size
    BACKUP_SIZE=$(ssh "$PVE_HOST" "ls -lh '$LATEST' 2>/dev/null | awk '{print \$5}'" || echo "?")
    BACKUP_FILE=$(basename "$LATEST")

    if [ "$AGE_HOURS" -gt "$MAX_AGE" ]; then
        if [ "$TIER" = "1" ]; then
            echo "CRITICAL: VM $VMID - Backup is ${AGE_HOURS}h old (max: ${MAX_AGE}h)"
            echo "         File: $BACKUP_FILE ($BACKUP_SIZE)"
            return 2
        else
            echo "WARNING: VM $VMID - Backup is ${AGE_HOURS}h old (max: ${MAX_AGE}h)"
            echo "         File: $BACKUP_FILE ($BACKUP_SIZE)"
            return 1
        fi
    else
        echo "OK: VM $VMID - Backup is ${AGE_HOURS}h old ($BACKUP_SIZE)"
        return 0
    fi
}

echo "--- Tier 1 (Critical) ---"
for VMID in $TIER1_VMIDS; do
    if ! check_backup "$VMID" 1 "$MAX_AGE_HOURS"; then
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "--- Tier 2 (Important) ---"
for VMID in $TIER2_VMIDS; do
    result=0
    check_backup "$VMID" 2 48 || result=$?
    if [ "$result" -eq 2 ]; then
        ERRORS=$((ERRORS + 1))
    elif [ "$result" -eq 1 ]; then
        WARNINGS=$((WARNINGS + 1))
    fi
done

echo ""
echo "--- Storage Check ---"
STORAGE_PCT=$(ssh "$PVE_HOST" "pvesm status 2>/dev/null | grep tank-backups | awk '{print \$7}'" || echo "?")
echo "tank-backups usage: $STORAGE_PCT"

# Check if storage is getting full (>80%)
STORAGE_NUM=$(echo "$STORAGE_PCT" | tr -d '%' | cut -d'.' -f1 || echo "0")
if [ "${STORAGE_NUM:-0}" -gt 80 ]; then
    echo "WARNING: Storage over 80% - consider pruning or expanding"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "=== Summary ==="
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "RESULT: FAILED - Critical backup issues found"
    exit 2
elif [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo "RESULT: WARNING - Non-critical issues found"
    exit 1
else
    echo ""
    echo "RESULT: PASSED - All backups healthy"
    exit 0
fi
