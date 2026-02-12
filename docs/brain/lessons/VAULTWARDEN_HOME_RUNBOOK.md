---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-12
scope: home-lessons
---

# Vaultwarden Home Runbook

> Operational runbook for Vaultwarden on proxmox-home VM 102.

## Quick Reference

| Field | Value |
|-------|-------|
| VM ID | 102 on proxmox-home |
| Tailscale IP | 100.93.142.63 |
| Web UI | http://vault:8080 |
| SSH | `ssh root@vault` |
| Resources | 2c / 2GB RAM / 16GB disk |
| Container | `vaultwarden` (single, healthy) |
| Compose path | `/home/ron/vaultwarden/` |

## Architecture

Single self-contained container with embedded SQLite database. No PostgreSQL, Redis, or external dependencies. All persistent data in `/home/ron/vaultwarden/data/`.

**User context:** User `ron` on VM 102 (not `root`, not `ubuntu`).

## Backup Strategy

- **VM-level:** vzdump P0 daily 03:00 (artifact confirmed 2026-02-11, 3.9GB)
- **App-level:** Planned tar.gz of `data/` dir to NAS (not yet implemented)

## Restore Procedure

### VM Restore
```bash
ssh root@proxmox-home
qmrestore /mnt/pve/synology-backups/dump/vzdump-qemu-102-*.vma.zst 102
qm start 102
```

### App Restore
```bash
ssh root@vault
cd /home/ron/vaultwarden
docker compose down
# restore data/ from backup
docker compose up -d
```

## Health Check

```bash
# Container status
ssh root@vault "cd /home/ron/vaultwarden && docker compose ps"

# Web UI
curl -s -o /dev/null -w "%{http_code}" http://vault:8080/
# Expected: 200

# SQLite integrity
ssh root@vault "sqlite3 /home/ron/vaultwarden/data/db.sqlite3 'PRAGMA integrity_check;'"
```

## Access

- **Web vault:** http://vault:8080 (user login)
- **Admin panel:** http://vault:8080/admin (token in Infisical `/spine/vm-infra/vaultwarden/ADMIN_TOKEN`)
- **Bitwarden clients:** Set server URL to `http://vault:8080`

## Common Issues

1. **"Invalid master password"** — Check `DOMAIN` env var matches access URL, or restore from backup
2. **Browser extension "Server URL Invalid"** — Verify Tailscale is running, set URL to `http://vault:8080`
3. **Container fails to start** — Check logs, verify `data/` exists and is writable
4. **Out of disk space** — `docker system prune -a`, or expand VM disk: `qm resize 102 scsi0 +10G`

## Service Restart

```bash
ssh root@vault "cd /home/ron/vaultwarden && docker compose restart"
```

## Related Documents

- `docs/governance/MINILAB_SSOT.md`
- `docs/governance/HOME_BACKUP_STRATEGY.md`
