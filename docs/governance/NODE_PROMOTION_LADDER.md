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
- `watcher_node`: proved candidate, not yet delivered
- `verification_node`: defined, not yet delivered
- `storage_evidence_node`: defined, not yet delivered
- `translator_node`: explicitly later, not part of the current MVP

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
