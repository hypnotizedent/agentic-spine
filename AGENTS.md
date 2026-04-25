---
status: authoritative
owner: "@operator"
scope: agent-runtime-contract
---

# AGENTS.md — Canonical Agent Entry

Read this file first.

This is the canonical agent entry surface for the current aperture.

<!-- Section: STRUCTURAL ENTRY CONTRACT — stable across apertures -->

## Current Aperture

<!-- Section: VOLATILE — operator-controlled, changes when Ronny lifts or narrows aperture -->

As of 2026-04-16, the spine is in `post-stabilization operator surfaces`
aperture.

The bounded `verify truth-plane separation` lane is closed. Its resulting
distinctions remain canonical read doctrine, but that lane is no longer the
active aperture. Spine-core stabilization remains complete. The engine stays
conservative; change is limited to provable bug fixes unless Ronny explicitly
widen scope. The baseline is commit `f0a74693` (manifest knowledge layer,
2026-04-12).

Legal work:
- read-heavy operator product surfaces (cockpit, dashboards, status views) that
  consume existing authority without mutating it
- classification of operator vision artifacts into existing governed intake
  posture, without authority promotion or new mutation-path creation
- parking operator notes with explicit promotion conditions; no authority
  promotion under this aperture
- release and distribution hygiene
- verify, status, and reconcile operations
- bug fixes to existing spine-core surfaces when provably broken

Illegal work until Ronny lifts this aperture:
- net-new governance surfaces, doctrine shelves, or surface type vocabulary
- broad architecture reopening (node topology, plane restructuring, fleet
  ontology)
- authority promotion of parked intake artifacts; classification is legal,
  promotion is not
- host assignments
- L3 domain creation or extraction
- worldview reconstruction or re-litigation of what the spine is
- new governed mutation paths unless explicitly scoped, narrowly bounded, and
  approved by Ronny

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

Verify hierarchy for all agent sessions:
- `verify.engine.run` — foundational engine smoke (is the engine alive?)
- `spine.verify` — canonical local spine truth (is control-plane coherent?)
- these two are the only foundational verify surfaces
- `verify.infra.run`, `verify.run domain <id>`, and `verify.run release` answer
  estate/workload health — they are scoped secondary surfaces, not peers
- `verify.fast` and `verify.core.run` are deprecated compatibility aliases for
  `verify.infra.run`; do not use them in new work
- estate/workload verify surfaces must not be treated as spine closeout truth or
  as packet/loop/governance blockers unless a contract explicitly says so
