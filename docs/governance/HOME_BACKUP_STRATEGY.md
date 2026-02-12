---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: home-backup-strategy
---

# Home Backup Strategy

> Backup plan for the home site (proxmox-home + Synology DS918+ NAS).
> Parent loop: `LOOP-HOME-BACKUP-INFRASTRUCTURE-ENABLE-20260209`

---

## Infrastructure Summary

| Component | Details |
|-----------|---------|
| **Hypervisor** | proxmox-home (Beelink, AMD Ryzen 7 7840HS, 27GB RAM, PVE 8.4.1) |
| **NAS** | Synology DS918+ (2x16TB IronWolf Pro + 2x3TB WD Red, SHR, ~20TB volume1) |
| **Network** | Home LAN 10.0.0.0/24, proxmox-home=10.0.0.50, NAS=10.0.0.150 |
| **Tailscale** | proxmox-home=100.103.99.62, NAS=100.102.199.111 |

### Guests

| ID | Type | Name | Tailscale IP | Status |
|----|------|------|-------------|--------|
| 100 | VM | Home Assistant | 100.67.120.1 | Running |
| 101 | VM | Immich | 100.83.160.109 | **STOPPED** |
| 102 | VM | Vaultwarden | 100.93.142.63 | Running |
| 103 | LXC | download-home (*arr) | 100.125.138.110 | Running |
| 105 | LXC | pihole-home | 100.105.148.96 | Running |

---

## Backup Tiers

| Tier | Guests | Schedule | Retention | Rationale |
|------|--------|----------|-----------|-----------|
| **P0 (Critical)** | VM 100 (HA), VM 102 (Vaultwarden) | Daily 03:00 | keep-last=3 | Irreplaceable state (automations, passwords) |
| **P1 (Important)** | LXC 103 (download-home) | Daily 03:15 | keep-last=3 | Config-heavy, slow to rebuild |
| **P2 (Deferrable)** | VM 101 (Immich), LXC 105 (pihole-home) | Weekly (Sun 04:00) | keep-last=2 | Immich stopped; pihole is rebuildable |

### Schedule Rationale
- **03:00 start** — staggered from shop vzdump (02:00) to avoid NAS write contention during offsite sync (09:00).
- **P0 before P1** — critical guests finish before important ones start.
- **Weekly for P2** — Immich is stopped (no state changes) and pihole config rarely changes.

---

## Backup Method: vzdump to NAS via NFS

### Why vzdump (not Hyper Backup) as primary

| Factor | vzdump | Hyper Backup |
|--------|--------|-------------|
| Scope | Full VM/LXC image | NAS-side file-level |
| Restore | PVE-native restore (`qmrestore`/`pct restore`) | File-level only |
| Scheduling | PVE built-in job scheduler | Synology Task Scheduler |
| Monitoring | `backup.status` capability already exists | No spine integration |

**Decision:** vzdump is primary (matches shop model). Hyper Backup is a future P5 addition for NAS-to-offsite DR — not in scope for this loop.

### Unprivileged LXC Workaround (GAP-OP-118 Fix)

Unprivileged LXC containers (103, 105) use `lxc-usernsexec` during vzdump which remaps UID 0→100000. This mapped UID cannot write to Synology NFS. **Fix:** add `tmpdir /var/tmp` to vzdump jobs containing LXC guests. This stages `pct.conf` on local disk (accessible to mapped UID) while the final archive is written to NFS outside the user namespace (as root). Applied to `backup-home-p1-daily` and `backup-home-p2-weekly` in `/etc/pve/jobs.cfg`.

### Storage Target

- **NAS NFS export:** `/volume1/backups/proxmox_backups` (already exists, verified in MINILAB_SSOT.md)
- **Mount on proxmox-home:** TBD — must use LAN IP `10.0.0.150` (NOT Tailscale IP — see NFS governance in MEMORY)
- **PVE storage target:** Create `nas-backups` storage entry pointing to NFS mount

### NFS Mount Specification

```
# /etc/fstab on proxmox-home
10.0.0.150:/volume1/backups/proxmox_backups /mnt/nas-backups nfs defaults,soft,timeo=150,retrans=3,x-systemd.requires=network-online.target 0 0
```

**Critical:** Use `soft` mount (not `hard`) — home NAS may be powered off; a hard mount would hang the hypervisor.

### PVE Storage Config

```
# /etc/pve/storage.cfg addition
dir: nas-backups
  path /mnt/nas-backups
  content backup
  prune-backups keep-last=3
  shared 0
```

---

## App-Level Backups

### Home Assistant (VM 100)

- **Method:** HA built-in backup (Settings → System → Backups)
- **Target:** NAS `/volume1/backups/homeassistant_backups/` (export exists)
- **Tracking:** Already in `backup.inventory.yaml` as `app-home-assistant` (enabled, 48h threshold)
- **Action needed:** Verify HA backup automation is actually running and producing artifacts

### Immich (VM 101) — DEFERRED

- VM is stopped. No app-level backup needed until VM is restarted.
- When restarted: Immich DB (PostgreSQL) needs pg_dump to NAS.

### Vaultwarden (VM 102)

- **Note:** Shop Vaultwarden (infra-core VM 204) already has app-level backup to NAS.
- Home Vaultwarden on VM 102 — assess whether it shares the same data or is independent.
- **Action needed:** Determine if home Vaultwarden needs its own app-level backup or if vzdump is sufficient.

---

## Backup Inventory Registration

Add to `ops/bindings/backup.inventory.yaml` (proposal 2):

```yaml
# HOME VM BACKUPS - PRIMARY (proxmox-home) - vzdump to NAS NFS
- name: home-vm-100-ha-primary
  enabled: false  # flip true after vzdump job is configured
  kind: file_glob
  host: proxmox-home
  base_path: "/mnt/nas-backups"
  glob: "vzdump-qemu-100-*.vma.zst"
  stale_after_hours: 26
  classification: critical

- name: home-vm-102-vaultwarden-primary
  enabled: false
  kind: file_glob
  host: proxmox-home
  base_path: "/mnt/nas-backups"
  glob: "vzdump-qemu-102-*.vma.zst"
  stale_after_hours: 26
  classification: critical

- name: home-lxc-103-download-primary
  enabled: false
  kind: file_glob
  host: proxmox-home
  base_path: "/mnt/nas-backups"
  glob: "vzdump-lxc-103-*.tar.zst"
  stale_after_hours: 26
  classification: important

- name: home-vm-101-immich-primary
  enabled: false
  kind: file_glob
  host: proxmox-home
  base_path: "/mnt/nas-backups"
  glob: "vzdump-qemu-101-*.vma.zst"
  stale_after_hours: 168
  classification: important
  notes: "VM stopped; weekly backup when restarted."

- name: home-lxc-105-pihole-primary
  enabled: false
  kind: file_glob
  host: proxmox-home
  base_path: "/mnt/nas-backups"
  glob: "vzdump-lxc-105-*.tar.zst"
  stale_after_hours: 168
  classification: rebuildable
```

> These entries are `enabled: false` by default. They get flipped to `true` in proposal 2 after vzdump jobs are confirmed working.

---

## Prerequisites (must verify before proposal 2)

1. **NFS connectivity:** `ssh proxmox-home 'mount -t nfs 10.0.0.150:/volume1/backups/proxmox_backups /mnt/nas-backups && ls /mnt/nas-backups'`
2. **vzdump storage target:** Confirm PVE can see `nas-backups` storage via `pvesm status`
3. **Existing job audit:** Check what the 3 disabled jobs reference and whether they can be re-enabled or must be recreated
4. **HA backup check:** Verify if HA is producing backup artifacts at `/volume1/backups/homeassistant_backups/`

---

## Execution Order (Proposal 2)

1. Create NFS fstab entry + mount on proxmox-home
2. Add `nas-backups` to `/etc/pve/storage.cfg`
3. Configure/enable vzdump jobs (P0 → P1 → P2)
4. Add entries to `backup.inventory.yaml` (enabled=true)
5. Run `backup.calendar.generate` to update calendar
6. Run `backup.status` to confirm freshness
7. Update `MINILAB_SSOT.md` + `BACKUP_GOVERNANCE.md`
8. Close loop

---

## Related

| Document | Relationship |
|----------|-------------|
| [BACKUP_GOVERNANCE.md](BACKUP_GOVERNANCE.md) | Parent governance doc (shop-focused, needs home addendum) |
| [MINILAB_SSOT.md](MINILAB_SSOT.md) | Home infrastructure SSOT |
| `ops/bindings/backup.inventory.yaml` | Backup target registry |
| `ops/bindings/backup.calendar.yaml` | Backup schedule calendar |
