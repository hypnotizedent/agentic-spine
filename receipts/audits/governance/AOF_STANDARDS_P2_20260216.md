# AOF Standards Pack v1 — Phase P2

**Date:** 2026-02-16
**Standards:** STD-004, STD-005, STD-008
**Executor:** Terminal C

## Scope

- STD-004 / D131: Catalog freshness enforcement
- STD-005 / D132: Mutation atomicity enforcement
- STD-008 / D134: Topology metadata quality enforcement

## Run Keys

| Capability | Run Key | Result |
|------------|---------|--------|
| stability.control.snapshot (pre) | `CAP-20260216-185745__stability.control.snapshot__Rhhkd48119` | WARN (latency) |
| verify.core.run (pre) | `CAP-20260216-185820__verify.core.run__R0vf351009` | 8/8 PASS |
| verify.domain.run aof --force (pre) | `CAP-20260216-185855__verify.domain.run__Rtybm61904` | 14/14 PASS |
| verify.core.run (post) | `CAP-20260216-190517__verify.core.run__Rgpca68991` | 8/8 PASS |
| verify.domain.run aof --force (post) | `CAP-20260216-190555__verify.domain.run__Rwnb979937` | 16/17 (D128 expected pre-commit) |

## Results

| Gate | Status | Validation |
|------|--------|------------|
| D131 | PASS | 10 domains, all within 7d freshness, all CAPABILITIES.md present |
| D132 | PASS | 9 governed scripts validated for git-lock pattern |
| D134 | PASS | 14 domains, 130+ gate assignments validated |
| D128 | FAIL (expected) | Unstaged mutations in gate contracts — clears after commit |

## Files Changed (21 total)

**New gate scripts (3):**
- `surfaces/verify/d131-catalog-freshness-lock.sh`
- `surfaces/verify/d132-mutation-atomicity-lock.sh`
- `surfaces/verify/d134-topology-metadata-quality-lock.sh`

**Gate contracts (4):**
- `ops/bindings/gate.registry.yaml` — added D131, D132, D134 entries; count 131→134
- `ops/bindings/gate.execution.topology.yaml` — added gate_assignments + aof path_triggers
- `ops/bindings/gate.domain.profiles.yaml` — added D131, D132, D134 to aof profile
- `surfaces/verify/drift-gate.sh` — added dispatch entries for D131, D132, D134

**Mutation scripts patched for git-lock (9):**
- `ops/plugins/orchestration/bin/orchestration-loop-open`
- `ops/plugins/orchestration/bin/orchestration-handoff-validate`
- `ops/plugins/orchestration/bin/orchestration-ticket-issue`
- `ops/plugins/orchestration/bin/orchestration-terminal-entry`
- `ops/plugins/orchestration/bin/orchestration-integrate`
- `ops/plugins/orchestration/bin/orchestration-loop-close`
- `ops/plugins/infra/bin/infra-relocation-service-transition`
- `ops/plugins/infra/bin/infra-relocation-state-transition`
- `ops/plugins/proposals/bin/proposals-supersede`

**Governance (1):**
- `docs/governance/_audits/AOF_STANDARDS_P2_20260216.md` (this file)

## Gate Implementation Details

### D131 — Catalog Freshness Lock
- Reads `ops/bindings/capability.domain.catalog.yaml`
- Validates each domain has `last_synced` field within 7 days
- Validates `docs/governance/domains/<domain>/CAPABILITIES.md` exists per domain
- Uses `TZ=UTC date -j -f` for macOS BSD date compatibility

### D132 — Mutation Atomicity Lock
- Validates 9 governed mutating scripts source `git-lock.sh` and call `acquire_git_lock`
- Scripts patched: 6 orchestration, 2 infra relocation, 1 proposals
- Pattern: `source "$ROOT/ops/lib/git-lock.sh"` + `acquire_git_lock` at script entry
- Lock uses atomic `mkdir` for POSIX-safe process locking

### D134 — Topology Metadata Quality Lock
- Validates all `domain_metadata` entries have required fields:
  `domain_id`, `description`, `criticality`, `capability_prefixes`, `path_triggers`, `added_date`
- Validates `criticality` in `{critical, standard}`
- Validates `capability_prefixes` and `path_triggers` are non-empty arrays
- Validates all `gate_assignments` have `gate_id`, `primary_domain`, `family`

## Residual Risks

- D131 freshness window is 7 days — domains with infrequent capability changes will need periodic `last_synced` refreshes
- D132 git-lock is process-level only — does not prevent concurrent mutations from different machines
- D134 does not validate cross-references (e.g., that primary_domain in gate_assignments refers to a valid domain_metadata entry)
