# AOF Standards Pack v1 — Phase P3

**Date:** 2026-02-16
**Standards:** STD-007
**Executor:** Terminal C

## Scope

- STD-007 / D133: Output vocabulary normalization

## Run Keys

| Capability | Run Key | Result |
|------------|---------|--------|
| stability.control.snapshot (pre) | `CAP-20260216-191102__stability.control.snapshot__R9ex84409` | WARN (latency) |
| verify.core.run (pre) | `CAP-20260216-191139__verify.core.run__Rtg887182` | 8/8 PASS |
| verify.domain.run aof --force (pre) | `CAP-20260216-191212__verify.domain.run__Ry4qd17993` | 17/17 PASS |
| verify.core.run (post) | `CAP-20260216-192055__verify.core.run__R03wf23946` | 8/8 PASS |
| verify.domain.run aof --force (post) | `CAP-20260216-192127__verify.domain.run__Rf4p134730` | 17/18 (D128 expected pre-commit) |
| surface.audit.full | `CAP-20260216-192142__surface.audit.full__Ru10438818` | 10/10 PASS |

## Results

| Gate | Status | Validation |
|------|--------|------------|
| D133 | PASS | 98 gates checked, 22 legacy exceptions |
| D128 | FAIL (expected) | Unstaged mutations in gate contracts — clears after commit |

## Files Changed (6 total)

**New gate script (1):**
- `surfaces/verify/d133-output-vocabulary-lock.sh`

**Gate contracts (4):**
- `ops/bindings/gate.registry.yaml` — added D133 entry; count 134→135
- `ops/bindings/gate.execution.topology.yaml` — added D133 gate_assignment + aof path_trigger
- `ops/bindings/gate.domain.profiles.yaml` — added D133 to aof profile
- `surfaces/verify/drift-gate.sh` — added D133 dispatch entry

**Governance (1):**
- `docs/governance/_audits/AOF_STANDARDS_P3_20260216.md` (this file)

## Gate Implementation Details

### D133 — Output Vocabulary Lock
- Scans all `d<N>-*.sh` gate scripts in `surfaces/verify/`
- Validates each gate script contains its gate ID (D<N>) in at least one `echo` or `printf` statement
- 22 legacy exceptions for gates that use bare PASS/FAIL without gate ID:
  d45, d48, d51, d52, d53, d58, d59, d60, d61, d64, d68, d69, d81, d82, d83, d84, d98, d99, d103, d112, d113, d114
- Exception list is a ratchet — prevents new non-canonical gates while allowing gradual migration

## Residual Risks

- 22 legacy gate scripts still use bare PASS/FAIL without gate ID in output — migrating them is deferred
- D133 validates source patterns (grep), not runtime output — a gate could construct its ID dynamically and pass the check without true canonical output
