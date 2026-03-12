---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-12
scope: vm200-physical-closeout
---

# VM200 Physical Closeout

## Pre-delete restore proof

- Observed on `pve` at `2026-03-12T04:30:02Z`.
- Cold capsule path: `/md1400/backup-cold/vzdump/pve/vzdump-qemu-200-2026_03_07-02_00_03.vma.zst`
- Cold capsule size: `196820427012` bytes (`183.3 GiB`)
- Cold capsule mtime: `2026-03-07T08:24:01Z`
- Cold capsule SHA-256: `ee8b3844cb58fc7c7cb72433f95fc12df4957171afdfba6d01427551eb1182d4`
- QEMU config path: `/etc/pve/qemu-server/200.conf`
- QEMU config SHA-256 before delete: `3fcc25b6b697139205de70a4f5d93c613f0d2a6ba2d49912c0d0fa703738f095`
- Pre-delete config showed `scsi0: local-lvm:vm-200-disk-0,size=300G`

## Delete execution

- Executed on `pve` at `2026-03-12T04:30:02Z`
- Command: `qm disk unlink 200 --idlist scsi0 --force 1`

## Post-delete proof

- `qm config 200` no longer reports `scsi0`
- `grep '^scsi0:' /etc/pve/qemu-server/200.conf` returned no match
- `lvs --noheadings -o lv_name,vg_name,lv_size | grep vm-200-disk-0` returned no match
- QEMU config SHA-256 after delete: `2329aa1b90c440783bac6484a75ab5f83c73d4d3399c58a27b89c2cf84b007d5`

## Restore path

- Restore command: `qmrestore /md1400/backup-cold/vzdump/pve/vzdump-qemu-200-2026_03_07-02_00_03.vma.zst 9200 --storage local-lvm --unique 1`
- Rename immediately after restore: `qm set 9200 --name vm200-restore-2026-03-12`
- Guardrails:
  - restore only into an isolated sandbox identity
  - do not reuse `docker-host`
  - do not republish legacy DNS, Tailscale, or Cloudflare routes
