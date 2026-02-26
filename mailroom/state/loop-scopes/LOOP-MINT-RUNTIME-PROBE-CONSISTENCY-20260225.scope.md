---
loop_id: LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225
created: 2026-02-25
status: active
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

