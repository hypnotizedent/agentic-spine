#!/usr/bin/env bash
# spine-state-sync-from-operator-console.sh
#
# T1 State Sync: pull canonical governance state from operator console (MBP)
# to execution host (ai-consolidation) Root 1 as a read-only projection.
#
# Direction: ai-consolidation pulls FROM MBP (operator console stays at zero LaunchAgents)
# Target:    ~/.runtime/spine/state/ (Root 1 — governance mirror)
# Authority: MBP remains sole canonical state root. This copy is read-only.
#
# SQLite safety: shared_authority.db is backed up on MBP via sqlite3 .backup
# before transfer, avoiding WAL corruption from rsync of a live database.

set -euo pipefail

# --- Configuration ---
MBP_USER="ronnyworks"
MBP_HOST="100.85.186.7"
SSH_KEY="${HOME}/.ssh/spine_machine_ed25519"
SSH_OPTS="-o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -i ${SSH_KEY} -o BatchMode=yes"

# Remote paths (MBP canonical)
REMOTE_STATE_ROOT="/Users/${MBP_USER}/code/.runtime/spine/state"
REMOTE_DB="${REMOTE_STATE_ROOT}/shared_authority.db"
REMOTE_BACKUP_DIR="/tmp/spine-state-sync"
REMOTE_BACKUP_DB="${REMOTE_BACKUP_DIR}/shared_authority.db"

# Local paths (ai-consolidation Root 1)
LOCAL_STATE_ROOT="${HOME}/code/.runtime/spine/state"

LOGPREFIX="[spine-state-sync]"

log() { echo "${LOGPREFIX} $(date -u +%Y-%m-%dT%H:%M:%SZ) $*"; }

# --- Preflight ---
if ! ssh ${SSH_OPTS} "${MBP_USER}@${MBP_HOST}" "echo ok" >/dev/null 2>&1; then
    log "WARN: MBP unreachable (expected when MBP is asleep/off). Skipping sync."
    exit 0
fi

log "MBP reachable. Starting state sync."

# --- Step 1: SQLite-safe backup on MBP ---
log "Step 1: Creating SQLite backup on MBP..."
ssh ${SSH_OPTS} "${MBP_USER}@${MBP_HOST}" "
    mkdir -p ${REMOTE_BACKUP_DIR}
    if [ -f '${REMOTE_DB}' ]; then
        sqlite3 '${REMOTE_DB}' \".backup '${REMOTE_BACKUP_DB}'\"
    else
        echo 'WARN: shared_authority.db not found on MBP'
    fi
"

# --- Step 2: rsync state tree (excluding SQLite WAL artifacts) ---
log "Step 2: Syncing state tree via rsync..."
mkdir -p "${LOCAL_STATE_ROOT}"
rsync -az --delete \
    --exclude='*.db-shm' \
    --exclude='*.db-wal' \
    --exclude='shared_authority.db' \
    -e "ssh ${SSH_OPTS}" \
    "${MBP_USER}@${MBP_HOST}:${REMOTE_STATE_ROOT}/" \
    "${LOCAL_STATE_ROOT}/"

# --- Step 3: Copy the SQLite backup (consistent snapshot) ---
log "Step 3: Copying SQLite backup..."
scp ${SSH_OPTS} \
    "${MBP_USER}@${MBP_HOST}:${REMOTE_BACKUP_DB}" \
    "${LOCAL_STATE_ROOT}/shared_authority.db"

# --- Step 4: Verify integrity ---
log "Step 4: Verifying SQLite integrity..."
INTEGRITY=$(sqlite3 "${LOCAL_STATE_ROOT}/shared_authority.db" "PRAGMA integrity_check" 2>&1)
if [ "${INTEGRITY}" = "ok" ]; then
    log "SQLite integrity: ok"
else
    log "ERROR: SQLite integrity check failed: ${INTEGRITY}"
    exit 1
fi

# --- Step 5: Log sync summary ---
CLOSED_LOOPS=$(sqlite3 "${LOCAL_STATE_ROOT}/shared_authority.db" "SELECT COUNT(*) FROM loops WHERE status='closed'" 2>/dev/null || echo "?")
SCOPE_COUNT=$(find "${LOCAL_STATE_ROOT}/loop-scopes" -name "*.scope.md" 2>/dev/null | wc -l | tr -d ' ')
HANDOFF_COUNT=$(find "${LOCAL_STATE_ROOT}/handoffs" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')

# --- Step 6: Write sync freshness marker for T3 mobile surface ---
date -u +%Y-%m-%dT%H:%M:%SZ > "${LOCAL_STATE_ROOT}/.last_sync_utc"

log "Sync complete. closed_loops=${CLOSED_LOOPS} scopes=${SCOPE_COUNT} handoffs=${HANDOFF_COUNT}"
