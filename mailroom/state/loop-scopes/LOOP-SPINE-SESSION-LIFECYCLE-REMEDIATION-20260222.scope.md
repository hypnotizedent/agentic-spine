---
loop_id: LOOP-SPINE-SESSION-LIFECYCLE-REMEDIATION-20260222
created: 2026-02-22
status: active
owner: "@ronny"
scope: spine
priority: high
objective: Rebuild startup/session lifecycle into a fast-by-default workflow while preserving safety gates, Mailroom routing, and release-cert rigor.
---

# Loop Scope: LOOP-SPINE-SESSION-LIFECYCLE-REMEDIATION-20260222

## Objective

Rebuild startup/session lifecycle into a fast-by-default workflow while preserving safety gates, Mailroom routing, and release-cert rigor.

## Parent Gaps

- GAP-OP-817

## Problem Statement

Current day-to-day startup behavior is running heavyweight reliability and verification commands before useful work begins.
This creates avoidable latency, battery drain, and context bloat, and encourages bypass behavior.

## Deliverables

- Startup lifecycle audit with measured wall-clock baselines and bottleneck attribution.
- Phased remediation plan that keeps governance guarantees while reducing startup tax.
- Mailroom proposal(s) for execution phases, with explicit gate/contract touch map.
- Verification strategy with fast-lane SLOs and fallback/full-lane controls.

## Acceptance Criteria

- A fast startup lane is defined and governed (target <10s p95 for day-to-day entry).
- Heavy checks are explicitly deferred to post-work, mutation-time, or full-cert lanes.
- Entry surface contract and related gates are updated without breaking D124/D65 invariants.
- Operator has a clear, sequenced rollout path with rollback points.

## Constraints

- Do not weaken mutation safety controls for critical domains.
- Keep receipts and proposal routing as mandatory execution boundaries.
- Preserve release/nightly certification lane semantics.
- Maintain compatibility across Codex/Claude/OpenCode entry surfaces.

## Initial Verification Matrix

- `./bin/ops status --brief`
- `./bin/ops cap run proposals.list`
- `./bin/ops cap run proposals.reconcile`
- `./bin/ops cap run verify.route.recommend`

## Notes

- Planning and registration started on 2026-02-22.
- Execution patch set is tracked via CP draft-hold and will be promoted to pending after owner review.

## Audit Baseline (Measured 2026-02-22)

- `./bin/ops status --brief`: `0.05s`
- `./bin/ops cap run session.start` (fast): `0.69s`
- `./bin/ops cap list`: `14.79s` (`443` output lines)
- `./bin/ops cap run stability.control.snapshot`: `65.69s` (reported status `failed`)
- `./bin/ops cap run verify.core.run`: `51.00s` (reported status `done`)
- Session-entry hook payload (`ops/hooks/session-entry-hook.sh`): `6646` bytes injected

## Core-8 Gate Cost Attribution

- Total profiled Core-8 wall clock: `53.463s`
- D63 `surfaces/verify/d63-capabilities-metadata-lock.sh`: `44.525s` (dominant)
- D3 `surfaces/verify/d3-entrypoint-smoke.sh`: `5.947s`
- Remaining gates combined: `~2.991s`

## Root Cause Summary

- Startup policy drift across surfaces: fast lane exists (`session.start`) but startup blocks still invoke heavy lane.
- Verify-core implementation cost is concentrated in metadata validation that repeatedly parses YAML per capability.
- Entrypoint smoke gate currently runs a heavyweight preflight path.
- Session-entry hook injects near-full governance brief, consuming context budget on every first prompt.
- Capability discovery (`cap list`) performs repeated YAML calls per capability instead of one-pass extraction.

## Remediation Plan (Phased)

### Phase 1: Immediate Latency and Context Relief

- Make startup block fast-by-default using `./bin/ops cap run session.start`.
- Keep legacy startup commands as explicit commented fallback for operator opt-in and parity gates.
- Optimize `ops cap list` to one-pass capability extraction.
- Replace D3 preflight invocation with lightweight entrypoint smoke checks.
- Rewrite D63 capability metadata validation to parse capabilities once.
- Switch session-entry hook to summary brief injection by default.

### Phase 2: Contract and Lifecycle Coherence

- Reconcile startup guidance across `AGENTS.md`, `CLAUDE.md`, `OPENCODE.md`, and `SESSION_PROTOCOL.md`.
- Align `docs/governance/AGENT_GOVERNANCE_BRIEF.md` verify cadence with fast start + post-work verify routing.
- Add explicit fast/full startup policy matrix and escalation conditions (when full lane is mandatory).

### Phase 3: Stability + Scale Controls

- Add performance budget gates:
  - `session.start` p95 target: `<2s`
  - `verify.core.run` p95 target: `<10s`
  - session-entry injection target: `<2.5KB`
- Add release certification checks for startup policy drift and latency regression.
- Require every new capability/gate to declare execution class (`startup`, `post-work`, `release-only`) to prevent startup accretion.
