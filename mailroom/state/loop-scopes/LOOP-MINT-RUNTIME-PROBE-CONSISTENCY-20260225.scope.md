---
loop_id: LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225
created: 2026-02-25
status: closed
owner: "@ronny"
scope: mint
severity: critical
objective: Eliminate conflicting health/deploy/proof signals and produce one runtime truth set for mint-apps and mint-data
---

# Loop Scope: LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225

## Problem Statement

Received audit results conflict on core runtime probes (`mint.modules.health`,
`mint.deploy.status`, `mint.runtime.proof`). Contradictory pass/fail output
blocks trustworthy decisions and causes loop churn.

## Deliverables

1. Execute a timed probe set (health, deploy, proof) on the same runtime window.
2. Record exact host/port targets used by each probe.
3. Produce discrepancy table for any mismatched outcomes.
4. File follow-on cleanup tasks only for verified mismatches.

## Acceptance Criteria

1. Three consecutive probe sets are captured with run keys.
2. Any mismatch has a root cause category:
   `probe_target_mismatch`, `service_down`, `network_path`, `stale_contract`.
3. A single truth statement is produced for each module: `UP`, `DOWN`, or
   `UNKNOWN` with evidence.
4. No "all healthy" claim is published unless all three probes agree.

## Constraints

1. Defer auth work.
2. Defer unbuilt capability expansion.
3. Do not ship code features in this loop; verification and runtime truth only.
4. Keep legacy/docker-host probes separate from fresh-slate probe outputs.

## Execution Closeout (2026-02-26)

Canonical artifact:
- `/Users/ronnyworks/code/agentic-spine/docs/planning/MINT_RUNTIME_PROBE_CONSISTENCY_20260226.md`

Run keys (3 consecutive sets):
- Set 1:
  - `CAP-20260226-022038__mint.modules.health__R597p24855`
  - `CAP-20260226-022038__mint.deploy.status__Rcvju24856`
  - `CAP-20260226-022039__mint.runtime.proof__Rt6v725052`
- Set 2:
  - `CAP-20260226-022252__mint.modules.health__Rkvcm49864`
  - `CAP-20260226-022252__mint.deploy.status__R3irt49921`
  - `CAP-20260226-022252__mint.runtime.proof__Rk8wx49935`
- Set 3:
  - `CAP-20260226-022501__mint.modules.health__Rcsxw75597`
  - `CAP-20260226-022501__mint.deploy.status__Rgq9c75598`
  - `CAP-20260226-022501__mint.runtime.proof__Rujia75706`

Validation closeout:
- `CAP-20260226-022508__verify.pack.run__Rk9ur78360` (mint pack pass 22/22)
- `CAP-20260226-022508__gaps.status__R9evv78361`

Acceptance result:
1. Three consecutive probe sets captured: met.
2. Mismatch root-cause categories assigned (`stale_contract` for uncovered proof surfaces): met.
3. Single per-module truth statement published (`UP`/`UNKNOWN`): met.
4. No unsupported "all healthy" claim for non-proof-covered modules: met.
