---
loop_id: LOOP-AOF-GAP-SCHEMA-CONFORMANCE-SELF-GROWTH-20260303
created: 2026-03-03
status: active
owner: "@ronny"
scope: governance
priority: high
horizon: now
execution_readiness: blocked
objective: Close the AOF schema-conformance loophole by enforcing gap schema contracts (not just naming conventions) so new fields cannot drift in narratively.
blocked_by:
  - "Sequencing lock only: run immediately after current W2 Friction/Cloudflare/Tailscale lanes park."
---

# Loop Scope: LOOP-AOF-GAP-SCHEMA-CONFORMANCE-SELF-GROWTH-20260303

## Objective

Make `ops/bindings/gap.schema.yaml` enforceable in runtime so authority schema and
actual gap entries cannot diverge.

## Why This Exists

A recent `blocker_class` rollout proved a structural gap:
- schema conventions lint checks naming/style, not schema conformance,
- `gap.schema.yaml` is not currently enforced,
- legacy exceptions on `operational.gaps.yaml` allow drift to pass silently.

Research synthesis (2026-03-03) extends this beyond gaps:
- the spine is detection-rich and growth-poor,
- new artifacts are discoverable only when manually registered,
- validate-after-registration is strong, register-at-creation is weak.

## Canonical Findings Added

The following registry surfaces are now explicitly tracked in this loop as
up-next governance work after W2 lanes park:

- Gate registry completeness (`surfaces/verify` vs `gate.registry.yaml`)
- Capability registry completeness (plugin `MANIFEST.yaml` vs `capabilities.yaml`)
- Agent registry completeness (`ops/agents/*.contract.md` vs `agents.registry.yaml`)
- Launchd registry completeness (`ops/runtime/launchd/*.plist` vs scheduler registry)
- Binding contract reference completeness (`ops/bindings/*.yaml` reachability)
- Plans index completeness (`mailroom/state/plans/*.md` vs `plans/index.yaml`)
- MCP config coherence (spine/workbench config parity vs declared agents)

All seven are treated as scope-linked growth checks for future scan capability
family design (`spine.scan` or equivalent split scanners).

## Guard Commands

- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-AOF-GAP-SCHEMA-CONFORMANCE-SELF-GROWTH-20260303`

## Scope

In:
- Schema conformance enforcement for `operational.gaps.yaml`
- Contract alignment between `gap.schema.yaml` and `gaps.file` outputs
- New drift lock gate for gap schema conformance (D332)

Out:
- Non-gap schema migrations
- Runtime service/domain mutations

## Execution Steps

- Step 1: Canonicalize `gap.schema.yaml` to current reality (`title`, `classification`, `blocker_class`).
- Step 2: Add strict schema-bound file enforcement to `spine.schema.conventions.yaml`.
- Step 3: Extend `schema-conventions-audit` with schema allowlist enforcement mode.
- Step 4: Add `D332` (`gap-schema-conformance-lock`) + register topology.
- Step 5: Verify + adversarial proof (inject unknown key -> expected FAIL).
- Step 6: Capture scanner-family design notes for registry completeness (`gate.scan`, `cap.scan`, `agent.scan`, `launchd.scan`, `binding.scan`) and queue follow-on implementation loop.

## Success Criteria

- Unknown keys in `operational.gaps.yaml` are hard failures.
- `gap.schema.yaml` and produced gap fields stay in lock-step.
- Fast verify includes schema conformance lock and passes.
- Canonical record includes the seven-surface registry completeness gap so this
  does not rely on operator memory.

## Definition Of Done

- Scope + plan artifacts committed.
- Gap schema enforcement path implemented and receipted.
- Linked gaps closed with explicit evidence.

## Linked Gaps

- GAP-OP-1411
- GAP-OP-1412

## Sequencing Note

This loop is **up next** and **current**. It is intentionally parked behind
in-flight W2 lanes only to avoid cross-lane write contention.
