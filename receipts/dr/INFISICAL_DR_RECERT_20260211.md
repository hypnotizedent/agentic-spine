---
type: dr-recertification
service: infisical
date: 2026-02-11
operator: "@ronny"
scope: procedure-certification
---

# Infisical DR Recertification — 2026-02-11

## Certification Type

**Procedure certification** — validates that a complete, executable restore drill
procedure exists, is consistent with existing backup/restore documentation, and
covers RTO/RPO validation.

This is NOT a live drill execution. Live drill evidence should be recorded separately
using the template in `INFISICAL_RESTORE_DRILL.md`.

## Artifacts Reviewed

| Artifact | Path | Status | Notes |
|----------|------|--------|-------|
| Backup/restore procedure | `docs/governance/INFISICAL_BACKUP_RESTORE.md` | CURRENT | last_verified: 2026-02-08, backup + restore + break-glass documented |
| DR runbook (Scenario 4) | `docs/governance/DR_RUNBOOK.md` | CURRENT | last_verified: 2026-02-08, isolate + assess + restore + rotate sequence |
| RTO/RPO objectives | `docs/governance/RTO_RPO.md` | CURRENT | last_verified: 2026-02-08, Infisical = Tier 1, RTO 2h, RPO 24h |
| Restore drill procedure | `docs/governance/INFISICAL_RESTORE_DRILL.md` | NEW | Created this session — 6-step quarterly drill with scratch DB isolation |
| Backup inventory binding | `ops/bindings/backup.inventory.yaml` | CURRENT | app-infisical target enabled, stale_after_hours=26 |
| Backup status capability | `backup.status` (plugin: backup) | OPERATIONAL | Monitors app-infisical freshness |
| Health probe | `services.health.status` | OPERATIONAL | Infisical endpoint monitored |
| Secrets project parity | `secrets.projects.status` | OPERATIONAL | Validates project count against SSOT |

## DR Readiness Assessment

### Backup Chain

| Layer | Mechanism | Frequency | Retention | Status |
|-------|-----------|-----------|-----------|--------|
| VM-level | vzdump on pve | Daily 02:00 | keep-last=2 | ACTIVE |
| App-level (DB) | pg_dump via cron | Daily 02:50 | 7 daily on NAS | ACTIVE |
| Offsite sync | rsync to NAS | Daily (post-dump) | Same as local | ACTIVE |

### Recovery Capabilities

| Capability | Documented | Tested | Notes |
|------------|-----------|--------|-------|
| Full DB restore from dump | YES (INFISICAL_BACKUP_RESTORE.md) | NO (drill pending) | First live drill not yet executed |
| Scratch DB drill procedure | YES (INFISICAL_RESTORE_DRILL.md) | NO (new) | Created this session |
| Break-glass access | YES (INFISICAL_BACKUP_RESTORE.md §4) | NOT VERIFIED | Cached creds + Vaultwarden fallback |
| Post-restore validation | YES (drill Step 4) | NO (drill pending) | Table count, project count, no errors |

### Known Gaps (from RTO_RPO.md)

| Gap ID | Description | Impact | Status |
|--------|-------------|--------|--------|
| BAK-05 | No offline bootstrap credentials | RTO undefined if infra-core + MacBook both lost | OPEN — not mitigated |
| BAK-03 | NAS has no offsite backup | RPO undefined if NAS destroyed | OPEN — not mitigated |

## Certification Result

| Criterion | Result |
|-----------|--------|
| Backup procedure documented | PASS |
| Restore procedure documented | PASS |
| Restore drill procedure exists | PASS (new: INFISICAL_RESTORE_DRILL.md) |
| Drill uses scratch DB isolation (no production risk) | PASS |
| RTO/RPO targets defined | PASS (2h / 24h) |
| Backup monitoring automated | PASS (backup.status capability) |
| Live drill executed | NOT YET — first live drill pending |
| Break-glass access verified | NOT YET — manual test pending |
| BAK-05 mitigated | FAIL — no offline bootstrap creds |
| BAK-03 mitigated | FAIL — NAS has no offsite |

**Overall: CONDITIONAL PASS** — procedure readiness certified. Two open gaps
(BAK-03, BAK-05) and no live drill execution yet.

## Next Actions

1. **Execute first live drill** using `INFISICAL_RESTORE_DRILL.md` — record results in a new receipt.
2. **Test break-glass access** — verify Vaultwarden contains current Infisical admin creds.
3. **Next recertification due**: 2026-05-11 (quarterly).

## Gap Registration

GAP-OP-112 registered in `ops/bindings/operational.gaps.yaml` for the missing
restore drill procedure and quarterly enforcement mechanism.
