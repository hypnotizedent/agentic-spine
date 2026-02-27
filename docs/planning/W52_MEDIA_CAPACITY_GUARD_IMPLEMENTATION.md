---
status: draft
owner: "@ronny"
last_updated: "2026-02-27"
scope: w52-media-capacity-guard
---

# W52 Media Capacity Guard Implementation

## Objective

Implement canonical governance so `media >= 80%` cannot persist without an owned remediation loop/gap and visible session brief output.

## Baseline (2026-02-27)

- media: 81% ONLINE
- md1400: 6% ONLINE
- tank: 40% ONLINE
- Protected no-touch:
  - LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226
  - GAP-OP-973

## Implemented Controls

1. Gate `D257` (`surfaces/verify/d257-media-capacity-guard-lock.sh`)
- Report/enforce modes
- WARN threshold: 80%
- FAIL threshold: 85%
- Stale threshold: 7 days
- Structured finding reasons:
  - `critical_breach`
  - `stale_unowned`
  - `threshold_breach` (derived via stale/trend/ownership findings)

2. Policy binding (`ops/bindings/infra.capacity.guard.policy.yaml`)
- Thresholds + host/pool targeting
- Owning loop/terminal contract
- Protected no-touch IDs
- Enforce promotion criteria

3. Lifecycle wrapper capability (`infra.media.capacity.guard.reconcile`)
- Script: `ops/plugins/infra/bin/infra-media-capacity-guard-reconcile`
- Behaviors:
  - `--brief` session line output
  - `--check-only` D257 evidence-only run
  - reconcile mode upserts owning loop/gap when needed
  - explicit protected no-touch attestation

4. Session visibility
- `session.start` fast output now includes:
- `HW: media=<cap>% <state> | md1400=<cap>% | capacity_gap=<id|none> | age=<days>`

## Report-First to Enforce Promotion

Promotion to enforce is allowed only after:

1. `verify.pack.run mint` passes.
2. `verify.pack.run communications` passes.
3. `verify.core.run` passes.
4. `proposals.reconcile --check-linkage` shows unresolved=0.
5. Master receipt decision is `READY_FOR_ENFORCE_PROMOTION`.

If any item fails: hold state = `HOLD_WITH_BLOCKERS`.

## Out-of-Scope in This Change

- No destructive storage actions (pool create/wipefs/sgdisk/zap)
- No mutation of protected loop/gap or active EWS/MD1400 rsync lanes
