# Mint Stateful Safety and Backup Posture - 2026-03-08

## Scope

Critical stateful services and recovery surfaces reviewed in this lane:

- Paperless
- Firefly
- Ghostfolio
- Vaultwarden
- Infisical
- Gitea
- MinIO
- Mail-archiver / Stalwart
- archive-smb dataset protection
- Proxmox VM/LXC backup and 730XD offsite plane

## Outcome

This report was corrected after operator review found that backup posture had been overstated green.

The red items were:

- `mail-archiver` 730XD offsite directory was still empty and [GAP-OP-1513](/Users/ronnyworks/code/agentic-spine/ops/bindings/operational.gaps.yaml#L24504) / [GAP-OP-1514](/Users/ronnyworks/code/agentic-spine/ops/bindings/operational.gaps.yaml#L24518) were still open.
- `archive-smb` inventory described daily auto snapshots before runtime actually had a scheduler.
- `app-finance-sanity-manifest` was still disabled and pointed at NAS instead of the live `pve` 730XD finance plane.

Corrective work applied in this lane:

- Finance stack backup governance now points the sanity manifest at `pve:/md1400/backup-cold/apps/finance` and leaves the finance/Paperless backup lane canonical.
- `mail-archiver` runtime is normalized onto `/etc/cron.d/communications-backups` as root, user crontab residue is removed, `/usr/local/bin/mail-archiver-backup.sh` is redeployed from the hardened staged version, and the March 8 retained-doc artifact set is re-proved on the canonical 730XD path with exact byte parity.
- `archive-smb` now has real runtime automation on `pve`: `/etc/cron.d/archive-smb-snapshot`, live `auto-daily-*` ZFS snapshots, and snapshot manifest output under `/md1400/backup-cold/archive-smb/snapshots/`.
- Paperless runtime on `finance-stack` remains corrected and re-proved, with the retained-doc queue drained and duplicate residue preserved in quarantine instead of deleted.
- Canonical proof for the backup lane now comes from service-specific receipts and host checks. The broad `backup.status` inventory probe remains context-blocked for many Tailscale-only surfaces from this terminal and should not be used as the sole source for this closeout.

## Primary Receipts

- Finance backup run: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-115516__finance.backup.run__Rt9zn42416/receipt.md`
- Finance backup status: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-131733__finance.backup.status__Rklev2872/receipt.md`
- Context-blocked inventory snapshot: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-182722__backup.status__Run7786824/receipt.md`
- Vzdump schedule/status: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-114501__backup.vzdump.status__Rga4s26918/receipt.md`
- Vaultwarden backup verify: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-112748__vaultwarden.backup.verify__R7eig84781/receipt.md`
- Paperless compose sync: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-142847__secrets.exec__R0xsa82989/receipt.md`
- Paperless governed restart: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-142905__docker.compose.up__R5tdd89755/receipt.md`
- Post-restart finance-stack health: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-143123__services.health.status__Rj5ye46053/receipt.md`
- archive-smb cron + first auto snapshots: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-175421__secrets.exec__Rs85s37786/receipt.md`
- archive-smb manifest-writing runtime sync: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-183146__secrets.exec__Rk61353428/receipt.md`
- mail-archiver offsite transport proof (uploads + manifest): `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-182507__secrets.exec__Rqnsf48984/receipt.md`
- mail-archiver March 8 DB offsite sync: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-182536__secrets.exec__Rbcld60272/receipt.md`
- mail-archiver runtime script redeploy: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-183208__secrets.exec__Rg00q56220/receipt.md`
- mail-archiver final canonical status proof: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-190643__communications.mailarchiver.backup.status__Rf2cg54654/receipt.md`

## Hardened Files

- `/Users/ronnyworks/code/agentic-spine/ops/staged/finance-stack/finance-stack-backup.sh`
- `/Users/ronnyworks/code/agentic-spine/ops/staged/pve/vzdump-offsite-sync.sh`
- `/Users/ronnyworks/code/agentic-spine/ops/staged/pve/archive-smb-snapshot.sh`
- `/Users/ronnyworks/code/agentic-spine/ops/staged/communications-stack/mail-archiver-backup.sh`
- `/Users/ronnyworks/code/agentic-spine/ops/staged/infra-core/infisical-backup.sh`
- `/Users/ronnyworks/code/agentic-spine/ops/staged/dev-tools/gitea-backup.sh`
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/backup/bin/archive-smb-snapshot`
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/finance/bin/finance-backup-run`
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/finance/bin/finance-backup-status`
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/communications/bin/communications-mail-archiver-backup-status`
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/vaultwarden/bin/vaultwarden-backup-verify`
- `/Users/ronnyworks/code/workbench/infra/compose/finance/docker-compose.yml`

## Governance / Doctrine Alignment

- `/Users/ronnyworks/code/agentic-spine/docs/governance/FINANCE_STACK_DOCTRINE_V1.md`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/FINANCE_STACK_OPERATOR_CHECKLIST.md`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SYNOLOGY_918_STORAGE_MANIFEST_V1.md`
- `/Users/ronnyworks/code/agentic-spine/ops/archive/bindings/backup.schedule.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/backup.inventory.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/archive/bindings/mail.archiver.backup.contract.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/synology918.storage.manifest.yaml`

## Restore / Safety Notes

- Finance stack state is on VM 211 persistent volumes and is preserved across restart/redeploy.
- Paperless restart/redeploy proof is current: compose sync + `docker.compose.up` + green `services.health.status` receipt after the runtime correction.
- Paperless retained-doc queue drained to zero after the governed runtime correction; duplicate backfill residue was preserved in quarantine (`172` PDFs) rather than deleted.
- Mail-archiver now has one canonical discoverable path: local `last-good` recovery point on VM 214 plus canonical 730XD offsite under `/md1400/backup-cold/apps/communications/mail-archiver/`.
- archive-smb dataset protection is now concrete at runtime: cron-driven ZFS snapshots plus manifest receipts on `pve`, matching the backup inventory target that discovers `/md1400/backup-cold/archive-smb/snapshots/archive-smb-snapshot-*.txt`.
- `backup.status` from this terminal should be read as a context probe, not a correctness oracle. Its 2026-03-08 receipt is preserved to show why service-specific proof was used for the final closure.
- Paperless incident root-cause and restore decision records remain preserved:
  - `/Users/ronnyworks/code/agentic-spine/mailroom/state/paperless-backup-incident/root-cause-receipt-20260308.md`
  - `/Users/ronnyworks/code/agentic-spine/mailroom/state/paperless-backup-incident/finance-restore-decision-receipt-20260308.md`
