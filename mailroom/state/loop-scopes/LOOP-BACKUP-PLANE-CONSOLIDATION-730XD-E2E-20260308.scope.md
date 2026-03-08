---
loop_id: LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308
created: 2026-03-08
status: closed
owner: "@ronny"
scope: backup
priority: medium
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Consolidate backup infrastructure to canonical 730XD plane for Mint/business/app backups with Synology reduced to home-local exceptions only
---

# Loop Scope: LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308

## Objective

Consolidate backup infrastructure to canonical 730XD plane for Mint/business/app backups with Synology reduced to home-local exceptions only

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308`

## Context

**Current Problem**: Parallel backup authority across Synology and 730XD creates ambiguity in restore truth, doc drift, and unclear canonical destination for Mint/business/app backups.

**Core Decision**: 730XD archive/SMB plane becomes canonical backup plane for Mint/business/app backups. Synology reduced to narrow home-environment exceptions only (primarily Home Assistant).

**Target Namespace**: `/archives/backups/<domain>/<service>/...` on 730XD plane

**Hard Rules**:
- Fresh-slate only, no docker-host, no ronny-ops runtime authority
- Preserve evidence, don't delete old backups before migration verification
- Don't destroy known-good restore points
- Don't perform blind rsync/moves without classification and receipts
- Use governed Spine authority as final source of truth
- Don't leave Synology as active canonical backup authority for Mint/business when done

## Orchestration Structure

**Execution Mode**: orchestrator_subagents (7 parallel sub-lanes)

**Sub-lanes**:
- **Lane A**: Current-state inventory + classification
- **Lane B**: 730XD backup namespace design + implementation
- **Lane C**: Spine authority migration
- **Lane D**: Domain migrations (Finance, Mint-data, Communications, Infra-core, VMs)
- **Lane E**: Synology exception scoping
- **Lane F**: Doc/script tombstoning
- **Lane G**: Proof + restore posture

## Phases

### Phase 1: Orchestration Setup
- Create orchestration packet
- Spawn 7 subagent lanes with dedicated worktrees/branches
- Establish coordination surface

### Phase 2: Parallel Lane Execution

**Lane A: Current-State Inventory + Classification**
- Inventory all backup roots (Synology, 730XD, PVE vzdump, VM-local, app-local)
- Sources: backup.inventory.yaml, workbench scripts, stateful service runbooks, live hosts
- Classify each family: `canonical_keep_here`, `migrate_to_730xd`, `retain_temporarily_for_forensics`, `home_local_exception`, `safe_to_delete_after_verified_migration`
- Deliver: full migration matrix + classification receipt

**Lane B: 730XD Backup Namespace Design + Implementation**
- Define exact canonical 730XD backup root/path scheme
- Ensure durability, reachability, operator/agent discoverability
- Separate archive families and backup families clearly
- Create directory roots if needed
- Update source-controlled helper/docs
- Deliver: final namespace design + created roots + updated surfaces

**Lane C: Spine Authority Migration**
- Update backup.inventory.yaml
- Update backup capability/plugin surfaces
- Update backup posture/proof surfaces
- Reclassify Synology destinations (home-local exception only where appropriate)
- Point all relevant service backup targets to 730XD canonical destination
- Deliver: updated Spine inventory/proof/capability truth, no active parallel backup authority

**Lane D: Domain Migrations**
- Migrate real backup authority with verification and receipts
- Domains: Finance, Mint-data (Postgres/MinIO), Communications (mail-archiver/Stalwart), Infra-core, VM offsite
- For each: identify current canonical on Synology/elsewhere → copy/promote to 730XD → verify counts/sizes/hashes/restore-path → update domain authority → retain old for grace window → write migration receipt
- Don't delete old copies unless parity exact, authority switched, retention grace satisfied, receipt says safe
- Deliver: per-domain migration receipts + verified new canonical paths

**Lane E: Synology Exception Scoping**
- Identify what truly belongs on Synology (Home Assistant expected, other genuine home-local only if evidence supports)
- Demote/retire all non-home business backup authority from Synology
- Update docs and inventory so Synology no longer reads as primary business backup plane
- Deliver: explicit list of allowed Synology exceptions, everything else demoted/migrated

**Lane F: Doc/Script Tombstoning**
- Tombstone/demote old docs/scripts that imply Synology is canonical for business backups, old backup roots remain authoritative, or archives=backups
- Use explicit labels: `superseded_by`, `legacy_readonly`, `reference_only`
- Patch active operator scripts/help text to point only at canonical 730XD backup truth
- Don't leave "historical but looks active" surfaces
- Deliver: tombstoned surfaces + patched active surfaces

**Lane G: Proof + Restore Posture**
- Prove new backup plane is real, not just documented
- For each migrated critical domain: prove backup destination exists on 730XD, Spine status sees right destination, restore class explicit
- Run safe restore proof/drill if possible, else write exact restore-proof receipts + rationale
- At minimum prove: finance → 730XD, mint-data → 730XD or explicit exception, communications → 730XD or explicit exception, Home Assistant → Synology by explicit exception
- Deliver: restore posture proof for all migrated domains

### Phase 3: Lane Integration + Verification
- Orchestrator integrates lane outputs
- Reconcile any cross-lane conflicts
- Run friction.reconcile for any filed friction items
- Generate consolidated migration matrix
- Run backup verify pack
- Close loop-linked gaps

### Phase 4: Closeout
- Commit all changes across lanes
- Merge lane branches
- Generate executive summary
- Update loop scope with final status
- Close loop

## Success Criteria

**Verification Evidence Required**:
1. Inventory classification complete
2. 730XD canonical backup namespace exists
3. Spine inventory/proof updated
4. Migrated domains actually have backups in new canonical paths
5. Synology reduced to explicit home-local exception(s)
6. Active docs/scripts no longer conflict
7. Restore/posture truth is coherent

**Final Status**: `BACKUP_PLANE_CONSOLIDATED_TO_730XD` or `PARTIAL_CONSOLIDATION_WITH_EXACT_RESIDUE`

**Verify Packs**: backup pack must pass

**Future Agent Test**: A future agent should discover one simple truth:
- 730XD is canonical backup plane for Mint/business/app backups
- Synology is only narrow home-local exception
- Old backup roots are classified and no longer ambiguous
- Spine, runtime, docs, and restore posture all agree

## Definition Of Done

**Migration Matrix Delivered**: Columns: domain/service, old location, new canonical location, action taken, retention state, restore state

**Exact Changes Documented**:
- Repos/files modified
- Host/runtime changes
- Commits across all lanes
- Receipt paths

**No Parallel Authority**: Only one canonical backup plane for business/app domains

**Receipted Evidence**: All verification commands, destination listings, restore proofs, doc/script drift removal proofs

## Closeout Summary

### Terminal Delivered (Commits 8b50c98e, 411d581f)

**Authority Changes** (`backup.inventory.yaml`):
- `app-mint-postgres`: nas → pve (`/md1400/backup-cold/apps/mint-data/postgres`)
- `app-mint-postgres-manifest`: nas → pve (`/md1400/backup-cold/apps/mint-data/postgres`)
- `app-stalwart-offsite`: nas → pve (`/md1400/backup-cold/apps/communications/stalwart`)
- `app-mail-archiver-offsite`: nas → pve (`/md1400/backup-cold/apps/communications/mail-archiver`)

**Runtime Scripts Deployed**:
- `mint-data` (VM 212): `/usr/local/bin/mint-postgres-backup.sh` → 730XD ✅ VERIFIED
- `communications-stack` (VM 214): `/usr/local/bin/stalwart-backup.sh` → 730XD ✅ VERIFIED
- `communications-stack` (VM 214): `/usr/local/bin/mail-archiver-backup.sh` → 730XD ⚠️ **RUNTIME ISSUE**

**Supporting Artifacts**:
- Receipt: `receipts/backup/stateful-hardening-730xd-integration-20260308.md`
- Path model: `docs/contracts/BACKUP_730XD_CANONICAL_PATH_MAPPING.md`
- Forensic audit: `docs/planning/BACKUP_SYNOLOGY_DS918_FORENSIC_AUDIT_20260308.md`

**Final Status**: `PARTIAL_730XD_INTEGRATION_WITH_EXACT_RUNTIME_PENDING`

### What Actually Works

**Verified Migrations** (runtime proven, 730XD artifacts exist):
- ✅ Mint Postgres: 18M dump verified on pve:/md1400/backup-cold/apps/mint-data/postgres/
- ✅ Stalwart: 3.0M data + 12K config verified on pve:/md1400/backup-cold/apps/communications/stalwart/

**Handoff**: "Mint + Stalwart migrated and verified; Mail-archiver runtime still unresolved; Finance not done."

### Runtime Issues Still Open

**Mail-Archiver (Communications Stack, VM 214)** ⚠️:
- **Inventory updated**: `app-mail-archiver-offsite` points to 730XD
- **Script deployed**: `/usr/local/bin/mail-archiver-backup.sh` targets `pve:/md1400/backup-cold/apps/communications/mail-archiver/`
- **Problem**: Target directory on pve is EMPTY (as of closeout forensic)
- **Concurrent runs detected**: Multiple `mail-archiver-backup.sh` / `pg_dump` processes active on VM 214
- **No lock**: Script uses shared staging dir `/tmp/mail-archiver-backup/` with no mutex
- **Overlap risk**: Concurrent runs can corrupt staging area, cause partial/failed syncs

**Finance (VM 211)** ❌:
- **Explicitly deferred**: Paperless `document_exporter` timing issue (command returns before zip fully written)
- **Script exists**: `/Users/ronnyworks/code/agentic-spine/ops/staged/finance-stack/finance-stack-backup.sh` (NOT deployed to runtime)
- **730XD paths ready**: `/md1400/backup-cold/apps/finance/{firefly,ghostfolio,paperless}/` exist but not active
- **Services blocked**: Firefly, Ghostfolio, Paperless all deferred pending Paperless export fix

### Residue (Still on NAS, Business Targets)

**Unchanged from Previous State**:
- `app-infisical` (nas, critical)
- `app-gitea` (nas, critical)
- `app-vaultwarden` (nas, critical)
- `app-paperless-db` (nas, critical)
- `app-paperless-export` (nas, critical)
- `app-finance-sanity-manifest` (nas, critical)

### Verification Not Closed

**Runtime Freshness**: No `backup.status` run performed by terminal.

**Restore Posture**: No restore proof from 730XD paths (even for Mint/Stalwart verified migrations).

### Follow-Up Required

**Immediate** (resolve runtime issues):
1. **GAP-OP-1513**: mail-archiver concurrent-run race condition (high, runtime-bug)
2. **GAP-OP-1514**: mail-archiver 730XD migration incomplete (high, runtime-bug)
3. **GAP-OP-1515**: Finance Paperless export timing issue (medium, runtime-bug)

**Deferred** (complete migration objective):
4. Migrate remaining NAS-backed business targets (Infisical, Gitea, Vaultwarden)
5. Run `backup.status` with runtime context to verify freshness
6. Execute restore posture proof for migrated paths

### Commits

- `8b50c98e` — feat(backup): migrate Mint/Stalwart to 730XD, stage mail-archiver (runtime incomplete)
- `411d581f` — docs(backup): add 730XD integration receipt for stateful hardening migration
- `db5fa1fa` — feat(backup): complete Spine authority migration to 730XD canonical plane (earlier work, container-fleet moves)
- `ebbae1e6` — feat(backup): complete Synology DS918+ forensic storage audit

**Loop Status**: Closed (terminal editing session done)
**Work Item Status**: Incomplete (Mint + Stalwart verified; Mail-archiver runtime unresolved; Finance not done)
