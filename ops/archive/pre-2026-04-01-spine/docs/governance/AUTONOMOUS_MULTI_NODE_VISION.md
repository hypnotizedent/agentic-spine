---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-28
scope: autonomous-multi-node-vision
version: 1.0
machine_enforcement: not_yet_machine_enforced
source_triangulation:
  - NORTH_STAR.md
  - docs/governance/SPINE.md
  - docs/governance/PLATFORM_LAYER_MODEL.md
  - docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md
  - docs/governance/LOCAL_CONTROL_PLANE_CONTRACT.md
  - docs/governance/GOVERNED_TASK_ENVELOPE_SPEC.md
  - ops/bindings/governed.change.lifecycle.contract.yaml
  - ops/bindings/node.role.contract.yaml
  - ops/bindings/session.admission.contract.yaml
  - ops/bindings/communication.protocol.contract.yaml
  - ops/bindings/role.runtime.control.contract.yaml
  - ops/bindings/wave.lifecycle.yaml
  - ops/bindings/launchd.runtime.contract.yaml
  - .runtime/spine/state/domain-state/spine/execution-packets-20260326/CAPABILITY_RECONCILIATION_AGAINST_LIVE_SURFACES_TRANCHE9_STATUS_20260328.md
---

# Autonomous Multi-Node Vision

This document preserves the operational end-state the spine is being built
toward.

It exists because the March 2026 governance campaign proved two things at the
same time:

1. the spine can now land focused, high-quality governed work quickly
2. the operator is still the human message bus connecting the surfaces

The campaign improved the engine. It also made the remaining orchestration gap
impossible to ignore.

## Relationship To Other Authorities

- [`NORTH_STAR.md`](../../NORTH_STAR.md) defines what the platform is for.
- [`SPINE.md`](SPINE.md) defines how governed work lands today.
- [`PLATFORM_LAYER_MODEL.md`](PLATFORM_LAYER_MODEL.md) defines L1, L2, and L3.
- [`TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`](TRANSLATOR_AUTHORITY_DOCTRINE_V1.md)
  defines translator boundaries and the 7-node model.
- [`LOCAL_CONTROL_PLANE_CONTRACT.md`](LOCAL_CONTROL_PLANE_CONTRACT.md) defines
  the operator workstation and current control-plane posture.
- [`GOVERNED_TASK_ENVELOPE_SPEC.md`](GOVERNED_TASK_ENVELOPE_SPEC.md) defines the
  bounded dispatch packet.
- [`node.role.contract.yaml`](../../ops/bindings/node.role.contract.yaml)
  defines physical node types and permissions.
- [`communication.protocol.contract.yaml`](../../ops/bindings/communication.protocol.contract.yaml)
  defines the operator -> translator -> controller pathway.
- [`wave.lifecycle.yaml`](../../ops/bindings/wave.lifecycle.yaml) defines
  multi-lane lifecycle expectations.

This document answers a different question:

> How does work move between nodes without Ronny acting as the router?

## The Problem Being Named

The operator is currently the routing layer.

In practice, a governed pass still often looks like this:

1. Codex emits a prompt or interpretation.
2. The operator pastes it to Cowork for translation or challenge.
3. The operator pastes the result back to Codex.
4. A terminal executes the prompt.
5. The terminal emits a receipt.
6. The operator pastes the receipt back through translation surfaces.
7. The operator decides the next move and repeats the cycle.

That means the operator is manually connecting:
- translator surfaces
- controller surfaces
- execution terminals
- receipt interpretation surfaces

The last three days made the pattern obvious. The capability reconciliation
campaign advanced through nine bounded tranches, but each tranche still
depended on manual copy-paste routing between windows. The work itself was
disciplined. The flow between nodes was not yet self-executing.

## The End-State Vision

The spine should reach a state where one bounded concern can move through the
system without the operator acting as the transport mechanism.

The intended end-state is:

1. A controller node receives a bounded concern.
2. The controller understands the scope using governed context only.
3. The controller decomposes the concern into bounded wave lanes.
4. The controller dispatches each lane to one or more execution nodes.
5. Execution nodes run autonomously within governed scope and emit receipts.
6. A watcher or librarian function maintains a ledger of git and receipt truth.
7. The controller aggregates lane receipts, synthesizes outcome, and updates
   campaign state.
8. The operator reviews the result and elects the next concern.

The operator's job becomes:
- elect the concern
- review the outcome
- decide the next move

The operator's job should not remain:
- manual packet router
- receipt courier
- human synchronization layer between terminals

## Current Truth

The vocabulary for this future already exists in repo truth.

| Existing authority | What it already provides | What is still missing |
|---|---|---|
| `ops/bindings/node.role.contract.yaml` | Physical node types and capability boundaries | Live inter-node workflow wiring |
| `ops/bindings/communication.protocol.contract.yaml` | Operator -> translator -> controller pathway | Delivery mechanism between live nodes |
| `docs/governance/GOVERNED_TASK_ENVELOPE_SPEC.md` | Bounded neutral dispatch container | Runtime node-to-node transport |
| `ops/bindings/wave.lifecycle.yaml` | Multi-lane lifecycle and receipt expectations | Autonomous lane dispatch and collection |
| `ops/bindings/role.runtime.control.contract.yaml` | Runtime roles including `worker` and `librarian` | Git-aware librarian behavior and deployed lane choreography |
| `ops/bindings/session.admission.contract.yaml` | Lane-specific admission and posture | Cross-surface continuity without manual relay |
| `ops/bindings/launchd.runtime.contract.yaml` | Headless scheduled execution posture | General-purpose multi-node execution orchestration |
| `wave.execute`, `wave.finish` | Governed wave primitives | Parallel multi-node use as standard operating mode |
| Attestation and receipt surfaces | Structured proof of execution | Unified aggregation and synthesis across lanes |

The spine has the vocabulary.
It does not yet have the wiring.

## What The Campaign Proved

The March 2026 campaign proved that:

- bounded governed work packets can land cleanly
- tranche-by-tranche remediation is a viable execution pattern
- receipts, status artifacts, and campaign updates can stay in sync
- the engine now supports disciplined iterative change better than it did in
  the prior 90 days

It also proved the remaining gap:

- routing still depends on a human carrying packets between surfaces
- receipt synthesis still depends on a human pasting outputs around
- controller intent is not yet delivered directly to execution nodes
- the system does not yet hold a durable git-aware memory of multi-lane work
  without operator shepherding

## The Human Message Bus Failure Mode

The anti-pattern is not only "manual work."

The specific failure mode is:

- the operator becomes the message bus
- work quality may still be high, but throughput and autonomy remain bounded by
  one human moving state between windows
- context can still be lost between surfaces
- the system can appear multi-node in doctrine while still behaving as a
  single-threaded manual relay in practice

This document names that condition as a first-class architectural gap.

## The Desired Node Flow

The node model is not only about machine placement.
It is also about communication topology.

The target communication flow is:

1. Operator -> Translator
2. Translator -> Controller
3. Controller -> Execution lanes
4. Execution lanes -> Receipt / attestation store
5. Watcher or librarian -> ledger and state observation
6. Controller -> synthesized result
7. Translator -> human-readable rendering
8. Operator -> next election

In that end-state:
- the translator remains a membrane, not an executor
- the controller remains responsible for governed dispatch and synthesis
- execution nodes perform bounded work only
- watcher and librarian functions preserve state memory and auditability
- the operator remains the strategic authority, not the transport layer

## Watcher And Librarian Clarification

Current repo truth names both a `watcher_node` and a `librarian` runtime role,
but they are not yet wired into the full autonomous pathway.

Current truth:
- `watcher_node` in `node.role.contract.yaml` is observation-oriented and does
  not mutate state
- `librarian` in `role.runtime.control.contract.yaml` exists as a close-role
  alias and governance handoff destination

Required future truth:
- a git-aware ledger function must observe what landed across lanes
- that function must not become an uncontrolled publisher or merger
- it must know what happened without relying on chat pasteback

This document does not lock the final implementation shape. The future system
may realize this as a watcher-adjacent node, a librarian service, or a paired
watcher-plus-librarian flow. What is fixed here is the need for the function,
not the final deployment detail.

## Prerequisites Before This Can Exist

Autonomous multi-node operation is not the next implementation step. It depends
on earlier truths being completed first.

The required prerequisites are:

1. Ownership truth
   - Capability reconciliation must finish so live capability ownership is not
     ambiguous.
2. Layer truth
   - The primitive-function pass described in
     [`PLATFORM_LAYER_MODEL.md`](PLATFORM_LAYER_MODEL.md) must classify what is
     L1, L2, and L3.
3. Extraction truth
   - Product and shared-boundary extraction must be explicit before work can be
     safely distributed across nodes without hidden coupling.
4. Git workflow truth
   - Push, branch, PR, and remote-sync discipline must become governed process,
     not memory.
5. Node-to-node dispatch truth
   - The controller needs a governed way to deliver bounded work envelopes to
     execution nodes.
6. Receipt aggregation truth
   - Receipts from multiple lanes must be collected, normalized, and
     synthesized without manual pasteback.
7. Librarian or ledger truth
   - The system needs a git-aware state memory that observes what landed across
     lanes.

## Phase Dependency Chain

The current intended order is:

- Phase 2: companion contract
  - done
- Phase 3: metabolism audit
  - done
- Phase 4: capability reconciliation against live surfaces
  - in progress
- Phase 4.5: layer classification pass
  - next major governed concern after ownership truth lands
- Phase 5: domain extraction and shared-boundary clarification
  - after layer truth
- Phase 6: autonomous multi-node operation
  - after extraction boundaries, node deployment posture, and node-to-node
    protocol are clear

This ordering is intentional.
The autonomous future is the destination, not the excuse to skip boundary work.

## Why This Matters Now

This vision must exist before implementation because the system is already
generating evidence of the gap.

Every triage wave the operator routes by hand is proof that:
- the work packet model is good
- the operator transport model is bad

If this vision remains only in conversation, later sessions will optimize
isolated surfaces again and reintroduce the same dependency on Ronny as glue.

Persisting the vision now keeps future work aligned with the actual purpose:
- not just better isolated nodes
- but a self-routing governed flow between them

## Non-Goals

This document does not authorize:
- immediate implementation of autonomous multi-node dispatch
- bypassing translator boundaries
- bypassing governed attach or receipt requirements
- skipping the remaining ownership reconciliation work
- skipping the layer-classification pass
- collapsing watcher, librarian, controller, and translator into one authority
- unguided scheduler expansion without explicit node-to-node contracts

This is vision truth, not implementation authorization.

## Governing Implication

This concern is `new_truth`.

It defines the operational end-state the spine is being built toward:

- the spine should coordinate itself across nodes
- the operator should review and elect, not manually relay packets
- receipts, git state, and wave state should be aggregated by the system
- node role doctrine must eventually become deployed workflow, not only
  vocabulary

The current campaign should finish first.
The future autonomous multi-node concern should be elected only after the
remaining prerequisite truths are in place.

## Operator Statement Preserved

The operator's intent being preserved here is:

> The whole point of the last three days was to stop being the glue.

And more specifically:

> My goal is nodes where one spine controller node can get the task from the
> translator node and understand that all the capabilities need to be
> reconciled. The importance of the work over the last 3 days is exponentially
> more impactful than the last 90 days. I want to ensure this is being thought
> about at this level and communicated end to end.

That statement is now repo truth.
