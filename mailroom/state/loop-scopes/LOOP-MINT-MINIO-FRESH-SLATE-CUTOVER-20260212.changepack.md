# Change Pack: MinIO Fresh-Slate Cutover

## Change Description

| Field | Value |
|------|-------|
| Change ID | LOOP-MINT-MINIO-FRESH-SLATE-CUTOVER-20260212 |
| Date | 2026-02-12 |
| Owner | @ronny |
| What | Establish storage stack as single canonical MinIO source; remove conflicting authority from mint-os compose; decouple mint-modules from legacy mint-os app stack |
| Why | Two compose files define MinIO with divergent configs; docker.compose.targets notes contradict SERVICE_REGISTRY; mint-modules has implicit legacy coupling |
| Downtime window | 0 min (SSOT/template changes only — no container restarts in this loop) |
| Rollback strategy | Revert commits on main |

## IP Map

Software-only cutover — no IP changes, no container restarts.

| Service | Host | IP | Port | Change |
|---------|------|----|------|--------|
| minio | docker-host | 192.168.1.200 | 9000/9001 | No runtime change — SSOT authority fix only |

## Rollback Map

| Artifact | Rollback Action | Source |
|----------|----------------|--------|
| docker.compose.targets.yaml | `git revert <commit>` | Main branch |
| SERVICE_REGISTRY.yaml | `git revert <commit>` | Main branch |
| workbench storage compose | `git revert <commit>` | Workbench repo |
| workbench mint-os compose | `git revert <commit>` | Workbench repo |

## Pre-Cutover Verification Matrix

| Check | Method | Result |
|-------|--------|--------|
| spine.verify | `./bin/ops cap run spine.verify` | PENDING (D53 expected to fail until changepack created) |
| ops status | `./bin/ops status` | 1 loop (this one), 0 gaps |
| docker.compose.status | `./bin/ops cap run docker.compose.status` | PENDING |
| services.health.status | `./bin/ops cap run services.health.status` | PENDING |

## Cutover Sequence

1. Create changepack (this file) to satisfy D53
2. Fix `docker.compose.targets.yaml` — remove "MinIO deprecated" from notes, add storage stack path
3. Fix `SERVICE_REGISTRY.yaml` — update compose path to storage stack canonical
4. Fix workbench `storage/docker-compose.yml` — correct volume path to match live NFS
5. Remove duplicate MinIO service from workbench `mint-os/docker-compose.yml`
6. Update mint-modules deploy docs/comments to reference storage stack (not mint-os)
7. Verify secrets namespace alignment in spine bindings
8. Run full recertification (verify + health + compose status)
9. Commit and close loop

## LAN-Only Devices

No LAN-only device changes. All changes are repo-level SSOT fixes.

## Post-Cutover Verification Matrix

| Check | Method | Expected |
|-------|--------|----------|
| spine.verify | `./bin/ops cap run spine.verify` | ALL PASS (D1-D71) |
| docker.compose.status | `./bin/ops cap run docker.compose.status` | Same as baseline (no runtime changes) |
| services.health.status | `./bin/ops cap run services.health.status` | minio OK |
| No stale deprecated refs | `rg "MinIO.*deprecated" ops/bindings/` | 0 matches |
| Single canonical compose | SERVICE_REGISTRY minio.compose | Points to storage stack |

## Sign-Off

| Role | Name | Date | Status |
|------|------|------|--------|
| Operator | @ronny (via Claude Opus 4.6) | 2026-02-12 | PENDING |
