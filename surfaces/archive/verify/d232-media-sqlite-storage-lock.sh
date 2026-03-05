#!/usr/bin/env bash
# TRIAGE: D232 media-sqlite-storage-lock — slskd SQLite databases must not reside on NFS
# D232: Media SQLite Storage Lock
# Enforces: slskd .db files are on local filesystem, not NFS (NFS causes WAL/lock corruption)
set -euo pipefail

source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale_for "download-stack"

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

# Resolve SSH target for download-stack
DS_IP=$(yq -r '.vms[] | select(.hostname == "download-stack") | .lan_ip // .tailscale_ip' "$VM_BINDING" 2>/dev/null || echo "")
DS_USER=$(yq -r '.vms[] | select(.hostname == "download-stack") | .ssh_user // "ubuntu"' "$VM_BINDING" 2>/dev/null || echo "ubuntu")

if [[ -z "$DS_IP" || "$DS_IP" == "null" ]]; then
  echo "SKIP: download-stack not found in vm.lifecycle binding"
  exit 0
fi

SSH_REF="${DS_USER}@${DS_IP}"
SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes"

# Check if slskd container is running
SLSKD_RUNNING=$(ssh $SSH_OPTS "$SSH_REF" 'sudo docker inspect slskd --format "{{.State.Running}}" 2>/dev/null || echo "false"' 2>/dev/null || echo "false")

if [[ "$SLSKD_RUNNING" != "true" ]]; then
  echo "SKIP: slskd container not running on download-stack"
  exit 0
fi

# Find all .db files in slskd data directory and check filesystem type
# stat -f uses %T for filesystem type on Linux (outputs e.g. "nfs", "ext2/ext3", "tmpfs")
DB_FILES=$(ssh $SSH_OPTS "$SSH_REF" 'sudo docker exec slskd find /app -name "*.db" -type f 2>/dev/null || echo ""' 2>/dev/null || echo "")

if [[ -z "$DB_FILES" ]]; then
  ok "No .db files found in slskd container (nothing to check)"
else
  while IFS= read -r db_path; do
    [[ -z "$db_path" ]] && continue

    # Use stat -f -c %T to get filesystem type (Linux stat)
    FS_TYPE=$(ssh $SSH_OPTS "$SSH_REF" "sudo docker exec slskd stat -f -c '%T' '${db_path}' 2>/dev/null || echo 'unknown'" 2>/dev/null || echo "unknown")

    # Normalize: NFS reports as "nfs" or "nfs4" or variants
    case "$FS_TYPE" in
      nfs*|NFS*)
        err "slskd SQLite database $db_path is on NFS filesystem ($FS_TYPE) — causes WAL/lock corruption"
        ;;
      unknown)
        err "slskd could not determine filesystem type for $db_path"
        ;;
      *)
        ok "slskd $db_path on local filesystem ($FS_TYPE)"
        ;;
    esac
  done <<< "$DB_FILES"
fi

# --- Result ---
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D232 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D232 PASS"
exit 0
