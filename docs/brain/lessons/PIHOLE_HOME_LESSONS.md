---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-12
scope: home-lessons
---

# Pi-hole Home Lessons

> Operational notes for Pi-hole DNS on proxmox-home LXC 105.

## Quick Reference

| Field | Value |
|-------|-------|
| LXC ID | 105 on proxmox-home |
| Tailscale IP | 100.105.148.96 |
| Local IP | 10.0.0.53 |
| Web UI | http://pihole-home/admin |
| Resources | 1c / 512MB RAM / 4GB disk |
| Status | **STOPPED** |

## Current State: STOPPED

The UDR7 (10.0.0.1) handles DNS directly. DHCP hands out `10.0.0.1` as DNS, NOT `10.0.0.53`.

**To re-enable Pi-hole:**
1. Start LXC: `pct start 105` on proxmox-home
2. Verify FTL listening on port 53: `ssh pihole-home "pihole status"`
3. Update UDR7 DHCP DNS setting from `10.0.0.1` to `10.0.0.53`
4. Test: `dig @10.0.0.53 google.com`

## Pi-hole v6 Notes

If upgraded to v6, config uses TOML format. **`DNSMASQ_LISTENING=all` env var is IGNORED** — use FTL CLI:
```bash
pihole-FTL config webserver.interface all
```

## Backup Strategy

- **VM-level:** vzdump P2 weekly Sun 04:00 (not yet validated — next run Feb 15)
- **App-level:** Teleporter export (not configured — LXC is stopped)
- **Classification:** Rebuildable (can reinstall from scratch)

## Relationship to Shop Pi-hole

| Instance | Location | IP | Status |
|----------|----------|-----|--------|
| pihole-home | LXC 105 (home) | 10.0.0.53 | Stopped |
| pihole-core | VM 204 (shop) | 192.168.1.204 | Running |

No synchronization between instances. Independent blocklists and configs.

## Common Issues (When Running)

1. **FTL not listening on port 53** — Disable systemd-resolved: `systemctl disable --now systemd-resolved`
2. **Web UI 404** — Restart lighttpd: `systemctl restart lighttpd`
3. **Devices not using Pi-hole** — UDR DHCP DNS must point to 10.0.0.53, not 10.0.0.1

## Pending Decision

Decide: re-enable Pi-hole or permanently decommission LXC 105? If decommissioned, update MINILAB_SSOT and remove backup entries.

## Related Documents

- `docs/governance/MINILAB_SSOT.md`
- `docs/governance/HOME_BACKUP_STRATEGY.md`
