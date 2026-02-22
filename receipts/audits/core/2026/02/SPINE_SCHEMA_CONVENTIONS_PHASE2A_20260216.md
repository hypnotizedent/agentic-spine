# Schema Conventions Phase 2A — Binding Notes Field Normalization

**Date:** 2026-02-16
**Loop:** LOOP-SPINE-SCHEMA-NORMALIZATION-20260216
**Phase:** 2A (safe config surfaces — `notes` → `description`)
**Executor:** Terminal C

## Summary

Renamed `notes` key to `description` in 7 binding files with zero reader impact.
No scripts access `.notes` programmatically from any of these files — all were
human-readable annotations only.

## Before / After

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Violations (full) | 37 | 30 | **-7** |
| Warnings (full) | 109 | 109 | 0 |
| Violations (gate mode, batch only) | 7 | 0 | **-7** |
| Core-8 gates | 8/8 PASS | 8/8 PASS | no change |
| AOF-12 gates | 12/12 PASS | 12/12 PASS | no change |

## Files Changed

| File | Occurrences Renamed | Reader Updates |
|------|-------------------|----------------|
| `ops/bindings/evidence.retention.policy.yaml` | 1 (`export.notes`) | none |
| `ops/bindings/naming.policy.yaml` | 9 (host entries) | none |
| `ops/bindings/rag.embedding.backend.yaml` | 2 (fallback candidates) | none |
| `ops/bindings/share.publish.allowlist.yaml` | 7 (allowed_paths entries) | none |
| `ops/bindings/startup.sequencing.yaml` | 1 (docker-host phase 4) | none |
| `ops/bindings/surface.readonly.contract.yaml` | 1 (spine_status surface) | none |
| `ops/bindings/deploy.dependencies.yaml` | 2 (chain entries) | none |

**Total:** 23 field renames across 7 files, 0 reader patches needed.

## Reader Impact Analysis

All reader scripts for these files were audited:
- `d96-evidence-retention-policy-lock.sh` — does not access `.notes`
- `d45-naming-consistency-lock.sh` — does not access `.notes`
- `rag-embedding-probe`, `rag-reindex-smoke` — do not access `.notes`
- `d82-share-publish-governance-lock.sh`, `share-publish-preview`, `share-publish-preflight` — do not access `.notes`
- `infra-post-power-recovery` — does not access `.notes`
- `d97-surface-readonly-contract-lock.sh`, `surface-readonly-audit` — do not access `.notes`
- `d51-caddy-proto-lock.sh` — does not access `.notes`

## Run Keys

| Capability | Run Key | Result |
|------------|---------|--------|
| stability.control.snapshot | `CAP-20260216-173239__stability.control.snapshot__Rve7s19458` | WARN (latency) |
| verify.core.run (pre) | `CAP-20260216-173347__verify.core.run__R499b23591` | 8/8 PASS |
| verify.domain.run aof (pre) | `CAP-20260216-173432__verify.domain.run__R1nnx35085` | 12/12 PASS |
| verify.core.run (post) | `CAP-20260216-173634__verify.core.run__R8wsl62007` | 8/8 PASS |
| verify.domain.run aof (post) | `CAP-20260216-173712__verify.domain.run__R6pxm72887` | 12/12 PASS |

## Residual Violations (30) — Phase 2B Candidates

### `notes` key (11 files remaining)

| File | Risk | Readers to Check |
|------|------|-----------------|
| `backup.inventory.yaml` | medium — has programmatic readers | backup caps |
| `cli.tools.inventory.yaml` | low | none known |
| `cloudflare.inventory.yaml` | low | cloudflare-agent |
| `docker.compose.targets.yaml` | medium — infra caps read this | deploy caps |
| `ha.areas.yaml` | medium — D120 reads this | D120 gate |
| `home.device.registry.yaml` | medium — D117 reads this | iot caps |
| `mailroom.bridge.endpoints.yaml` | low | mailroom bridge |
| `secrets.credentials.parity.yaml` | low | secrets audit |
| `secrets.inventory.yaml` | medium — secrets caps read this | secrets caps |
| `services.health.yaml` | high — stability.control reads this | stability caps |
| `spine.verify.runtime.yaml` | medium — verify reads this | verify infra |
| `vm.operating.profile.yaml` | high — vm caps read this | infra caps |
| `z2m.naming.yaml` | medium — D119 reads this | z2m gates |

*Excluded from Phase 2A: these files have programmatic readers that need `.notes` → `.description` patches.*

### `vmid` key (3 files)
- `home.device.registry.yaml`, `tenants/media-stack.yaml`, `vm.lifecycle.derived.yaml`, `vm.operating.profile.yaml`

### Non-canonical status values (6 violations)
- `infra.relocation.plan.yaml` (`migrated`)
- `media.services.yaml` (`stopped`)
- `network.home.baseline.yaml` (`installed`, `connected`)
- `operational.gaps.yaml` (`accepted`)
- `spine.verify.runtime.yaml` (`temporary`)
- `vm.lifecycle.yaml` (`stopped`, `template`)

## Notes

- Gate architecture files (`gate.registry.yaml`, `gate.execution.topology.yaml`) intentionally excluded per hard constraint.
- `operational.gaps.yaml`, `ssh.targets.yaml`, `vm.lifecycle.yaml` have legacy exceptions in the audit tool — not counted as violations.
- Warnings (109) are primarily `updated` key → `updated_at` renames, deferred to Phase 3+.
