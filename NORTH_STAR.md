---
status: draft
audience: agents
scope: platform-identity
---

# What The Spine Is

The spine is a recovery-first governed execution system.

It exists to preserve truthful, repeatable, unattended, recoverable work across
models, tools, terminals, and nodes without depending on chat memory, a single
vendor surface, or one workstation staying special.

The spine is correct only if it reduces operator friction when the estate is
under stress.

The spine is a clean, honest work culture guided by a human steward. Governance
artifacts exist to preserve, advance, and verify the meaning of the work; they
are not the source of meaning and must not turn human guidance into parked
administrative residue.

Recovery is the test.

Model independence, tool independence, and node portability are platform
properties, not future aspirations.

## The Core Is A Machine Coordination Kernel

The center of the spine is machine-to-machine coordination, not human
notification.

The core protocol every node and model must obey:

- request
- claim
- heartbeat
- result
- failure
- receipt

The canonical authority matrix for these primitives — what each one is, where it
lives, and what is canonical vs derived vs undefined — is in
[`docs/governance/KERNEL_PRIMITIVE_CANON.md`](docs/governance/KERNEL_PRIMITIVE_CANON.md).

Any model, terminal, or node must speak this same protocol even if it reasons
differently.

Human alerting, escalation, and operator notification are rails off the side of
this core, not the center.

They are adapters.

They attach to the kernel, they do not define it.

## Platform Identity

The spine owns boring, generic, estate-critical truth:

- identity
- storage
- backup
- recovery
- maintenance sequencing
- minimal verification
- explicit terminal identity, execution class, and node-role truth for portable execution
- machine coordination kernel

Execution classes and node roles are platform truth.

Specific hosts are deployment variables outside L1.

The spine must know what work belongs to which execution class and node role.

It must not hardcode which machine fills that node role.

A new node joins by attaching to the spine, declaring its local node role, and
materializing only the work legal for that node role.

The plumbing must work out of the box for the next new computer or node.

## The Control Plane Is Node Architecture

The target is not the human steward's workstation carrying control, execution,
and memory by force of habit.

The target is a node architecture with explicit responsibility boundaries:

- `operator_console` admits and observes work
- `execution_host` carries unattended execution
- `watcher_node` proves liveness and escalation from outside the watched node
- `storage_evidence_node` owns durable runtime truth and receipts
- `verification_node` attests read-heavy truth

The operator workstation is a client of that system.

It may open terminals into the control plane, but it must not be the glue that
keeps the control plane alive.

## Distribution Authority

The canonical repository is self-hosted Gitea at `git.ronny.works`.
All development, all commits, and all branch authority flow from Gitea.

GitHub (`github.com/hypnotizedent/agentic-spine`) is a read-only
distribution mirror. It receives pushes from the canonical repo.
It does not receive direct commits, merges, or pull requests.

Issues, discussions, and contributions should reference the canonical
Gitea instance. GitHub is a window, not a door.

## What It Is Not

- Not a special-laptop control plane
- Not a pile of workstation-local glue
- Not a bucket of domain apps
- Not a human alert queue mistaken for a coordination bus
- Not governance paperwork mistaken for platform truth
- Not aperture compliance mistaken for preserving the meaning of the work
- Not a system that sounds coherent while recovery is unproven
- Not a platform whose health can be green while canonical surfaces are stale
  or ambiguous
- Not defined by any specific host, VM, dataset name, or domain workload

## Core Invariants

### I1. Recovery Is First-Class

The platform must preserve at least one proven path back in when the host is
down, the overlay network is down, services are down, and secrets are
unavailable.

Installed is not done.

Documented is not done.

LAN-only reachable is not done.

Done means tested console, tested power control, and at least one completed
disaster drill.

### I2. The Operator Workstation Is A Client, Never Substrate

No critical platform behavior may depend on a workstation staying logged in,
mounted, or healthy.

No background duty, scheduled job, share publication, FUSE mount, local
wrapper, or launch agent may carry estate-critical runtime weight on an
operator workstation.

Long-lived background duties run on governed nodes.

The workstation opens a terminal into the system; it is not the system.

### I3. Scheduled Work Is Role-Driven And Host-Portable

Every scheduled label declares an intended node role.

Every host materializes only labels matching its declared local role.

L1 must not require hardcoded per-host binding.

A new node joins the estate by declaring its role and inheriting correct
behavior.

### I4. Governance Is Not Completion

A change is done only when:

- the procedure executed
- the resulting runtime path works
- the resulting recovery path works
- the authoritative state reflects the new reality
- obsolete or transitional truth is retired

Receipts that report green on unclosed state are lies and must fail hard.

### I5. Retirement Must Propagate

When a binding, capability, generator, wrapper, label, or surface is retired at
the gate layer, the filesystem and code layers must also stop producing.

The engine must refuse to commit until propagation is complete.

Gate-says-dead and disk-says-alive is a platform lie.

### I6. Canonical Read Surfaces Must Be Unmistakable

A canonical surface must be discoverable, current, and regenerable from living
sources.

Stale projections, orphaned generated files, dead wrappers, and shelves that
look canonical but are not are forbidden.

If a surface cannot be regenerated from current truth, it is not canonical.

If an agent can open the wrong file and still sound plausible, the platform has
not made truth sharp enough.

### I7. Telemetry And Receipts Must Be Discoverable Through The Live Capability Surface

If agents must drop to direct shell inspection to learn the state of a critical
maintenance, storage, or recovery operation, the governed surface has failed.

Receipts and telemetry for any estate-critical class of work must be reachable
through the same capability layer agents already use.

### I8. Names Must Equal Meaning

Dataset name, mountpoint, share name, label name, and human meaning must align.

Historical names and migration residue are not truth.

If a surface is born temporary, it must drain or be retired.

If it persists, it must be renamed into truth.

## Closure Rule

A change is not complete until all of the following are true:

- the procedure executed successfully
- the resulting runtime path works
- the resulting recovery path works
- the authoritative state reflects the new reality
- obsolete or transitional truth is retired

Procedural governance without state closure is incomplete work.

## Truth Rule

A surface is allowed to act as current truth only if it is:

- discoverable
- current
- canonical
- regenerable from living sources

Historical residue, transitional shims, dead wrappers, and orphaned generated
files must not masquerade as live truth.

If an agent can read the wrong file and still sound plausible, truth is not
sharp enough.

## Layer Contract

L1 owns:

- role truth
- canonical read truth
- identity, storage, backup, and recovery truth
- maintenance sequencing
- retirement propagation
- telemetry discoverability
- truthful materialization rules
- the machine coordination kernel

L2 owns reusable boundaries across workloads:

- reachability and identity resolution
- secrets access status
- host and guest control
- recovery-plane access
- backup and snapshot visibility
- publication and browse adapters
- human notification rails

L2 must be agent-obvious.

L3 owns workload-specific logic, health, and product behavior.

L3 must not pull platform truth upward into product-local glue.

L3 depends on L1 and L2 surviving.

L1 and L2 must never depend on L3 surviving.

Deployment variables, including which machine fills which role, live outside L1
and must not leak into it.

## Verify Rule

Minimal verification must answer:

- is attach truthful
- are canonical surfaces actually canonical
- is role and materialization behavior truthful
- is identity, storage, backup, and recovery coherent
- is a recovery path known and proven
- is any critical platform behavior anchored to a workstation
- is retirement propagation honest
- are critical maintenance and recovery surfaces discoverable to agents
- do machine coordination primitives work uniformly across models and nodes

Verification exists to protect operator continuity, not to increase paperwork.

Fewer gates, sharper gates.

## Admission Rule

A new capability, binding, adapter, or doctrine surface belongs here only if it
does at least one of:

1. strengthens the platform as a recovery-first governed execution system
2. sharpens one of the estate-critical truths owned by L1
3. strengthens a shared adapter boundary required by multiple workloads
4. improves agent discoverability of critical maintenance, verification, or
   recovery paths
5. strengthens the machine coordination kernel

It does not belong here if it:

- makes one workstation more special
- adds ambiguity to canonical truth
- preserves historical names over current meaning
- introduces product-specific clutter into L1
- hardcodes a host, VM, or machine into L1
- increases governance surface without increasing recoverability
- treats human notification as if it were the coordination core

## The Standard

The spine is judged by one question:

When the estate is under stress, does it reduce operator friction or add to it?

If it adds friction, hides truth, depends on a special laptop, leaves recovery
unproven, or confuses human notification with machine coordination, it is
wrong.

Everything else is commentary.
