---
status: authoritative
owner: "@human-steward"
scope: agent-runtime-contract
---

# AGENTS.md — Canonical Agent Entry

Read this file first.

This is the canonical agent entry surface for the current aperture.

<!-- Section: STRUCTURAL ENTRY CONTRACT — stable across apertures -->

## Current Aperture

<!-- Section: VOLATILE — steward-controlled, changes when the human steward lifts or narrows aperture -->

As of 2026-04-25, the human steward lifted the prior `post-stabilization operator
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
- self-healing aperture repair when the human steward explicitly identifies
  aperture capture, intent blackholing, parking-as-deferral, or governance
  ceremony as the blocker to clean work culture; this work must subtract
  friction from existing engine/ingress/control-plane paths rather than create a
  parallel plane

Illegal work under this aperture:
- unrelated product/domain feature expansion that does not serve lean-spine
  subtraction or control-plane reconciliation
- gratuitous new doctrine shelves, surface types, or mutation paths that add
  operator decisions instead of removing them
- authority promotion of parked intake artifacts without a canonical home and
  explicit operator reason
- host/workload changes that are unrelated to telemetry, custody,
  control-plane truth, or subtraction of exposed compatibility paths

Only the human steward may invoke, change, or lift this aperture.

Do not invent a freeze, stance, or override.

The human steward may explicitly call out aperture friction for a bounded self-healing
repair when the aperture itself is blocking the spine from preserving or
advancing the work's meaning. This is stewardship, not ownership override: the
agent must respect the aperture's anti-drift purpose while repairing the rule
that is causing intent loss. The required move is to reconcile the rule in the
existing authoritative home, keep the change bounded to the named failure, and
avoid creating duplicate planes, folders, or parallel doctrine.

Do not create new homes, folders, or doctrine surfaces unless the human steward explicitly says where they belong.

If bounded-lane promotion is needed, use an existing canonical home and say why
that home is the right one.

If a task falls outside the current aperture, refuse and name which aperture rule it violates.

If the human steward says the aperture is the blocker, treat that as a steward-guided
request to inspect and repair the aperture boundary itself, not as a reason to
defer the work.

<!-- End section: VOLATILE -->

## Authority Surface

<!-- Section: STRUCTURAL ENTRY CONTRACT (continued) — stable across apertures -->

Governance is loaded at session attach. This file is the canonical entry surface
for current operator rules and the first read for any agent session.

- Current aperture and authority: this file
- Platform identity: [`NORTH_STAR.md`](NORTH_STAR.md)
- Operating contract: [`docs/governance/SPINE.md`](docs/governance/SPINE.md)
- Membrane doctrine: [`docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`](docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md)
- Root authority: [`ops/bindings/root.authority.contract.yaml`](ops/bindings/root.authority.contract.yaml)

## Session Rules

<!-- Section: DERIVATIVE — reinforcement only; authority lives in SESSION_PROTOCOL.md and SPINE.md -->

Do not treat archived or historical docs as first-read entry authority.
(Authority: [`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md), [`SPINE.md`](docs/governance/SPINE.md))

Non-promoted work, synthesis artifacts, and parked material belong in
`$SPINE_STATE/` (canonical: `~/code/.runtime/spine/state/`), not in the repo.
New repo docs require deliberate promotion and human-steward co-sign.
(Authority: [`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md))

Governed session start: `ops terminal launch --tool <tool> --terminal <name>`
Orientation (read-only, not admission): `./bin/ops cap run session.v3.attach`
(Authority: [`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md))

RAG retrieval is allowed as a discovery aid, not as authority. Use
`rag.direct.retrieve` or `rag.direct.query` to find likely governed source refs,
then read the cited packet, loop scope, contract, receipt, or capability
readback directly before deciding or mutating.
(Authority: [`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md))

Verify hierarchy for all agent sessions:
- `verify.engine.run` — foundational engine smoke (is the engine alive?)
- `spine.verify` — canonical local spine truth (is control-plane coherent?)
- these two are the only foundational verify surfaces
- `verify.infra.run`, `verify.run domain <id>`, and `verify.run release` answer
  estate/workload health — they are scoped secondary surfaces, not peers
- estate/workload verify surfaces must not be treated as spine closeout truth or
  as packet/loop/governance blockers unless a contract explicitly says so
