# Mint Stateful Safety and Backup Posture - 2026-03-08

## Scope

Critical stateful services reviewed in this lane:

- Paperless
- Firefly
- Ghostfolio
- Vaultwarden
- Infisical
- Gitea
- MinIO
- Proxmox VM backup/offsite plane

## Outcome

Stateful backup posture is materially hardened and re-proved.

- Finance stack backup scripts now cover Paperless/Firefly/Ghostfolio with fresh receipts.
- Paperless runtime contract on finance-stack was corrected and redeployed through governed Spine surfaces so restart preserves state while using doc-backed OCR/worker settings.
- Proxmox vzdump and offsite sync evidence is current.
- Vaultwarden backup verification is current.
- Infisical/Gitea/Stalwart backup/restore governance docs were refreshed in the same lane.
- The canonical doctrine now states that retained invoices live in Paperless and MinIO is artwork-only for active Mint usage.

## Primary Receipts

- Finance backup run: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-115516__finance.backup.run__Rt9zn42416/receipt.md`
- Finance backup status: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-131733__finance.backup.status__Rklev2872/receipt.md`
- Canonical backup status: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-120155__backup.status__Rx6az77684/receipt.md`
- Vzdump schedule/status: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-114501__backup.vzdump.status__Rga4s26918/receipt.md`
- Vaultwarden backup verify: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-112748__vaultwarden.backup.verify__R7eig84781/receipt.md`
- Paperless compose sync: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-142847__secrets.exec__R0xsa82989/receipt.md`
- Paperless governed restart: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-142905__docker.compose.up__R5tdd89755/receipt.md`
- Post-restart finance-stack health: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-143123__services.health.status__Rj5ye46053/receipt.md`

## Hardened Files

- `/Users/ronnyworks/code/agentic-spine/ops/staged/finance-stack/finance-stack-backup.sh`
- `/Users/ronnyworks/code/agentic-spine/ops/staged/pve/vzdump-offsite-sync.sh`
- `/Users/ronnyworks/code/agentic-spine/ops/staged/infra-core/infisical-backup.sh`
- `/Users/ronnyworks/code/agentic-spine/ops/staged/dev-tools/gitea-backup.sh`
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/finance/bin/finance-backup-run`
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/finance/bin/finance-backup-status`
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/vaultwarden/bin/vaultwarden-backup-verify`
- `/Users/ronnyworks/code/workbench/infra/compose/finance/docker-compose.yml`

## Governance / Doctrine Alignment

- `/Users/ronnyworks/code/agentic-spine/docs/governance/FINANCE_STACK_DOCTRINE_V1.md`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/FINANCE_STACK_OPERATOR_CHECKLIST.md`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SYNOLOGY_918_STORAGE_MANIFEST_V1.md`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/backup.inventory.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/synology918.storage.manifest.yaml`

## Restore / Safety Notes

- Finance stack state is on VM 211 persistent volumes and is preserved across restart/redeploy.
- Paperless restart/redeploy proof is current: compose sync + `docker.compose.up` + green `services.health.status` receipt after the runtime correction.
- Paperless retained-doc queue drained to zero after the governed runtime correction; duplicate backfill residue was preserved in quarantine (`172` PDFs) rather than deleted.
- Offsite copy and restore-aware posture are tracked through the backup receipts above.
- Paperless incident root-cause and restore decision records remain preserved:
  - `/Users/ronnyworks/code/agentic-spine/mailroom/state/paperless-backup-incident/root-cause-receipt-20260308.md`
  - `/Users/ronnyworks/code/agentic-spine/mailroom/state/paperless-backup-incident/finance-restore-decision-receipt-20260308.md`
