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

Subtraction aperture discipline:
- Every first-class L1/L2 improvement must subtract the old surface it replaces.
  Construction is not completion.
- The spine core defines canonical protocol shape, custody, heartbeat/readback,
  result/failure, receipt, role truth, and retirement gates. It must not absorb
  L3 domain bodies, app-specific logic, or old shard behavior as new
  architecture.
- Do not create permanent adapter backfill, parallel catchup systems, or
  domain-specific wrapper subsystems to preserve old residue. A thin adapter is
  legal only when it is the minimal readback/materialization shape required by
  an existing canonical L1/L2 contract and it names the old surface it will
  retire, hide, or demote.
- Old operational jobs may continue only as operational jobs with canonical
  readback. They must not remain parallel authority, placement truth, watcher
  truth, backup truth, status truth, or operator grammar.
- Parked/deferred is not closure. If a legacy surface cannot be subtracted yet,
  the live gap is the missing canonical replacement proof, not a new governance
  shelf.
- Estate truth must not split into three disconnected planes. When planning or
  changing L1/L2 estate shape, reconcile runtime truth (what actually runs on
  hosts and storage), intent/planning truth (OI/HI, packets, domain-state notes,
  receipts, and candidate records), and repo/contract truth (contracts,
  capabilities, status, and verifies) before choosing the next slice. If the
  planes disagree, the work is a first-class reconciliation and subtraction
  problem; do not solve only the most visible symptom.
- Repo topology must not hide drift. `agentic-spine` owns the L1 kernel and
  control-plane truth. Workbench may own L2 shared operational rails, adapters,
  generators, validators, and reusable agent tools, but it must not become the
  new dumping ground for L3/product bodies. L3 project/domain bodies belong in
  project homes while unstable; stable product bodies belong in product homes or
  explicitly named product repos. Generated projections may cross these
  boundaries, but hand-maintained authority must have exactly one home.

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
- estate-truth reconciliation across runtime, intent/planning, and repo/contract
  planes, including alias cleanup, promotion-path readback, and subtraction of
  stale surfaces that make the planes disagree
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
- moving L3/product bodies into Workbench without classifying whether they are
  shared L2 rails, unstable project bodies, stable products, generated
  projections, or stale residue
- treating hand-updated factual YAML as canonical when it should be generated
  from a living authority
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
`$SPINE_STATE/`, not in the repo. `$SPINE_STATE` is a **logical** root.
Canonical authority lives on the `storage_evidence_node` (pve, currently
`/md1400/spine/state`); consumer-host resolution (MacBook
`~/code/.runtime/spine/state`, ai-cons `/home/ubuntu/code/.runtime/spine/state`,
pve-r620 likewise) is **projection/cache**, not durable shared state. Writes
that must be durable shared authority must run via `cap.sh`-routed cap
execution (which lands on the authority host) or write through the
canonical mount. Local-direct writes on a consumer host produce projection
artifacts only — not durable. There is no governed writer today for
non-authoritative durable research or derived-conclusion notes; until one
exists, such notes are session-local only. New repo docs require deliberate
promotion and human-steward co-sign.
(Authority: [`root.authority.contract.yaml#taxonomy.storage_evidence_node_canonical.file_plane_policy`](ops/bindings/root.authority.contract.yaml),
[`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md))

Operator input and human intent are the entry point; loops are bounded
execution containers, not intake buckets. Operator input is unverified
outside thinking from the human steward (raw OI/HI drops); evidence is
the verified proof — receipts, live probes, repo/runtime observations,
authoritative doc readback — that the system produces by acting on or
comparing against operator input. Do not create a loop just to hold Q&A,
make status/readback prettier, or satisfy packet binding. Attach operator
input to an existing loop when the fit is clear; create a loop only when
there is a bounded objective with acceptance and close criteria.
(Authority: [`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md))

Human intent, examples, and packet prose are inputs to consider, not authority
by themselves. They become actionable only when attached to the existing
governed home that owns the concern. Examples and templates illustrate shape;
they do not widen scope, create permission, or override contracts.
(Authority: [`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md),
[`SPINE.md`](docs/governance/SPINE.md))

When the human steward names a concrete example such as a Pi, Frigate, a Dell,
or a VM, do not collapse the request into that example if the surrounding
language asks for a systemic pattern. First identify the L1/L2 family, the
existing canonical home, and the old surfaces to subtract; only then touch the
example-specific runtime.
(Authority: [`NORTH_STAR.md`](NORTH_STAR.md),
[`NODE_PROMOTION_LADDER.md`](docs/governance/NODE_PROMOTION_LADDER.md),
[`first.class.change.closure.contract.yaml`](ops/bindings/first.class.change.closure.contract.yaml))

When the work is repo-topology or domain extraction, classify the surface before
moving it: L1 kernel, L2 shared rail/adapter, L3 unstable project/domain body,
stable product body, generated projection, stale residue, or compatibility
shim. Workbench is a valid target only for L2 rails or explicitly transitional
domain homes with a named subtraction path; it is not proof that the surface is
canonical.
(Authority: [`NORTH_STAR.md`](NORTH_STAR.md),
[`SPINE.md`](docs/governance/SPINE.md))

The primary `agentic-spine` checkout must stay on `main` and clean. If repo
mutation is needed, do the work in a managed worktree; do not use the primary
checkout as a work lane.
(Authority: [`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md))

Governed session start/admission:
`ops terminal launch --tool <tool> --terminal <name>`
Public readback: `./bin/ops status`
Expert drilldown: `./bin/ops status --expert` only when public status gives a
reason for drilldown.
Orientation (read-only, not admission): `./bin/ops cap run session.v3.attach`
(Authority: [`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md))

Agent entry mode is governed by the work-intake router policy in
`SESSION_PROTOCOL.md`. Serious work defaults to engine lane; direct terminal
work is limited to read-only reports and direct tiny patches with an explicit
reason. Visible worker terminals are exceptional and must not substitute for
lane telemetry.
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

Live verify exit codes govern, not the cached `ops status` projection — re-run
`verify.engine.run` and `spine.verify` directly before treating any failure as
a blocker, since the "spine verify" line in `ops status` is a projection that
may lag the live truth. A FAIL D-gate blocks bounded mutation only when its
scope predicate overlaps the surface being modified; per-host scope skips such
as `D153` and `D397` already establish the per-gate scope-predicate pattern. A
bound `worker`-class terminal may proceed in a managed worktree on an
orthogonal red with an explicit risk note. The real mutation gate is bound
terminal identity (`SPINE_TERMINAL_ID` set by `ops terminal launch`) plus the
capability role allowlist in `role.runtime.control.contract.yaml`
(`runtime_roles.mutating_roles` and `mutating_capability_allowlist_by_role`),
not posture telemetry such as `SPINE_RECOVERY_READY` (formerly
`SPINE_SAFE_TO_MUTATE`, renamed for honesty — it signals execution-host
recovery readiness, not mutation permission, and has no enforcement consumer).
(Authority: [`role.runtime.control.contract.yaml`](ops/bindings/role.runtime.control.contract.yaml),
[`SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md))
