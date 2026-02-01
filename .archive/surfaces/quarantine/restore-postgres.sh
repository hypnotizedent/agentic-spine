#!/bin/bash
# Mint OS PostgreSQL Restore Script
# Usage: ./restore-postgres.sh /path/to/backup.sql.gz

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <backup_file.sql.gz>"
    echo ""
    echo "Available backups:"
    ls -lh /home/docker-host/backups/postgres/*.sql.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "WARNING: This will REPLACE all data in mint_os database!"
echo "Backup file: $BACKUP_FILE"
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo "[$(date)] Stopping API to prevent writes..."
docker stop mint-os-dashboard-api 2>/dev/null || true

echo "[$(date)] Restoring from backup..."
gunzip -c "$BACKUP_FILE" | docker exec -i mint-os-postgres psql -U mintadmin -d mint_os

echo "[$(date)] Restarting API..."
docker start mint-os-dashboard-api

echo "[$(date)] Restore complete!"
echo "[$(date)] Verifying..."
docker exec mint-os-postgres psql -U mintadmin -d mint_os -c "SELECT COUNT(*) as orders FROM orders;"
