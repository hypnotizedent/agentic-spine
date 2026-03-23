# Shop Backup Doc Sprawl Reduction

**Date**: 2026-03-23
**Wave**: LOOP-SHOP-STORAGE-CUTOVER-20260322

## Files Updated (commit 024b978c)

| File | Change | Tank refs fixed |
|------|--------|-----------------|
| `docs/governance/domains/backup.md` | tank→data in canonical model | 1 |
| `docs/contracts/BACKUP_730XD_CANONICAL_PATH_MAPPING.md` | Pool 1 description, migration path | 3 |
| `ops/plugins/infra/bin/infra-vm-intake-scaffold` | BACKUP_BASE path | 1 |
| `ops/plugins/infra/backup/bin/backup-vzdump-status` | listing path + VMID list | 4 |
| `ops/plugins/infra/backup/bin/backup-status` | comparison path (data-first, tank fallback) | 1 |

## Files Still Containing tank/backups (not yet fixed)

| File | Status | Reason |
|------|--------|--------|
| `ops/bindings/shop.storage.map.yaml` | Generated | Will regenerate via `infra.shop.storage.authority.build` |
| `ops/bindings/service.data.lifecycle.projected.yaml` | Generated | Will regenerate |
| `ops/bindings/home.storage.map.yaml` | Generated | Will regenerate |
| `ops/bindings/backup.posture.snapshot.yaml` | Generated | Will regenerate via `backup.posture.snapshot.build` |
| `ops/bindings/operational.gaps.yaml` | Historical | Gap descriptions reference tank as context |
| `docs/runbooks/mint/MINT_FRESH_SLATE_INFRA_BOOTSTRAP_RUNBOOK.md` | Runbook | Example paths, low impact |
| `ops/plugins/infra/bin/infra-shop-storage-authority-build` | Build script | object_id is descriptive |

## Canonical Narrative Count

**Before**: 2 competing narratives (inventory said `/data`, domain doc said `/tank`)
**After**: 1 canonical narrative — `backup.inventory.yaml` is the root, all docs align to `/data`

## Recommended Follow-up

1. Regenerate projections: `backup.posture.snapshot.build`, `infra.shop.storage.authority.build`
2. Update Mint runbook example paths (low priority)
3. Archive `BACKUP_730XD_CANONICAL_PATH_MAPPING.md` as historical after next verify cycle
