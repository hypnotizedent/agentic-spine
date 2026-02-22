---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: mint-aof-preflight-enforcement-step1
parent_loop: LOOP-MINT-AOF-BASELINE-V1-20260217
---

# Mint AOF Preflight Enforcement Step 1 (2026-02-17)

## Scope

Implement changed-files preflight enforcement in `mint-modules` without adding new drift gates.

## Constraints Preserved

1. No proposal queue mutation in this run (status/list read-only only).
2. `GAP-OP-590` unchanged:
   - status remains open
   - parent loop remains `LOOP-WORKBENCH-AOF-HARDENING-V2-20260217`
3. No edits under `dropzone/*`.
4. Changed-files ratchet only; no whole-repo retrofit.

## Phase 0 — Preflight

- `CAP-20260217-113450__stability.control.snapshot__R8iom79360`
- `CAP-20260217-113528__verify.core.run__Rmnik83488`
- `CAP-20260217-113622__verify.domain.run__Rvdki2550`
- `CAP-20260217-113638__proposals.status__Royzx10029`
- `CAP-20260217-113638__proposals.list__Rglt110051`
- `CAP-20260217-113638__gaps.status__R0yfl10054`

Gate result: PASS.

## Phase 1 — Contract + Checker

Created in `mint-modules`:

1. `scripts/guard/mint-aof-check.sh`
2. `docs/CANONICAL/MINT_AOF_PRECHECK_CONTRACT.yaml`

Phase-1 gate check output:

```text
MINT AOF CHECK
mode=all format=text changed_files=2 evaluated_files=2
findings: none
summary: P0=0 P1=0 P2=0 total=0
```

Gate result: PASS.

## Phase 2 — Workflow Wiring

Updated in `mint-modules`:

1. `bin/mintctl` (`mintctl aof-check` pass-through command)
2. `scripts/release/promote-to-prod.sh` (mandatory preflight checker call)
3. `AGENT_ENTRY.md` (precheck-before-commit/promotion guidance)
4. `docs/CANONICAL/CONTROL_PLANE_ENFORCEMENT.md` (ratchet policy + command examples)

Gate result: PASS.

## Phase 3 — Certification

Mint-side checks:

1. `./bin/mintctl aof-check --mode all --format text`
   - `summary: P0=0 P1=0 P2=0 total=0`
2. `./bin/mintctl aof-check --mode all --format json`
   - `{ "summary": { "P0": 0, "P1": 0, "P2": 0, "total": 0 } }`
3. `./bin/mintctl doctor`
   - `DOCTOR: PASS`

Spine-side cert:

- `CAP-20260217-114205__verify.core.run__R3cbi76111`
- `CAP-20260217-114205__verify.domain.run__R4ko676114`
- `CAP-20260217-114205__proposals.status__Rhw7y76112`
- `CAP-20260217-114205__gaps.status__Rvyc676116`

`GAP-OP-590` proof line:

```text
[low] GAP-OP-590 → LOOP-WORKBENCH-AOF-HARDENING-V2-20260217 (active)
```

Gate result: PASS.

## Proposal Queue Observation

- Phase 0 pending count: 10
- Phase 3 pending count: 9

No queue mutation commands were executed in this run. Queue delta observed as
external concurrent activity.
