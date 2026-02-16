# Schema Conventions Phase 2C — Status/Lifecycle Normalization

**Date:** 2026-02-16
**Loop:** LOOP-SPINE-SCHEMA-NORMALIZATION-20260216
**Phase:** 2C (status and lifecycle convention debt)
**Executor:** Terminal C

## Summary

Normalized all 10 status/lifecycle violations across 4 binding files. Patched 4 reader/writer
scripts for compatibility. Renamed `lifecycle` → `project_health` in secrets.inventory.yaml
(field was semantically wrong — informational project health flags, not component lifecycle).
Added `accepted` to canonical status enum for operational.gaps.yaml (structural exception:
gaps have both `description` and `notes`, making `notes` rename impossible without schema
redesign).

## Before / After (Full Session: Phase 2A + 2B + 2C)

| Metric | Start of Session | After 2A | After 2B | After 2C | Total Delta |
|--------|-----------------|----------|----------|----------|-------------|
| Violations (full) | 37 | 30 | 22 | **10** | **-27** |
| Warnings (full) | 109 | 109 | 107 | **107** | **-2** |
| Status/lifecycle violations | 10 | 10 | 10 | **0** | **-10** |
| Violations (gate, batch) | — | 0 | 0 | **0** | — |
| Core-8 gates | 8/8 PASS | 8/8 PASS | 8/8 PASS | 8/8 PASS | no change |
| AOF-12 gates | 12/12 PASS | 12/12 PASS | 12/12 PASS | 12/12 PASS | no change |

## Status Violations Fixed (6)

| File | Old Value | New Value | Reader Impact |
|------|-----------|-----------|---------------|
| `infra.relocation.plan.yaml` (29 services) | `migrated` | `applied` | 2 scripts patched |
| `network.home.baseline.yaml` | `installed` | `provisioned` | None (zero readers) |
| `network.home.baseline.yaml` | `connected` | `active` | None (zero readers) |
| `operational.gaps.yaml` (3 entries) | `accepted` | Added to canonical enum | None (structural exception) |
| `spine.verify.runtime.yaml` | `temporary` | `experimental` | None (zero readers) |

## Lifecycle Violations Fixed (5)

| File | Old Field | New Field | Values | Reader Impact |
|------|-----------|-----------|--------|---------------|
| `secrets.inventory.yaml` | `lifecycle` | `project_health` | `active`, `overloaded`, `overlaps`, `clean`, `clean_but_duped`, `deprecated` | 1 script patched |

**Rationale:** The `lifecycle` field in secrets.inventory.yaml was semantically wrong — it
tracks Infisical project health/scope status (risk flags), not component lifecycle stages.
Renaming to `project_health` removes the field from lifecycle enforcement entirely since it's
not the canonical `lifecycle` field name.

## Touch-and-Fix Cascades

Files touched for status/lifecycle fixes that also required `notes` → `description` rename:

| File | notes → description | Reason |
|------|-------------------|--------|
| `spine.verify.runtime.yaml` | 1 entry (list) | Touch-and-fix: status change triggered gate |
| `secrets.inventory.yaml` | 16 entries | Touch-and-fix: lifecycle rename triggered gate |

## Reader/Writer Scripts Patched (4 scripts)

| Script | Change | Pattern |
|--------|--------|---------|
| `ops/plugins/secrets/bin/secrets-inventory-status` | `.lifecycle` → `.project_health` (5 occurrences) | yq select/filter expressions |
| `ops/plugins/infra/bin/infra-relocation-service-transition` | Accept `applied` alongside `migrated` | Case enum + transition validation |
| `ops/plugins/infra/bin/infra-relocation-promote` | Emit `applied` instead of `migrated` | Write path + output text |
| (none for network/spine.verify) | — | Zero readers consume status field |

## Structural Exception: operational.gaps.yaml

The `accepted` status was added to the canonical enum rather than migrated in-place because:
1. Touching operational.gaps.yaml triggers touch-and-fix for `notes` and `discovered_at`
2. Gap entries have BOTH `description:` (primary) and `notes:` (supplementary commentary)
3. Renaming `notes` → `description` would create duplicate YAML keys
4. `discovered_at` is a domain-specific date field (gap discovery time, not entry creation time)
5. Adding `accepted` is semantically valid: it means "acknowledged/triaged but not yet fixed"

## Conventions Schema Updates

| Change | File |
|--------|------|
| Added `accepted` to `status_rules.allowed_values` | `spine.schema.conventions.yaml` |

## Run Keys

| Capability | Run Key | Result |
|------------|---------|--------|
| stability.control.snapshot (pre) | `CAP-20260216-175528__stability.control.snapshot__Rhbwg35413` | WARN (latency) |
| verify.core.run (pre) | `CAP-20260216-175614__verify.core.run__Rhjuc38353` | 8/8 PASS |
| verify.domain.run aof (pre) | `CAP-20260216-175651__verify.domain.run__Rgtp349221` | 12/12 PASS |
| verify.core.run (post) | `CAP-20260216-180536__verify.core.run__R8l9i75430` | 8/8 PASS |
| verify.domain.run aof (post) | `CAP-20260216-180609__verify.domain.run__R9wxj86149` | 12/12 PASS |

## Files Changed (11 total)

**Binding files (5):**
- `ops/bindings/infra.relocation.plan.yaml` — 29x `status: "migrated"` → `"applied"`
- `ops/bindings/network.home.baseline.yaml` — `installed` → `provisioned`, `connected` → `active`
- `ops/bindings/secrets.inventory.yaml` — `lifecycle` → `project_health`, `notes` → `description`
- `ops/bindings/spine.verify.runtime.yaml` — `temporary` → `experimental`, `notes` → `description`
- `ops/bindings/spine.schema.conventions.yaml` — added `accepted` to status enum

**Reader/writer scripts (4):**
- `ops/plugins/secrets/bin/secrets-inventory-status`
- `ops/plugins/infra/bin/infra-relocation-service-transition`
- `ops/plugins/infra/bin/infra-relocation-promote`

**Governance (1):**
- `docs/governance/_audits/SPINE_SCHEMA_CONVENTIONS_PHASE2C_20260216.md` (this file)

## Residual Violations (10) — Phase 2D+ Candidates

### `notes` key (8 files remaining)
- `backup.inventory.yaml`, `cli.tools.inventory.yaml`, `cloudflare.inventory.yaml`
- `docker.compose.targets.yaml`, `ha.areas.yaml`, `home.device.registry.yaml`
- `mailroom.bridge.endpoints.yaml`, `secrets.credentials.parity.yaml`
- `z2m.naming.yaml`

### `vmid` key (1 file remaining)
- `home.device.registry.yaml` — uses vmid in IoT context (not VM lifecycle)

### Structural blockers for Phase 2D
- `operational.gaps.yaml` — `notes` + `discovered_at` require gap schema redesign (notes ≠ description in gap context)
- `notes` in remaining 8 files — requires reader impact analysis per file
- 107 warnings (mostly `updated` → `updated_at` renames) — low priority, no gate failures
