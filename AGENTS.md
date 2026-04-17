---
status: authoritative
owner: "@ronny"
scope: agent-runtime-contract
---

# AGENTS.md — Canonical Agent Entry

Read this file first.

This is the canonical agent entry surface for the current aperture.

<!-- Section: STRUCTURAL ENTRY CONTRACT — stable across apertures -->

## Current Aperture

<!-- Section: VOLATILE — operator-controlled, changes when Ronny lifts or narrows aperture -->

As of 2026-04-16, the spine is in `verify truth-plane separation` aperture.

Spine-core stabilization remains complete. Scope is widened only enough to
separate spine/object truth from estate/workload health across verify surfaces,
agent read paths, and block semantics. The baseline is commit `f0a74693`
(manifest knowledge layer, 2026-04-12).

The immediate specimen for this aperture is verify itself:
`verify.run`, `verify.topology`, the G-gate registry/ring surfaces, and the
agent/operator surfaces that currently read `fast`/`infra`/`domain`/`release`
results as if they were spine truth. Do not widen into L3 host, VM, or service
repair unless Ronny says so.

Deepest standard for this aperture:
- distinguish object truth from role truth
- do not let workload-role or host-health failures falsify packet, loop, or
  governance truth
- prefer shapes that teach truthful, repeatable environment habits over shapes
  that reward reading estate noise as spine truth

Legal work:
- audit existing verify surfaces, packs, outputs, and block semantics to
  determine which ones answer spine truth vs estate/workload health
- land read-side clarification in existing canonical homes so every agent sees
  the verify boundary before acting
- bug-fix existing verify surfaces when they conflate planes or emit misleading
  scope, truth, or blocking signals
- narrow changes to existing verify wrappers, metadata, and outputs when needed
  to encode truth plane and decision semantics honestly
- read-heavy operator product surfaces (cockpit, dashboards, status views) that
  consume existing authority without mutating it
- classification of operator vision artifacts into existing governed intake
  posture, without authority promotion outside the bounded verify lane
- parking operator notes with explicit promotion conditions
- release and distribution hygiene
- verify, status, and reconcile operations
- bug fixes to existing spine-core surfaces when provably broken

Illegal work until Ronny lifts this aperture:
- L3 domain, VM, service, or host remediation under the banner of verify work
- net-new governance surfaces, doctrine shelves, or surface type vocabulary
  outside existing canonical homes
- broad architecture reopening beyond verify truth-plane separation
- host assignments, workload placement, or role promotion unrelated to making
  verify truthful
- L3 domain creation or extraction
- worldview reconstruction or re-litigation of what the spine is outside the
  verify lane
- generic multi-family provisioning or recovery expansion
- promotion of parked artifacts unrelated to verify truth-plane separation
- new governed mutation paths unrelated to verify truth-plane separation

Only Ronny may invoke, change, or lift this aperture.

Do not invent a freeze, stance, or override.

Do not create new homes, folders, or doctrine surfaces unless Ronny explicitly says where they belong.

If bounded-lane promotion is needed, use an existing canonical home and say why
that home is the right one.

If a task falls outside the current aperture, refuse and name which aperture rule it violates.

<!-- End section: VOLATILE -->

## Authority Surface

<!-- Section: STRUCTURAL ENTRY CONTRACT (continued) — stable across apertures -->

Governance is loaded at session attach. This file is the canonical entry surface
for current operator rules and the first read for any agent session.

- Current aperture and authority: this file
- Platform identity: [`NORTH_STAR.md`](NORTH_STAR.md)
- Operating contract: [`docs/governance/SPINE.md`](docs/governance/SPINE.md)
- Translator doctrine: [`docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`](docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md)
- Root authority: [`ops/bindings/root.authority.contract.yaml`](ops/bindings/root.authority.contract.yaml)

## Session Rules

<!-- Section: DERIVATIVE — reinforcement only; authority lives in SESSION_PROTOCOL.md and SPINE.md -->

Do not treat archived or historical docs as first-read entry authority.
(Authority: [`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md), [`SPINE.md`](docs/governance/SPINE.md))

Non-promoted work, synthesis artifacts, and parked material belong in
`.runtime/spine/state/`, not in the repo. New repo docs require deliberate
promotion and Ronny co-sign.
(Authority: [`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md))

Session attach: `./bin/ops cap run session.v3.attach`
(Authority: [`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md))

Verify scope reading for all agent sessions:
- `verify.run engine`, `honesty`, and `spine` answer spine/object truth
- `verify.run fast`, `infra`, `domain`, and `release` answer estate/workload
  health, not packet/loop/governance truth
- estate/workload verify surfaces must not be treated as spine closeout truth or
  as packet/loop/governance blockers unless a contract explicitly says so
