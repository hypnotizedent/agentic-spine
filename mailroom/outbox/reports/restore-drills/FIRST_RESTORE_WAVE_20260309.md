---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-09
scope: restore-drill-wave
---

# First Restore Wave - 2026-03-09

## Summary

This was the first post-green restore-drill wave against the current canonical backup model:

- `tank` = shop VM/LXC source backup plane
- `md1400` = shop cold VM/app/config plane
- `Synology` = home HA + home Pi-hole plane

Wave result:

- Shop VM plane: PASS
- Home restore plane: PASS
- Media config-state plane: PASS
- Communications backup parity plane: PASS
- Infra-core / Infisical runtime health: PASS
- Infisical scratch DB restore: DEFERRED FOR CLEAN RERUN
- Mail-archiver scratch restore: DEFERRED FOR NEXT WAVE

## Executed Proofs

### 1. Shop VM scratch restore from md1400

- Source artifact: `/md1400/backup-cold/vzdump/pve/vzdump-qemu-205-2026_03_08-11_54_54.vma.zst`
- Host: `pve`
- Scratch target: `VMID 9205`
- Scratch storage: `local-lvm`
- Result: restore unpack reached `100%` in the Proxmox restore log; scratch VM config materialized and `qm status 9205` returned `stopped`
- Cleanup: scratch guest destroyed after proof; stale restore lock had to be cleared after the restore task over-held `lock-9205.conf`

Notes:

- This proved that the md1400 shop cold VM plane can materialize a governed shop VM into scratch on `pve`.
- The stale lock behavior should be treated as operational residue on the Proxmox restore path, not a backup artifact failure.

### 2. Home Synology scratch restore

- Source artifact: `/mnt/pve/synology-backups/dump/vzdump-lxc-105-2026_03_08-04_00_02.tar.zst`
- Host: `proxmox-home`
- Scratch target: `CTID 9105`
- Scratch storage: `local-lvm`
- Restore duration: `5s`
- Result: scratch CT config materialized successfully for `pihole-home`
- Cleanup: scratch CT destroyed after proof

### 3. Media config restore dry-runs

Download-stack:

- Capability: `media.backup.restore`
- Run key: `CAP-20260309-042915__media.backup.restore__R07ti49977`
- Service: `radarr`
- Selected backup: `/mnt/docker/backups/media-config/download-stack-config-20260304-233318.tar.gz`
- Result: dry-run restore plan resolved correctly

Streaming-stack:

- Capability: `media.backup.restore`
- Run key: `CAP-20260309-042827__media.backup.restore__Rr85d34345`
- Service: `jellyfin`
- Selected backup: `/mnt/docker/backups/media-config/streaming-stack-config-20260305-034505.tar.gz`
- Result: dry-run restore plan resolved correctly

### 4. Communications backup parity proof

- Capability: `communications.mailarchiver.backup.status`
- Run key: `CAP-20260309-043406__communications.mailarchiver.backup.status__Rsmtd6927`
- Result: `status: OK`
- Proofs observed:
  - local DB artifact present
  - local uploads artifact present
  - local manifest present
  - md1400 offsite DB artifact present
  - md1400 offsite uploads artifact present
  - md1400 offsite manifest present
  - local/offsite DB bytes matched exactly
  - canonical cron present at `/etc/cron.d/communications-backups`

### 5. Infra-core runtime health

- Capability: `services.health.status -- --host infra-core`
- Run key: `CAP-20260309-043406__services.health.status__Rcg3n6924`
- Result: `status: OK (all endpoints healthy)`
- Endpoints observed healthy:
  - `caddy`
  - `cloudflared`
  - `infisical`
  - `vaultwarden`
  - `authentik`
  - `pihole`

## Deferred / Residual Drill Work

### Infisical scratch DB restore

Status: deferred for clean rerun

Reason:

- During this wave, the actual runtime health and backup freshness were re-proved, but the scratch DB restore session on `infra-core` was not cleanly receipted end-to-end because the remote command path was unstable while other long-running drill sessions were active.
- This is a drill execution residue, not current evidence of backup failure.

Next action:

- Re-run the authoritative procedure in `docs/archive/governance/INFISICAL_RESTORE_DRILL.md`
- Keep the scope narrow: dump copy -> scratch DB restore -> row counts -> cleanup -> receipt

### Mail-archiver scratch restore

Status: deferred to next wave

Reason:

- First wave prioritized one real shop VM restore, one real home restore, and one governed media restore proof set.
- `mail-archiver` already proved backup parity and offsite correctness in this wave, but not a scratch DB restore.
- The current DB artifact is large enough that it should be treated as a dedicated drill window, not a quick add-on.

Next action:

- Run the monthly `mail-archiver` restore drill as a dedicated wave using the latest `last-good` DB + uploads set.

## Final Backup Roots / Mount Points

### Shop / 730XD environment

- Shop primary VM/LXC source plane on `pve`: `/tank/backups/vzdump/dump/`
- Shop cold VM copy plane on `pve`: `/md1400/backup-cold/vzdump/pve/`
- Shop cold VM manifest root on `pve`: `/md1400/backup-cold/vzdump/pve/manifests/`
- Shop cold app plane on `pve`: `/md1400/backup-cold/apps/`
- Domain roots under the shop app plane:
  - `/md1400/backup-cold/apps/infra-core/`
  - `/md1400/backup-cold/apps/dev-tools/`
  - `/md1400/backup-cold/apps/mint-data/`
  - `/md1400/backup-cold/apps/finance/`
  - `/md1400/backup-cold/apps/communications/`
  - `/md1400/backup-cold/apps/media/`
- Archive-SMB snapshot manifest root on `pve`: `/md1400/backup-cold/archive-smb/snapshots/`

### Home environment

- Home runtime mount on `proxmox-home`: `/mnt/pve/synology-backups/dump/`
- Canonical home backup store on `nas`: `/volume1/backups/proxmox_backups/dump/`
- Confirmed home policy:
  - `home-vm-100-ha-primary` -> Synology
  - `home-lxc-105-pihole-primary` -> Synology

### Removed wrong-location home path

- No active home backup root remains under `/md1400/backup-cold/vzdump/home`
- `pve` cron residue check: `/etc/cron.d/home-vzdump-md1400-pull` is absent

## Residual Cleanup After Comfort Window

Do not delete immediately. Hold until you are comfortable with the green run history plus this restore-wave evidence.

### NAS legacy business backup residue

Legacy grace-mirror roots still present on `nas`:

- `/volume1/backups/apps/finance/`
- `/volume1/backups/apps/ghostfolio/`
- `/volume1/backups/apps/gitea/`
- `/volume1/backups/apps/infisical/`
- `/volume1/backups/apps/mail-archiver/`
- `/volume1/backups/apps/mint-postgres/`
- `/volume1/backups/apps/paperless/`
- `/volume1/backups/apps/stalwart/`
- `/volume1/backups/apps/vaultwarden/`

### NAS legacy shop exact-offsite residue

- `/volume1/backups/proxmox/vzdump/critical/`

### Legacy home / mint-os residue to review before delete

- `/volume1/backups/proxmox_backups/mint-os/`
- `/volume1/backups/proxmox_backups/mint-os/configs/`
- `/volume1/backups/proxmox_backups/mint-os/minio/`
- `/volume1/backups/proxmox_backups/mint-os/postgres/`
- `/volume1/backups/proxmox_backups/mint-os/strapi/`

Rule:

- Delete residue only after another comfort window of green `backup.status` runs and once you are satisfied the restore-wave receipts are sufficient.

## In-Scope Estate Notes

- Deprecated `vm-200-docker-host` remains intentionally out of the canonical protected estate.
- Large media payloads remain excluded by policy.
- Duplicate MinIO payload backups remain excluded by policy.
- Immich photo corpus remains on its separate photo-backup story.

## Canonical References

- `/Users/ronnyworks/code/agentic-spine/ops/bindings/backup.inventory.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/archive/bindings/backup.schedule.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/archive/bindings/backup.calendar.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/backup.posture.snapshot.yaml`
- `/Users/ronnyworks/code/agentic-spine/docs/contracts/BACKUP_730XD_CANONICAL_PATH_MAPPING.md`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SYNOLOGY_918_STORAGE_MANIFEST_V1.md`
