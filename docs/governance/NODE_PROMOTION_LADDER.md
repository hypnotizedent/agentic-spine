---
status: authoritative
owner: "@ronny"
last_verified: 2026-04-14
scope: l1-node-promotion-ladder
---

# Node Promotion Ladder

This document defines how a "node" becomes real in the spine.

A node is not a machine with a label.

A node is a promoted role with:
- role truth
- workload truth
- candidate host truth
- bootstrap and join proof
- runtime materialization
- observability
- separation and failure truth

If those are not present, the system has a candidate, not a delivered node.

## Why This Exists

The spine has two different truths that must not be collapsed:

1. Taxonomy truth
   What kinds of nodes may exist in the system.
2. Delivery truth
   Which nodes are actually real, running, and provable today.

Without this distinction, naming inflation replaces architecture. A machine gets a role name before it has the proof required to carry that role.

## The Core Rule

Taxonomy is vocabulary.

Delivery is promotion.

The spine grows by promoting node roles through evidence-backed stages, not by naming more machines.

## Supporting Doctrine

The promotion ladder does not stand alone.

It depends on two supporting truths:

1. taxonomy is necessary but insufficient
2. delivered nodes must remain honest over space and time

These supporting truths are doctrine inside the ladder. They are not separate governance products.

## The Promotion Ladder

The canonical promotion ladder for a node is:

1. `taxonomy`
   The role exists as part of the node vocabulary.
2. `contracted`
   The role has authority, scope, and failure boundaries in governed contract surfaces.
3. `workload-backed`
   The role has intended workloads or runtime responsibilities, not just a name.
4. `candidate-backed`
   A real machine or VM candidate is identified and assessed against the role.
5. `bootstrap-joined`
   The host can be reached, identified, and joined into governed surfaces.
6. `materialized`
   The role's runtime shape exists on the target platform.
7. `delivered`
   The role is installed, activated, observable, and meets its acceptance bar.

Anything short of `delivered` is not a finished node.

## What Counts As Proof

For a node to be treated as real, the spine must be able to show:

- a governing contract for the role
- intended workloads or explicit runtime obligations
- a specific host or host class that can carry the role
- proof that the host joined cleanly
- proof that the runtime shape exists on that host
- proof that the runtime is actually running
- proof that logs, status, or other observability surfaces can see it
- proof that its failure boundary matches the role contract

This is what makes a node first-class.

## What The Spine Has Achieved Since 2026-03-25

Since 2026-03-25, the spine moved from role ideas and overloaded machines toward a real promotion system.

The important shifts are:

- `operator_console` became explicit instead of ambient.
- `execution_host` became explicit instead of "whatever machine is awake."
- verify and status surfaces were made more honest.
- Stage 0 bootstrap became governed enough to stop bad starts.
- `macbook-2016-pro` became a successful Linux bootstrap and post-bootstrap join proof.
- watcher runtime materialization on Linux became real enough to install and verify.

This means the spine is no longer only a taxonomy and a set of notes. It now has a visible promotion ladder.

## Current L1 Position

The current L1 silver-living MVP node kit is:

1. `operator_console`
2. `execution_host`
3. `watcher_node`
4. `verification_node`
5. `storage_evidence_node`

Current delivery posture:

- `operator_console`: live
- `execution_host`: live
- `watcher_node`: delivered
- `verification_node`: defined, not yet delivered
- `storage_evidence_node`: defined, not yet delivered
- `translator_node`: explicitly later, not part of the current MVP

`execution_host` delivery is now governed by the standard in
`ops/bindings/node.role.contract.yaml`. Active runtime labels are observation;
delivered execution_host status requires runtime placement proof, Linux path
resolution proof, and a fresh execution-pickup recovery drill receipt. Today the
only host meeting that standard is `ai-consolidation`.

This is the smallest node kit that proves the spine is engineering a real governed multi-node system rather than a laptop-plus-VM improvisation.

## Role Delivery Is More Important Than Machine Count

The target is not "more VMs" or "more hardware."

The target is:

- fewer accidental runtime surfaces
- more first-class node roles
- clearer authority
- clearer workload placement
- clearer failure boundaries

The system should not grow by acquiring machines and then inventing roles for them.

It should grow by:

1. defining a role
2. defining its proof bar
3. selecting a host
4. delivering the role cleanly

## How The 77-Node Taxonomy Fits

The 77-node list is valid as taxonomy.

It is not valid as an immediate deployment plan.

The taxonomy answers:

"What kinds of node functions may exist in the final system?"

It does not answer:

- which of these deserve dedicated machines now
- which are shared roles inside another node
- which are future architecture
- which are blocked by current aperture or runtime gaps

Not every named node becomes a machine.

The taxonomy is the vocabulary of possible node functions.
The promotion ladder is the mechanism that decides which of those functions become real nodes.

## Taxonomy Is Necessary But Insufficient

Taxonomy gives the spine a vocabulary.

Taxonomy alone does not make nodes real.

Every serious node promotion decision must also survive adjacent models:

- `identity`
  Which specific instance is this, and what does it supersede or replace?
- `placement`
  Where can this role live, and what placements are anti-patterns?
- `contracts`
  What is the role allowed, required, and forbidden to do?
- `realization`
  How does this abstract role become a real runtime on a real host?
- `verification`
  How will the spine prove the node is actually behaving as claimed?
- `lifecycle`
  How does the role enter service, degrade, retire, or get replaced?
- `dependency`
  What other roles, paths, or services must exist for this role to stay honest?
- `economics`
  What is the real cost of dedicating hardware or preserving separation here?
- `failure`
  What breaks when this role fails, and what must remain separate from it?
- `authority`
  What truth does this role own, and what truth must it never own?

If a role has a name but cannot answer these questions, it is still vocabulary, not delivery.

## Nodes Need Physics, Not Just Names

A delivered node can still become dishonest over time even when its initial promotion looked correct.

Three supporting models act as the "physics" next to taxonomy:

- `topology`
  Spatial truth. Where the node lives, what it is near, what it must be separated from, and how distance or locality affects it.
- `entropy`
  Decay truth. What is drifting, rotting, fragmenting, or becoming unreliable even when the node still looks green.
- `metabolism`
  Flow and transformation truth. What inputs, outputs, jobs, and state transitions move through the node over time.

These are not extra promotion stages.

They are decision filters that strengthen the existing stages, especially:

- `contracted`
- `workload-backed`
- `materialized`
- `delivered`

If a node is promoted without topology truth, placement becomes accidental.

If a node is promoted without entropy truth, temporary exceptions harden into silent rot.

If a node is promoted without metabolism truth, runtime flow and transformation become illegible.

The spine must use these models to keep delivered nodes honest, not just to justify new names.

## VM Supersession Rule

Current VMs should be superseded by first-class nodes only when node contracts own workload placement first.

That means:

- a VM is not automatically a node
- moving a label from "VM" to "node" without contract and workload truth is relabeling, not progress
- a VM becomes implementation detail once a first-class node role owns:
  - authority
  - workloads
  - runtime shape
  - observability
  - failure posture

The correct sequence is:

1. promote the node role
2. bind the workloads to the node role
3. deliver the runtime on a host
4. let the old VM-shaped view become secondary or retire

This is what "vertically aligned" means in the spine:

- idea
- contract
- workload
- host
- runtime
- logs
- failure behavior

all tell the same story.

## Role Runtime Promotion Closure

When a physical node, appliance, VM, or service takes over work from another
runtime, treat the move as one role-runtime promotion closure. Do not begin with
the most visible example word. Begin with the existing first-class homes and
prove that every plane tells the same story.

The one way of doing this is:

1. **Bootstrap / first touch**
   Use `fleet.admission.contract.yaml`,
   `fleet.admission.classification.yaml`, and the governed bootstrap or
   first-touch capability. Discovery, DHCP, SSH, BMC, Proxmox visibility, and
   self-report are evidence only. They do not admit, place, or promote the
   machine.
2. **Admission / identity**
   Read `node.admission.status`. Admission records what the machine is and what
   evidence exists. It does not assign runtime duty by itself.
3. **Role contract / workload ownership**
   Use `node.role.contract.yaml` and this ladder. A workload moves because a
   role owns it, not because a host happens to be reachable or spacious.
4. **Runtime and placement**
   Use `vm.lifecycle.yaml`, `infra.placement.policy.yaml`,
   `infra.storage.placement.policy.yaml`, and
   `relocation.closure.contract.yaml` for VM/service moves. A VM or appliance is
   implementation detail once role/workload/runtime truth exists.
5. **Storage and payload custody**
   Use `service.data.lifecycle.registry.yaml`,
   `storage.scaffold.authority.yaml`, and `payload.custody.status` for durable
   paths, staging, archive, tombstone, and transfer truth.
6. **Backup and recovery**
   Use `backup.inventory.yaml`, `backup.locality.contract.yaml`,
   `backup.status`, and `backup.estate.readback.status`. The new runtime is not
   delivered until its restore or rebuild path is current and old backup truth is
   demoted or retired.
7. **Watcher / observability**
   Use witness surfaces such as `watcher.health`,
   `watcher.input.projection.status`, `observability.context.status`, and
   `prometheus.targets.status` to prove visibility. Observability is witness
   truth; it must not decide placement, admission, backup, or role authority.
8. **Projection / operator readback**
   Regenerate or verify generated projections only from living authorities. If a
   stale generated file, design note, dashboard, or expert diagnostic can still
   make the old runtime sound current, the promotion is not closed.
9. **Retirement**
   Use `lifecycle.closure.contract.yaml` and the relevant VM/service/appliance
   controls to mark the old source as rollback hold, retired, tombstoned, or
   purged. A destroyed VM, disabled service, or deleted backup is not closure
   unless the authoritative state and readbacks say the same thing.

This sequence is not a new subsystem. It is the closure behavior already
required by the promotion ladder, first-class change closure, relocation
closure, backup authority, storage custody, and witness-only observability.

Examples such as Pi-hole, Frigate, observability, or a new Dell are test cases,
not scope boundaries. Agents must identify the systemic promotion family first,
then apply the existing homes above to the concrete example.

## Current Delivery Order

For the current MVP, the delivery order is:

1. `watcher_node`
   Because it closes the scoped `execution_host` external-escalation exception.
2. `verification_node`
   Because it removes self-verification as the default posture.
3. `storage_evidence_node`
   Because it forces explicit physical ownership of canonical state.

`translator_node` remains later work. It is not part of the current MVP.

## Canonical Non-Goals

This document does not:

- assign hosts to node roles
- activate runtime on any host
- declare every taxonomy item a dedicated machine
- commit to a final topology for every role
- replace machine-readable role contracts

This document defines the promotion model only.

## Canonical Test

The spine is getting better only if the same role can move through the ladder with less improvisation over time.

The proof is not more names.

The proof is:

- clearer role truth
- cleaner host selection
- faster bootstrap
- cleaner runtime materialization
- cleaner observability
- cleaner delivery

That is how nodes grow through the spine.
