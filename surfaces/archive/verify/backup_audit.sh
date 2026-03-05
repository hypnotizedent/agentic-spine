#!/bin/bash
# STATUS: data-generator (writes backup_inventory.json; not a verifier)
# Backup Audit Script
# Governance: docs/governance/BACKUP_GOVERNANCE.md
# Issue: #622
# Purpose: Generate JSON inventory of VM/CT backups (read-only)

set -euo pipefail

# Network gate — skip cleanly when Tailscale VPN is disconnected
source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale_for "pve"

# Configuration
PVE_HOST="${PVE_HOST:-pve}"
BACKUP_PATH="/tank/backups/vzdump/dump"
OUTPUT_DIR="${OUTPUT_DIR:-$(dirname "$0")/../../data}"
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%SZ)
OUTPUT_FILE="${OUTPUT_DIR}/backup_inventory.json"

echo "=== Backup Audit Script ==="
echo "Host: $PVE_HOST"
echo "Backup path: $BACKUP_PATH"
echo "Output: $OUTPUT_FILE"
echo ""

# Check SSH connectivity
if ! ssh -o ConnectTimeout=5 "$PVE_HOST" "echo ok" >/dev/null 2>&1; then
    echo "ERROR: Cannot connect to $PVE_HOST"
    exit 1
fi

echo "Collecting VM inventory..."
VM_LIST=$(ssh "$PVE_HOST" "qm list 2>/dev/null | tail -n +2" || echo "")

echo "Collecting CT inventory..."
CT_LIST=$(ssh "$PVE_HOST" "pct list 2>/dev/null | tail -n +2" || echo "")

echo "Collecting storage status..."
STORAGE_STATUS=$(ssh "$PVE_HOST" "pvesm status 2>/dev/null | grep tank-backups" || echo "")

echo "Collecting backup files..."
BACKUP_FILES=$(ssh "$PVE_HOST" "ls -l $BACKUP_PATH/*.vma.zst 2>/dev/null" || echo "")

echo "Collecting job configuration..."
JOB_CONFIG=$(ssh "$PVE_HOST" "cat /etc/pve/jobs.cfg 2>/dev/null" || echo "")

# Parse storage info
if [ -n "$STORAGE_STATUS" ]; then
    STORAGE_TOTAL=$(echo "$STORAGE_STATUS" | awk '{print $4}')
    STORAGE_USED=$(echo "$STORAGE_STATUS" | awk '{print $5}')
    STORAGE_AVAIL=$(echo "$STORAGE_STATUS" | awk '{print $6}')
    STORAGE_PCT=$(echo "$STORAGE_STATUS" | awk '{print $7}' | tr -d '%')
else
    STORAGE_TOTAL=0
    STORAGE_USED=0
    STORAGE_AVAIL=0
    STORAGE_PCT=0
fi

# Build JSON output
echo "Generating JSON inventory..."

cat > "$OUTPUT_FILE" << EOF
{
  "generated": "$TIMESTAMP",
  "host": "$PVE_HOST",
  "backup_path": "$BACKUP_PATH",
  "storage": {
    "target": "tank-backups",
    "total_kb": $STORAGE_TOTAL,
    "used_kb": $STORAGE_USED,
    "available_kb": $STORAGE_AVAIL,
    "percent_used": $STORAGE_PCT
  },
  "vms": [
EOF

# Process VMs
FIRST=true
while IFS= read -r line; do
    [ -z "$line" ] && continue

    VMID=$(echo "$line" | awk '{print $1}')
    NAME=$(echo "$line" | awk '{print $2}')
    STATUS=$(echo "$line" | awk '{print $3}')

    # Find latest backup for this VM
    LATEST_BACKUP=$(ssh "$PVE_HOST" "ls -t $BACKUP_PATH/vzdump-qemu-${VMID}-*.vma.zst 2>/dev/null | head -1" || echo "")

    if [ -n "$LATEST_BACKUP" ]; then
        BACKUP_SIZE=$(ssh "$PVE_HOST" "stat -c %s '$LATEST_BACKUP' 2>/dev/null" || echo "0")
        BACKUP_TIME=$(ssh "$PVE_HOST" "stat -c %Y '$LATEST_BACKUP' 2>/dev/null" || echo "0")
        BACKUP_FILE=$(basename "$LATEST_BACKUP")
        BACKUP_STATUS="ok"
    else
        BACKUP_SIZE=0
        BACKUP_TIME=0
        BACKUP_FILE="none"
        BACKUP_STATUS="missing"
    fi

    # Calculate age in hours
    NOW=$(date +%s)
    if [ "$BACKUP_TIME" -gt 0 ]; then
        AGE_HOURS=$(( (NOW - BACKUP_TIME) / 3600 ))
    else
        AGE_HOURS=-1
    fi

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    cat >> "$OUTPUT_FILE" << VMEOF
    {
      "vmid": $VMID,
      "name": "$NAME",
      "status": "$STATUS",
      "latest_backup": "$BACKUP_FILE",
      "backup_size_bytes": $BACKUP_SIZE,
      "backup_age_hours": $AGE_HOURS,
      "backup_status": "$BACKUP_STATUS"
    }
VMEOF

done <<< "$VM_LIST"

cat >> "$OUTPUT_FILE" << EOF

  ],
  "containers": [],
  "summary": {
    "total_vms": $(echo "$VM_LIST" | grep -c . || echo 0),
    "total_cts": $(echo "$CT_LIST" | grep -c . || echo 0)
  }
}
EOF

echo ""
echo "=== Audit Complete ==="
echo "Output: $OUTPUT_FILE"
echo ""

# Print summary
echo "Summary:"
echo "  VMs: $(echo "$VM_LIST" | grep -c . || echo 0)"
echo "  CTs: $(echo "$CT_LIST" | grep -c . || echo 0)"
echo "  Storage used: ${STORAGE_PCT}%"
