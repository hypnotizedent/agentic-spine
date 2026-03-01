---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-28
scope: home-reboot-validation
---

# Home Reboot Health Gate

Purpose: fail-safe reboot checklist for the home site (`proxmox-home`, `homeassistant`, `pihole-home`, `nas`).

## Pre-Reboot Hard Stops

- Do not reboot if `/etc/pve/jobs.cfg` has invalid scheduler fields.
- Do not reboot if `pve-cluster.service` is not `active`.
- Do not reboot if LXC `105` is not configured for `onboot: 1`.
- Do not reboot if NAS mount targets required by home workloads are unreachable.

## Pre-Reboot Checks

```bash
ssh proxmox-home 'systemctl is-active pve-cluster.service pve-firewall.service pvescheduler.service'
ssh proxmox-home 'pct status 105 && pct config 105 | grep -E "^onboot: 1$"'
ssh proxmox-home 'pct exec 105 -- sh -lc "command -v pihole && pihole -v"'
ssh proxmox-home 'grep -n "mailnotification" /etc/pve/jobs.cfg'
```

## Post-Reboot Checks

```bash
ssh proxmox-home 'systemctl is-active pve-cluster.service pve-firewall.service pve-guests.service pvescheduler.service'
ssh proxmox-home 'pct status 105 && pct exec 105 -- sh -lc "command -v pihole && pihole -v"'
./bin/ops cap run verify.pack.run infra
./bin/ops cap run verify.pack.run home
```

## Recovery Steps

- If `pvescheduler.service` is degraded, validate and correct `mailnotification` enum values in `/etc/pve/jobs.cfg` (`always|failure`) and restart scheduler.
- If LXC `105` is down or unhealthy, start it and re-check Pi-hole CLI health.
- If HA add-ons are degraded after boot, run site recovery and then re-run verify packs.

## Rollback Criteria

Stop and escalate if any of the following remains true after one recovery pass:

- `pve-cluster.service` not active
- `pvescheduler.service` not active
- LXC `105` missing Pi-hole binary/health
- Infra verify pack has deterministic failures tied to home boot sequence
