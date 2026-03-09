---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-09
scope: backup-script-audit-and-restore-wave
---

# Backup Script Audit and Restore Wave - 2026-03-09

## Scope

- Check active backup-script runtime surfaces
- Re-run Infisical scratch DB restore cleanly
- Run dedicated mail-archiver scratch restore wave
- Clean Synology NAS residue:
  - `/volume1/backups/apps/*`
  - `/volume1/backups/proxmox/vzdump/critical/`
- Review `/volume1/backups/proxmox_backups/mint-os/*`

## Backup Script Runtime Audit

Verified deployed runtime script surfaces:

| Host | Runtime surface | Evidence |
|---|---|---|
| `pve` | `/usr/local/bin/archive-smb-snapshot` | sha256 `de8a64105ffa...` |
| `pve` | `/usr/local/bin/vzdump-md1400-cold-sync.sh` | sha256 `653eec607d87...` |
| `communications-stack` | `/usr/local/bin/mail-archiver-backup.sh` | sha256 `8896383fb9af...` |
| `communications-stack` | `/usr/local/bin/stalwart-backup.sh` | sha256 `abcf285f9f54...` |
| `finance-stack` | `/usr/local/bin/finance-stack-backup.sh` | sha256 `f6bacb4b1b77...` |
| `infra-core` | `/usr/local/bin/infisical-backup.sh` | sha256 `d7c218058e92...` |
| `infra-core` | `/usr/local/bin/vaultwarden-backup.sh` | sha256 `e8c50b639a4c...` |
| `dev-tools` | `/usr/local/bin/gitea-backup.sh` | sha256 `ae2050c77f90...` |
| `mint-data` | `/usr/local/bin/mint-postgres-backup.sh` | sha256 `ba19d04150e1...` |
| `download-stack` | `/usr/local/bin/media-config-backup.sh` | sha256 `8b7db1e947dc...` |
| `streaming-stack` | `/usr/local/bin/media-config-backup.sh` | sha256 `8b7db1e947dc...` |

Verified canonical cron surfaces:

- `pve:/etc/cron.d/archive-smb-snapshot`
- `communications-stack:/etc/cron.d/communications-backups`
- `finance-stack` user crontab `20 6 * * * /usr/local/bin/finance-stack-backup.sh`
- `download-stack:/etc/cron.d/media-config-backup`
- `streaming-stack:/etc/cron.d/media-config-backup`
- `pve` home md1400 pull residue is absent (`/etc/cron.d/home-vzdump-md1400-pull` removed)

Notes:

- `n8n` backup artifact remains green in `backup.status`, but the direct runtime hash check on `automation-stack` did not return output in this wave.
- This is an audit residue, not current evidence of backup failure.

## Infisical Scratch Restore

Result: PASS

Source artifact:

- `pve:/md1400/backup-cold/apps/infra-core/infisical/infisical-db-2026-03-09T065001Z.sql.gz`

Scratch restore proof on `infra-core`:

- scratch DB existed: `db_exists=1`
- table count: `216`
- project count: `9`
- secret folder count: `55`
- audit log count: `0`

Cleanup:

- `infisical_drill` scratch DB dropped
- `/tmp/infisical-drill-restore.sql.gz` removed

Interpretation:

- Canonical Infisical backup artifact is restorable into scratch and yields real data structures.

## Mail-Archiver Scratch Restore

Result: NOT GREEN

Source artifacts:

- `/srv/mail-archiver/backups/last-good/mail-archiver-db-2026-03-08T030001Z.sql.gz`
- `/srv/mail-archiver/backups/last-good/mail-archiver-uploads-2026-03-08T030001Z.tar.gz`

Scratch restore observations on `communications-stack`:

- scratch DB existed: `db_exists=1`
- scratch DB public tables: `1`
- scratch DB `__EFMigrationsHistory` rows: `0`
- extracted uploads files: `0`
- restore log showed real SQL replay and reached `COPY 399`

Production comparison:

- production `__EFMigrationsHistory` rows: `13`
- live uploads file count: `0`

Interpretation:

- The dedicated scratch restore wave did not produce a clean parity proof for mail-archiver.
- Uploads parity appears acceptable (`0` files in both production and scratch extraction).
- Database parity is not acceptable yet: production shows `13` migration rows while the scratch restore produced `0`.
- This needs follow-up before mail-archiver can be called fully restore-proven.

Cleanup:

- `MailArchiver_drill` scratch DB dropped
- `/tmp/mail-archiver-uploads-drill` removed
- `/tmp/mail-archiver-drill-restore.log` removed

## NAS Residue Cleanup

Deleted on `nas`:

- `/volume1/backups/apps/*`
- `/volume1/backups/proxmox/vzdump/critical/`

Post-cleanup NAS state:

- `/volume1/backups/apps` -> `0`
- `/volume1/backups/proxmox/vzdump` -> `0`
- `/volume1` utilization -> `7.2T used / 13T free / 38%`

## Mint-OS Review

Reviewed but not deleted:

- `/volume1/backups/proxmox_backups/mint-os/minio/` -> `110G`
- `/volume1/backups/proxmox_backups/mint-os/postgres/` -> `146M`
- `/volume1/backups/proxmox_backups/mint-os/configs/` -> `392K`
- `/volume1/backups/proxmox_backups/mint-os/strapi/` -> `8K`

Observed characteristics:

- stale legacy residue from `2025-12` through `2026-01`
- not part of the current canonical Mint backup model
- MinIO duplicate payload backup remains explicitly excluded by policy

## Wave Verdict

- Backup runtime freshness: GREEN
- Backup script runtime surfaces: GREEN with minor `n8n` audit residue
- Infisical restore proof: GREEN
- Mail-archiver restore proof: RED
- NAS residue cleanup requested in this wave: COMPLETE
- Mint-os review requested in this wave: COMPLETE

## Required Follow-up

1. File/track the mail-archiver restore anomaly as an explicit backup-quality follow-up.
2. Re-run a narrower mail-archiver scratch restore with full parity checks before calling communications restore-proof green.
3. Decide whether to delete `/volume1/backups/proxmox_backups/mint-os/*`.
