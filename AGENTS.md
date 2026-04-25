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

As of 2026-04-25, Ronny lifted the prior `post-stabilization operator
surfaces` aperture. The spine is now in `lean spine subtraction and
control-plane reconciliation` aperture.

The remaining problems are no longer primarily spine-core authority bugs. The
active work is now the exposed compatibility shell around the kernel:
public-vs-expert drift, fragmented telemetry/readback, workflow over-visibility,
doctrine/runtime contradiction, migration residue, and unresolved control-plane
truth.

Legal work:
- public vs expert boundary work across existing surfaces, including demoting
  `ops loops`, `ops wave`, raw scope/receipt surgery, and similar expert paths
  from taught operator grammar while preserving them as drilldown/surgery tools
- operator read-model collapse across `status`, operator payload, cockpit/mobile,
  standing-program health, interventions, OI readback, handoffs, loops, waves,
  and foundational verify truth
- workflow closure and concealment work that makes waves/handoffs/closeout more
  engine-internal and less operator-public, including execute-path automation
- doctrine/runtime reconciliation across `AGENTS.md`, `NORTH_STAR.md`,
  `docs/governance/SPINE.md`, `docs/governance/SESSION_PROTOCOL.md`,
  `docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`, and existing public
  help text
- control-plane truth decisions and implementation, including node/control-plane
  topology, custody/attestation semantics, and whether `operator_console` or a
  promoted control node is the long-term governing control plane
- bounded governance/contract updates required to make the above truthful
- subtraction cleanup of migration residue, stale references, stale loops,
  stale parked operator-visible artifacts, and visible compatibility shells
- verify, status, reconcile, release/distribution hygiene, and provable bug
  fixes anywhere needed to support this aperture

Illegal work under this aperture:
- unrelated product/domain feature expansion that does not serve lean-spine
  subtraction or control-plane reconciliation
- gratuitous new doctrine shelves, surface types, or mutation paths that add
  operator decisions instead of removing them
- authority promotion of parked intake artifacts without a canonical home and
  explicit operator reason
- host/workload changes that are unrelated to telemetry, custody,
  control-plane truth, or subtraction of exposed compatibility paths

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
