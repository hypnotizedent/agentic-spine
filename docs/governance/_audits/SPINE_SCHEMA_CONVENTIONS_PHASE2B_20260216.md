# Schema Conventions Phase 2B — High-Risk Notes + vmid Normalization

**Date:** 2026-02-16
**Loop:** LOOP-SPINE-SCHEMA-NORMALIZATION-20260216
**Phase:** 2B (high-risk binding files with programmatic readers)
**Executor:** Terminal C

## Summary

Renamed `notes` → `description` in 3 high-risk binding files and `vmid` → `id` in 4 binding
files. Patched 7 reader scripts with `(.id // .vmid)` compatibility fallback. Updated
conventions schema to include `stopped`/`template` as valid VM lifecycle status values and
cleared the `vm.lifecycle.yaml` legacy exception.

## Before / After (Full Session: Phase 2A + 2B)

| Metric | Start of Session | After 2A | After 2B | Total Delta |
|--------|-----------------|----------|----------|-------------|
| Violations (full) | 37 | 30 | **22** | **-15** |
| Warnings (full) | 109 | 109 | **107** | **-2** |
| Violations (gate, batch) | — | 0 | **0** | — |
| Core-8 gates | 8/8 PASS | 8/8 PASS | 8/8 PASS | no change |
| AOF-12 gates | 12/12 PASS | 12/12 PASS | 12/12 PASS | no change |

## Batch B1: High-Risk `notes` → `description`

| File | Occurrences | Reader Updates |
|------|-------------|----------------|
| `ops/bindings/services.health.yaml` | 44 endpoint entries | none (no `.notes` readers) |
| `ops/bindings/vm.operating.profile.yaml` | 14 profile entries | none (no `.notes` readers) |
| `ops/bindings/vm.lifecycle.yaml` | 20 VM entries (touch-and-fix) | none (no `.notes` readers) |

**Reader impact analysis:** All consumers (stability-control-snapshot, d69, d86, vm-governance-audit, etc.) use `.notes` only as a shell variable name, never as a YAML field accessor.

## Batch B2: `vmid` → `id` with Compatibility Readers

### Binding Files Renamed

| File | Entries Renamed |
|------|----------------|
| `ops/bindings/vm.lifecycle.yaml` | 20 `vmid:` → `id:` |
| `ops/bindings/vm.lifecycle.derived.yaml` | 13 `vmid:` → `id:` |
| `ops/bindings/vm.operating.profile.yaml` | 14 `vmid:` → `id:` |
| `ops/bindings/tenants/media-stack.yaml` | 2 `vmid:` → `id:` (nested under `media.vms`) |

### Reader Scripts Patched (7 scripts, `(.id // .vmid)` fallback)

| Script | Lines Patched | Pattern |
|--------|--------------|---------|
| `surfaces/verify/d86-vm-operating-profile-parity-lock.sh` | 12 | `select((.id // .vmid) == $vmid)` |
| `surfaces/verify/d69-vm-creation-governance-lock.sh` | 1 | `.vms[$i] \| (.id // .vmid)` |
| `ops/plugins/vm/bin/vm-profile-audit` | 3 | `.profiles[$i] \| (.id // .vmid)` |
| `ops/plugins/vm/bin/vm-lifecycle-derived-check` | 2 | `(.vms[$i].id // .vms[$i].vmid)` + output template |
| `ops/plugins/vm/bin/vm-governance-audit` | 1 | `.vms[$i] \| (.id // .vmid)` |
| `ops/plugins/observability/bin/stability-control-snapshot` | 1 | `(.id // .vmid) // ""` |
| `ops/plugins/observability/bin/stability-control-reconcile` | 1 | `(.id // .vmid)` |

### Conventions Schema Updates

| Change | File |
|--------|------|
| Added `stopped`, `template` to `status_rules.allowed_values` | `spine.schema.conventions.yaml` |
| Cleared `vm.lifecycle.yaml` legacy exception (migration complete) | `spine.schema.conventions.yaml` |

## Run Keys

| Capability | Run Key | Result |
|------------|---------|--------|
| stability.control.snapshot | `CAP-20260216-174018__stability.control.snapshot__Rn8ez77541` | WARN (latency) |
| verify.core.run (pre) | `CAP-20260216-174048__verify.core.run__Rnozq80296` | 8/8 PASS |
| verify.domain.run aof (pre) | `CAP-20260216-174136__verify.domain.run__Rqgt8468` | 12/12 PASS |
| verify.core.run (post) | `CAP-20260216-174600__verify.core.run__R0e6a14033` | 8/8 PASS |
| verify.domain.run aof (post) | `CAP-20260216-174716__verify.domain.run__Rpqow27862` | 12/12 PASS |

## Files Changed (15 total)

**Binding files (6):**
- `ops/bindings/services.health.yaml` — `notes` → `description`
- `ops/bindings/vm.operating.profile.yaml` — `notes` → `description`, `vmid` → `id`
- `ops/bindings/vm.lifecycle.yaml` — `notes` → `description`, `vmid` → `id`
- `ops/bindings/vm.lifecycle.derived.yaml` — `vmid` → `id`
- `ops/bindings/tenants/media-stack.yaml` — `vmid` → `id`
- `ops/bindings/spine.schema.conventions.yaml` — added status values, cleared exception

**Reader scripts (7):**
- `surfaces/verify/d86-vm-operating-profile-parity-lock.sh`
- `surfaces/verify/d69-vm-creation-governance-lock.sh`
- `ops/plugins/vm/bin/vm-profile-audit`
- `ops/plugins/vm/bin/vm-lifecycle-derived-check`
- `ops/plugins/vm/bin/vm-governance-audit`
- `ops/plugins/observability/bin/stability-control-snapshot`
- `ops/plugins/observability/bin/stability-control-reconcile`

**Governance (2):**
- `docs/governance/_audits/SPINE_SCHEMA_CONVENTIONS_PHASE2B_20260216.md` (this file)

## Residual Violations (22) — Phase 2C+ Candidates

### `notes` key (8 files remaining)
- `backup.inventory.yaml`, `cli.tools.inventory.yaml`, `cloudflare.inventory.yaml`
- `docker.compose.targets.yaml`, `ha.areas.yaml`, `home.device.registry.yaml`
- `mailroom.bridge.endpoints.yaml`, `secrets.credentials.parity.yaml`
- `secrets.inventory.yaml`, `spine.verify.runtime.yaml`, `z2m.naming.yaml`

### `vmid` key (1 file remaining)
- `home.device.registry.yaml` — uses vmid in IoT context (not VM lifecycle)

### Non-canonical status values (6 violations)
- `infra.relocation.plan.yaml` (`migrated`)
- `media.services.yaml` (`stopped`)
- `network.home.baseline.yaml` (`installed`, `connected`)
- `operational.gaps.yaml` (`accepted`)
- `spine.verify.runtime.yaml` (`temporary`)

### Non-canonical lifecycle values (4 violations)
- `secrets.inventory.yaml` (`active`, `overloaded`, `overlaps`, `clean`, `clean_but_duped`)

## Scripts NOT Patched (out of scope — different context)

- `backup-vzdump-vmid-set` — operates on PVE jobs.cfg, not YAML bindings
- `media-status` — uses `vmid` as a local parameter variable
- `infra-placement-policy-check` — uses `vmid` as function argument, reads from placement policy
- `infra-vm-bootstrap`, `infra-vm-provision` — use `--vm-id` CLI flag, PVE API concept
- `home-backup-status` — hardcoded PVE vmid integers (100, 102)
- `d69:82-84` — reads `.vmid` from `SERVICE_REGISTRY.yaml` (separate file, not in scope)
- `d69:89,108` — uses `vmid` variable in vzdump glob and stack path patterns (Proxmox concept)
