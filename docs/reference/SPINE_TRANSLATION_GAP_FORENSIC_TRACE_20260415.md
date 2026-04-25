---
status: draft
owner: "@operator"
date: 2026-04-15
loop_id: LOOP-SPINE-TRANSLATION-GAP-FORENSIC-TRACE-20260415
scope: spine-translation-gap-forensic-trace
type: forensic-packet
posture: read-heavy-operator-analysis
---

# Spine Translation Gap Forensic Trace

## Purpose

This packet captures the operator forensic read that the core problem is not
primarily an execution gap. It is a translation gap across live spine layers
that use different vocabularies and do not yet compose into one machine-queryable
estate object.

This packet is intended to persist the analysis in repo authority-adjacent form
so continued discussion can anchor to a governed loop and a canonical path,
instead of remaining in chat residue.

## Core Claim

The spine currently has at least four materially different truth planes:

1. Governance truth
   Node-role vocabulary such as `execution_host`, `operator_console`,
   `watcher_node`, `verification_node`, and `storage_evidence_node`.
2. Inventory truth
   Machine, VM, and workload vocabulary such as app-plane, data-plane,
   hypervisor, shop/home placement, and host hardware identity.
3. Verify truth
   Infrastructure and parity vocabulary such as reachability, storage health,
   gate parity, and surface honesty.
4. Execution-plane evidence truth
   Receipts, loop state, runtime state, and cross-terminal continuity artifacts.

Each plane is individually more honest than before. The problem is that they do
not share one canonical vocabulary for "what this live thing is in the spine,
what role it actually holds, what work it is allowed to do, how it is verified,
and what evidence proves that right now."

## Layer Trace

### 1. Governance speaks node-role vocabulary

`ops/bindings/node.role.contract.yaml` defines a mature role vocabulary with:

- node types
- authority matrices
- physical separation posture
- failure expectations
- replacement posture
- exceptions and retirement notes

This layer is rich, but device-agnostic by design. It explicitly says it governs
taxonomy and authority, not deployment or machine assignment.

### 2. Inventory speaks workload and host vocabulary

`vm.lifecycle.yaml`, `hardware.inventory.yaml`, `operator.hardware.inventory.yaml`,
and `ssh.targets.yaml` describe machines, VMs, workloads, sites, IPs, users,
constraints, and readiness.

These surfaces answer:

- what machine exists
- where it lives
- what stack or workload it carries
- how to reach it

They do not cleanly answer:

- what node role this machine currently realizes in the spine
- whether that role is candidate-backed, bootstrap-joined, materialized, or delivered

### 3. Verify speaks infra-health and parity vocabulary

The G-gates prove baseline estate and infrastructure conditions.
The D-gates prove parity, topology, discipline, and governance coherence.

This layer answers:

- is the surface reachable
- is the gate topology coherent
- are bindings and projections aligned
- is runtime/state discipline honest

It is weaker at answering:

- is the live estate behaving according to node-role contract semantics
- is the claimed role actually materialized with its required obligations

### 4. Execution-plane evidence speaks receipts and continuity

The runtime and evidence roots carry loop scopes, orchestration state, receipts,
cap runs, and handoff artifacts outside the repo.

This is correct for operational state separation, but it means execution evidence
is not naturally visible from committed authority unless a session explicitly
loads or references it.

## Primary Translation Failure

The central failure is semantic non-isomorphism between:

- node-role truth
- machine/workload truth
- infra-health truth
- execution evidence truth

The repo has strong individual surfaces for each. It does not yet have a single
canonical translation object that binds them together for one live estate unit.

That absence produces operator-visible drift:

- nodes feel "floating"
- topology takes multiple file joins to infer
- verify can pass while role semantics remain unproven
- terminals can reason from committed authority and miss fresh execution evidence

## Concrete Specimens

### Specimen A: `macbook-2016-pro` as floating node

The machine exists in `ops/bindings/operator.hardware.inventory.yaml` as
operator-owned hardware with `platform: linux`, explicit constraints, and an
ineligible posture after failed bootstrap expectations.

It does not live in VM inventory because it is bare metal.
The default infra verify family is VM and infrastructure centric.
The node-role contract remains device-agnostic and does not assign the machine
to a realized node role.

Result:

- the machine exists
- it is governed as hardware
- it is discussable as a node candidate
- but it is not represented as one coherent realized spine object

This is the "floating node" symptom.

### Specimen B: bootstrap preflight timing

The host/bootstrap surface matured late relative to operator pain.
Stage 0 connectivity preflight landed on 2026-04-13, after the operator had
already experienced bootstrap friction around Wi-Fi and prerequisite assumptions.

This means the bootstrap pain was not just procedural sloppiness. It exposed an
actual missing producer in the governed flow at the time of use.

### Specimen C: receipt blindness across terminals

Runtime state is intentionally externalized under `~/code/.runtime/spine`, and
the root authority contract explicitly treats split-brain and broken continuity
as damage modes.

However, a second terminal that does not explicitly load or consult fresh runtime
evidence can still reason from committed authority and regenerate work that was
already executed elsewhere.

This is not merely prompt discipline failure. It is a structural visibility gap
between committed truth and runtime truth.

### Specimen D: aperture tax

The aperture is now the canonical agent entry surface.
That makes policy extremely clear.
It also means architecture-affecting changes often require manual policy-layer
reconciliation before the system can honestly absorb them.

Because the translation bridge across governance, inventory, verify, and runtime
is incomplete, the aperture burden becomes visible as repeated manual updates and
projection maintenance.

### Specimen E: `routing.dispatch.yaml` as ghost map

`routing.dispatch.yaml` remains present as a large routing projection even though
the generator that produced it was deleted and two of its three source surfaces
were deleted with it during the spine-lite pass.

That makes the file more dangerous than ordinary staleness:

- it still exists
- it still sounds authoritative
- it is not regenerable from living sources
- there is no mechanical way to know which subset of its 734 routes remain true
  without rebuilding the lost generation path or replacing it entirely

An agent that reads it as routing authority is not merely reading old data.
It is reading a dead map whose error surface is unknown.

## Supporting Repo Evidence

### Governance evidence

- `AGENTS.md` establishes the current aperture as the canonical entry surface and
  restricts change to conservative post-stabilization operator-surface work.
- `docs/governance/NODE_PROMOTION_LADDER.md` correctly distinguishes taxonomy
  truth from delivery truth and says a node is not real until promotion is
  evidenced through bootstrap, materialization, observability, and failure truth.
- `ops/bindings/node.role.contract.yaml` contains a mature role model, but it is
  a device-agnostic authority surface rather than a live deployment bridge.

### Inventory evidence

- `docs/governance/DEVICE_IDENTITY_SSOT.md` still presents itself as a single
  source of truth for device identity and opens with an active routing
  instruction telling agents to check it before referencing hostnames, device
  roles, or Tailscale/LAN IPs. That means it is not merely stale. It is a live
  redirect toward March 22 truth.
- `ops/bindings/operator.hardware.inventory.yaml` carries fresher operator-hardware
  truth, including `macbook-2016-pro` demotion and `windows-mint` reassessment.
- `ops/bindings/ssh.targets.yaml` carries access-path truth and recovery hints,
  which means access semantics are yet another adjacent plane that must be joined.
- `ops/bindings/routing.dispatch.yaml` remains in the repo as a large projection
  whose generation path is no longer alive, making it a high-risk stale surface
  for any agent that mistakes it for current routing truth.

### Verify evidence

- `ops/commands/verify.sh` still defaults to the 17-gate infrastructure baseline.
- `ops/plugins/core/verify/lib/spine_scope_gate_set.py` shows that spine-only
  verify is now honest about `executable_now`, `already_covered`,
  `missing_implementation`, `stale_target`, and `out_of_spine_scope`.
- This is an honesty advance, but it also confirms that verify is currently
  classifying incompleteness rather than fully proving role-behavior compliance.

### Authority-concentration evidence

- `docs/reference/L1_L2_L3_PRODUCT_AUTHORITY_AUDIT_20260408.md` explicitly states
  that the remaining monolith is authority concentration and that
  `gate.execution.topology.yaml` still carries live product topology truth.
- The same audit states that `routing.dispatch.yaml` is a 734-route orphaned
  projection that is not regenerable from living sources because the generator
  and two of its three source surfaces were deleted in the spine-lite pass.

### Runtime continuity evidence

- `ops/bindings/root.authority.contract.yaml` names `split_brain_state` and
  `broken_continuity` as first-class damage models.

## Why This Feels Like Repetition To The Operator

The forward motion is real. The engine, wave closeout, status surfaces, and
entry honesty improved materially after 2026-03-25.

But the corrective loop remains externally visible because:

- a change lands in one plane
- another plane still describes older truth
- a gate detects drift or projection mismatch
- the system performs a reconcile/fix/retire pass
- adjacent drift becomes visible

From the operator seat, that appears as the same work being done multiple times.
What is actually recurring is cross-plane translation repair.

## Epistemic Posture Reading

The operator reading is that the spine still defaults too quickly to solving
instead of first locating the true issue in the live estate.

That reading is consistent with repo structure.
Governance and doctrine are strong enough that an agent can sound coherent while
reasoning from intended-state truth rather than current-state evidence.

The machine coordination kernel in `NORTH_STAR.md` is:

- request
- claim
- heartbeat
- result
- failure
- receipt

The present repo still allows too much estate reasoning from governance,
inventory, and parity surfaces before a claim/heartbeat/evidence read has made
current reality explicit.

## Additional Convergence From Parallel Reads

The first and second forensic reads are complementary rather than redundant.
They converged on the same structural signal from different angles:

- one read went harder on commit analytics, authority concentration, and verify internals
- the other went harder on field-level inventory joins, missing `node_role`
  attachment, bare-metal ghost cases, and site/topology inference cost

Where they overlap is the highest-confidence signal.

### Orphaned routing projection as live hazard

`routing.dispatch.yaml` is not merely stale residue.
It is a live-sounding dead map.

The repo currently carries a large routing projection with no living generator,
no full living source set, and no mechanical way to re-derive it from current
truth. That makes it especially dangerous because:

- it sounds authoritative
- it is large enough that selective truth drift is hard to notice
- an agent can read it and reason confidently from unknown-invalid routes

This is one of the sharpest examples of the repo allowing intended authority
shape and actual regenerable authority shape to diverge.

### Active SSOT conflict in device identity

The `DEVICE_IDENTITY_SSOT.md` problem is stronger than simple staleness.

Its header still instructs agents:

- before referencing hostnames
- before referencing device roles
- before referencing Tailscale or LAN IPs
- check this document

That is an active routing instruction toward March 22 truth even though fresher
April 14 operator-hardware reality now lives elsewhere.

So the problem is not only "two files overlap."
The older file still tells agents to stop there.

### Verify green does not mean estate-correct

`spine_scope_gate_set.py` is unusually revealing.
It openly classifies core gates into:

- `executable_now`
- `already_covered`
- `missing_implementation`
- `stale_target`
- `out_of_spine_scope`

That is an honest production posture for a system mid-realization.
It also means a green verify surface cannot be read naively as full estate proof.

At best, the current output means there are no active failures among the gates
that are currently implemented and in scope.
That is a materially smaller claim than "the estate is behaving according to its
full role contract."

### Live example of receipt blindness

The operator manually carrying findings between two parallel agent membranes is
itself a direct specimen of the continuity problem.

Two agents analyzed the same repo in parallel.
Neither had automatic visibility into the other's findings.
The operator had to perform the synthesis by hand.

This is the same structural failure class already named in spine runtime
continuity language:

- execution evidence exists
- but other sessions do not see it unless it is explicitly surfaced
- therefore the operator becomes the broadcast bus

### Aperture is not the bug

The aperture is restrictive, but that is not the core design mistake.
Given the current maturity of cross-layer translation, operator-only aperture
control is the correct conservative posture.

The real friction is that estate changes propagate across too many partially
manual surfaces:

- binding updates
- projection updates
- gate parity checks
- aperture review

So the aperture feels heavier than it should because it sits on top of an estate
whose semantic propagation is still incomplete.

### Control-plane asymmetry

One useful framing from the parallel read is:

"The engine behaves like a kernel. The surrounding authority behaves like a legal system."

This packet's "translation gap" framing and that "control-plane asymmetry"
framing point at the same phenomenon from different altitudes.

The kernel wants direct machine action.
The legal system wants cross-document interpretation and operator judgment.
The current friction comes from asking one estate to operate like both at once.

## Refined Bottom Line

The spine has:

- a stronger engine
- a more honest verify posture
- a more mature governance model

What it still lacks is one mechanical surface that can answer, for a live
machine or VM:

- what node role it currently realizes
- what its promotion state currently is
- what workloads are legal for it
- what site/topology it belongs to without multi-file inference
- what evidence proves that now

Until that surface exists, autonomy remains bounded by the amount of cross-layer
joining the operator is willing to perform manually in each session.

## Operator Ideology And Discipline Inputs

The operator standard being applied to this forensic read is not merely
"make it work."

The spine is expected to express the following properties at every layer:

- calibration
- parsimony
- legibility
- idempotency
- atomicity
- reversibility
- orthogonality
- traceability
- coherence

These are not decorative values.
They are the cultural and doctrinal bar for whether the spine is behaving like
a governed machine coordination system rather than a pile of compensating habits.

The nine properties are not a post-hoc checklist.
They are a pre-synthesis filter.

Every surface, capability, packet, prompt, and binding change is expected to
pass through them implicitly before output exists at all.

### Reading of those properties in current context

- calibration: the system should describe only what is actually true now
- parsimony: the number of moving surfaces needed for a routine action should be minimal
- legibility: a machine, node, packet, or receipt should be understandable without multi-hop interpretation
- idempotency: rerunning the same bounded step should converge, not fork state
- atomicity: steps should close as one state transition rather than partial mutation plus later cleanup
- reversibility: temporary or wrong moves should be backout-capable without archaeology
- orthogonality: topology, identity, workload, and verification concerns should not bleed into each other unnecessarily
- traceability: a current claim should point back to its governing packet, evidence, or authority chain
- coherence: all live surfaces discussing the same thing should agree on what it is

### Operator doctrine statement for the nine properties

**Calibration**

Every authoritative surface should state:

- what it knows
- when it was verified
- by what method

A surface missing those fields is not fit to act as authority.

**Parsimony**

One surface per concern.
If a new surface is introduced for an existing concern, some older surface
should be retired or demoted. Otherwise the spine accumulates parallel truth.

**Legibility**

An agent should be able to read one live surface and understand:

- what this machine is
- what it is allowed to do
- what zone or class it belongs to

Zero multi-file joins for basic estate cognition is the target posture.

**Idempotency**

Repeating a safe bounded operation should converge, not fork state.
If repeated execution accumulates unintended side effects, the surface is
violating contract.

**Atomicity**

Changes should land completely or fail clearly.
Half-updated bindings, partial packet writes, and "close enough" state are all
anti-properties under this doctrine.

**Reversibility**

Every capability should either have a documented undo path or explicitly declare
that it is irreversible before execution.

**Orthogonality**

Governance should not silently carry inventory truth.
Inventory should not silently carry verify logic.
Verify should not silently carry runtime state.
When a surface crosses concern boundaries, that boundary crossing should be
explicit, narrow, and documented as an adapter.

**Traceability**

Every decision should point to a loop.
Every mutation should point to a wave or equivalent execution artifact.
Every output should point to a receipt.
If current estate state cannot be traced back to a governed production path, it
is ungoverned.

**Coherence**

Governance, inventory, verify, and runtime should speak one shared vocabulary.
This packet's translation-gap diagnosis is fundamentally a coherence diagnosis.

## Workflow Clarity Requirements

The operator expectation is that every governed step should make the following
explicit before synthesis or execution:

- what the current workflow is
- what context is valid
- what policies apply
- what actions are permitted
- what format outputs must take
- what must be loaded before synthesis
- whether a response is safe to execute, save, or forward

This is another way of stating the translation-gap problem.
If a session cannot answer those questions mechanically from the live spine,
the operator must become the interpreter.

## Mailroom As Architectural Pressure Point

The mailroom is not a minor implementation detail in this reading.
It is one of the most sensitive concentration points in the entire system
because it touches:

- evidence
- runtime state
- prompts
- packets
- continuity between sessions and agents

The operator judgment here is that the mailroom currently requires a large
architecture rethink in service of boringness.

The specific symptom called out is path dishonesty and repeated writes to the
wrong place by agent-side cowork or collaboration tooling.
That matters because the mailroom is exactly the place where boringness,
path correctness, and continuity should be strongest, not weakest.

### Mailroom boringness doctrine

Boring means:

- one canonical answer
- mechanically derived
- same every time

The current Cowork/runtime-root behavior is assessed here as a boringness
failure, not a smart-system failure.

The reported pattern is:

- Cowork sees the spine repo through a session-mounted path
- Cowork infers `.runtime/` relative to that mounted repo path
- the operator's real runtime root is an absolute home path under
  `$SPINE_RUNTIME/`
- the two locations are physically different
- therefore Cowork and terminal sessions write to different realities

That makes the mailroom fail two doctrinal tests at once:

- calibration, because the environment is guessing rather than declaring
- atomicity, because a packet may "land" in one view and be absent in another

Under this doctrine, runtime roots should be declared or fail closed.
Inference of runtime roots from relative workspace position is classified here
as non-boring and therefore unfit for a continuity-critical surface.

## Drift Gates As Cultural Reality

The drift gates are read positively in this packet.
They are one of the repo's strongest discipline surfaces because they sweep
the tree clean and expose mismatches that would otherwise harden into folklore.

But the operator judgment is that agents must be aware of them as part of their
working consciousness, not merely encounter them as after-the-fact failure.

If agents do not know the drift discipline before they synthesize, then the
gates function as cleanup rather than guidance.

This packet therefore treats drift-gate awareness as part of session culture,
not merely post-hoc enforcement.

## Foundational Node Classes

The following node classes are part of the operator's architectural vocabulary
for reasoning about what a machine fundamentally is:

| Node Class | Primary Concern |
|---|---|
| `network-node` | routing, switching, firewall, DNS, DHCP |
| `identity-node` | auth, secrets, PKI, zero-trust fabric |
| `observability-node` | metrics, logs, traces, alerting |
| `time-node` | NTP, clock sync |
| `connectivity-node` | VPN mesh, tunnels, WAN bridging |
| `control-node` | provisioning, config management, imaging |

These classes are not interchangeable with workload labels.
They belong to the same family of concerns as the translation-gap problem
because they describe architectural function, not merely host description.

## Spine Engine In One Frame

The operator frame for the spine engine is:

### Discovery

What L3 product does this client need?

- decisions
- presence
- experiences
- artifacts

### Design

Which L2 factory produces that?
Which L1 building supports that factory?
Which L0 atoms does that building require?

### Deploy

Install bottom-up:

- L0
- L1
- L2
- L3

### Govern

Agents run.
The operator maintains the environment.
The client receives the product.

### Scale

Next client.
Same stack.
Different L3 output.

This frame matters because it reveals when the repo is collapsing infrastructure,
product, and control semantics into one undifferentiated surface.

## Functional Zones To Node Classes

The operator's five functional zones are:

1. `SENSE`
   perceive the environment through cameras, microphones, sensors, and IoT endpoints
2. `THINK`
   compute and reason, including light edge inference and heavy deep compute
3. `REMEMBER`
   hold state across databases, files, vectors, archives, and secrets
4. `ACT`
   produce effects across printers, controllers, APIs, and automation endpoints
5. `COORDINATE`
   move work across orchestrators, spine, schedulers, routers, and message buses

This zone model is another architectural vocabulary that the repo does not yet
cleanly project into one mechanical node identity surface.

## Practical Ladder For Node Realization

The operator's practical ladder is:

1. Site hardware intelligence
   "What is this machine and where does it fit?"
2. Site runtime standardization
   "What exact standard role should this machine become?"
3. Provisioning / configuration actuation
   "Apply the shape."
4. Verification / drift / lifecycle
   "Did it stay that way?"

This ladder aligns with the packet's broader finding:
the current repo has strong partial surfaces for each step, but not yet one
mechanically joined path that keeps all four steps in one coherent object model.

This ladder is also a sequencing doctrine.
It cannot be collapsed or reordered without dishonesty:

- a machine cannot be standardized before it is understood
- it cannot be verified before it is provisioned
- it should not be promoted before its role is legible

The reported bootstrap pain is classified here as a ladder violation:
provisioning began before hardware intelligence was complete.

## Claim Step Made Concrete

The operator reduces the kernel's `claim` step to a concrete six-question
pre-flight that should precede synthesis:

1. What context is valid
   Which loop is active and what receipts or prior session evidence already exist?
2. What policies apply
   What does the current aperture and active governance posture permit?
3. What actions are permitted
   Which capabilities and roles are legal in the current context?
4. What format outputs must take
   What contract or output discipline governs the result shape?
5. What must be loaded before synthesis
   Which authority surfaces are mandatory reads before reasoning starts?
6. Whether a response is safe to execute, save, or forward
   Is the action destructive, reversible, idempotent, or safely transmissible?

This packet treats repeated work, path mistakes, and late gate surprises as
symptoms of weak claim discipline before synthesis.

## Functional Zone Mapping

The operator's engine frame maps to the functional zones directly:

- `DISCOVERY` aligns with `SENSE`
- `DESIGN` aligns with `THINK` plus `REMEMBER`
- `DEPLOY` aligns with `ACT`
- `GOVERN` aligns with `COORDINATE`
- `SCALE` is the proof that the taxonomy is portable across hosts and clients

That frame matters because it keeps product demand, infrastructure composition,
deployment sequencing, governance, and portability distinct.

When the repo collapses them into one surface, zone clarity is lost and the
translation burden returns to the operator.

## Steward Interface Diagnosis

The sharpest framing in this loop is that the three green channels in the spine
work because they share protocol on both sides, while steward-to-spine does not.

The currently healthy channels are:

- machine-to-machine
- agent-to-spine
- agent-to-agent

Those channels are comparatively reliable because they already share:

- schema
- protocol vocabulary
- bounded artifact shape
- detectable failure modes

Machine-to-machine has wire format.
Agent-to-spine has capability contracts, loop scopes, and governed surfaces.
Agent-to-agent has controller prompts, receipts, and bounded execution artifacts.

Steward-to-spine is different.
Its input side is natural language:

- shorthand
- typos
- conceptual compression
- incomplete diagnosis
- feeling-language before causal naming

Its output side is governance vocabulary:

- capability ids
- loop ids
- binding paths
- packet contracts
- narrow role and policy surfaces

The translation cost between those two registers is currently paid mostly by the
steward.

That is the deeper interface failure:

- the governance may be correct
- the engine may be correct
- but the human-facing input channel still lacks a first-class protocol layer

### Why this matters

Every time the steward has to:

- remember a file path
- look up a loop id
- restate a concern in governance vocabulary
- translate a feeling into a binding-level diagnosis

the spine has failed to absorb an interface cost that it should own.

This is not an indictment of strict governance.
It is a diagnosis that governance designed for machines will naturally create
friction for humans unless a dedicated translation layer exists and persists.

### Steward model versus owner model

This packet distinguishes two different interface postures:

**Owner model**

The owner commands the system directly in system vocabulary.
Execution assumes deep internal understanding.

**Steward model**

The steward guides the system toward a vision.
The system translates that guidance into internal operations.
The steward abides by governance because they believe in the system's
recoverability logic, not because they want to operate it as a machine engineer
at every conversational turn.

The current pain described in this loop is that the spine repeatedly demands the
steward speak the machine's language.
That is backwards at the interface layer.

### First-class steward understanding

What is missing is not chat memory.
It is a durable, governed, session-independent steward interface model.

This model would need to preserve at least:

- communication patterns
- shorthand vocabulary
- known priorities
- recurring friction triggers

#### Communication patterns

The steward often expresses:

- feeling first
- diagnosis second

Examples of the pattern:

- "this feels wrong" means diagnosis work is needed before action
- "things kept being done multiple times" points to continuity and receipt
  visibility failure, not mere annoyance

Without a durable understanding of that register, agents either over-literalize
or over-generalize the request.

#### Shorthand vocabulary

The steward uses compressed terms that map to governed concepts, for example:

- `aperture`
- `boring`
- `mailroom`
- `nodes`
- `bootstrap`

Today that mapping is partially held in:

- local skill behavior
- adapter behavior
- in-session interpretation
- human memory

That is not durable enough for a primary operator interface.

#### Known priorities

This loop has already surfaced stable priorities such as:

- autonomy
- nodes
- legibility
- multi-location clarity
- bootstrap reliability
- identity and SSH alignment

An interface that cannot preserve those priorities session-to-session forces the
steward to re-establish foundational direction repeatedly.

#### Friction triggers

Stable friction triggers named in this loop include:

- manual aperture updates
- remembering internal paths
- work being done multiple times
- loops not closing
- excess ceremony on low-stakes work

If those triggers are known and durable, the system can avoid generating them.
If they are ephemeral, the operator becomes the recurring friction detector.

### Failure mode without steward protocol

Without a first-class steward interface, agents tend toward two opposite errors:

1. over-literalization
   A broad architectural concern gets collapsed into a narrow local change.
2. over-expansion
   A bounded concern gets expanded into broad mutation or cleanup work that the
   steward did not authorize.

Both failures come from weak translation between natural steward language and
machine governance language.

This is another expression of the packet's broader epistemic posture concern:
the system tries to solve before it has proved that it understands.

### Reflection as interface discipline

For this channel, the missing discipline is not only translation but reflection.

Before execution, the system should be able to confirm:

- what it believes the steward means
- what scope it believes is being authorized
- what vocabulary bridge it is applying

If that reflection step is absent, the system moves from ambiguous human input
to concrete machine action too quickly.

### Governance is bidirectional but asymmetric

This packet's reading is that the governance relationship is bidirectional:

- the steward owes obedience to the recoverability logic of the governance
- the governance owes legibility and low-friction stewardship in return

Strictness is not the issue.
Friction that does not buy recoverability is the issue.

Examples already named elsewhere in this loop:

- manually maintained generated projections
- stale surfaces that still redirect agents toward themselves
- absent durable steward vocabulary bridge

Strict governance is not being criticized here.
Strictness is correct and intentional because it protects recoverability.

The distinction being made is narrower:

- governance strictness that preserves recoverability is good
- friction that does not buy recoverability benefit is waste

This packet therefore locates the burden in the steward interface and
translation layer, not in the existence of strong governance itself.

### Refined channel diagnosis

The missing components for steward-to-spine to be as reliable as the three green
channels are:

- a persistent steward profile as a governed surface
- a durable vocabulary bridge between steward language and spine concepts
- a mandatory reflection step before execution

This packet records those as architectural absences in the current interface,
not as implementation prescriptions.

### Concrete failure modes when steward profile is absent

Two recurring failure modes follow directly from the absence of a durable model
of the steward's communication register:

1. too literal
   The system interprets the steward's words narrowly and executes something
   smaller or more local than intended.
2. too broad
   The system over-interpolates from the steward's concern and expands scope
   into a much larger mutation set than was intended.

These opposite behaviors have the same root cause:
the system does not yet preserve a first-class understanding of how the steward
compresses, signals, and scopes intent.

### Specimen F: feeling-language as diagnostic signal

The steward often states a problem in feeling-language before naming a cause.

Examples from this loop:

- "this feels like X"
- "things kept being done multiple times"
- "not all the way there"

These are not soft preambles.
They are diagnostic signals.

In this communication register:

- "this feels like X" means X is wrong and should be investigated
- "things kept being done multiple times" points toward continuity or receipt
  visibility failure
- unease language is often upstream of a more precise causal model that emerges
  only after reflection

An agent that reads this language literally will act on the surface statement.
An agent with steward understanding will treat feeling-language as a signal to
reflect, restate understanding, and diagnose before acting.

## Current Discussion Anchor

This packet is the canonical repo anchor for continued discussion of:

- translation gap versus execution gap
- floating-node symptoms
- bootstrap timing and missing preconditions
- runtime evidence visibility across terminals
- aperture ceremony as a symptom of incomplete translation wiring
- missing role-compliance semantics between governance, inventory, and verify

It is intentionally forensic.
It does not propose remediation.

## Runtime Packet Family State (2026-04-15)

The translation-gap forensic loop now has a runtime packet family under the
mailroom/state surface rather than the repo. This is intentional.

- the repo holds the forensic authority
- the runtime state holds the controller-ingestable packet set

As of 2026-04-15, the mailroom packet loop contains fifteen packet seams:

- workflow forensics
- steward interface
- mailroom boringness
- node translation
- bootstrap ladder
- identity and SSH truth
- verify role compliance
- receipt visibility
- projection honesty
- aperture friction
- topology and site legibility
- capability alignment
- runtime hygiene
- friction telemetry
- autonomous dispatch

This matters because the runtime packet family is now broad enough to cover the
translation gap, the node-canonical boringness path, the membrane workflow
seam, and the final autonomy bridge without collapsing them into one giant
mutation prompt.

## Capability Registry Facts

The capability registry is more weakly classified than the surrounding audit
language suggests.

Verified directly from `ops/capabilities.yaml` on 2026-04-15:

- total capabilities: `145`
- populated `layer` field count: `0`
- populated `node_role` field count: `0`
- populated `zone` field count: `0`
- populated `functional_class` field count: `0`
- `mutating + approval:auto` capabilities: `36`

This means the L1/L2/L3 classification exists as doctrine and audit language,
but not yet as enforced metadata in the registry controllers actually query.

It also means the registry does not currently encode the membrane/controller
reflection boundary in a way that prevents name-driven capability choice.

## Runtime Hygiene Facts

The runtime residue problem is not hypothetical.

Verified directly from live state on 2026-04-15:

- `17` runtime `WAVE-HONESTY-PROBE` worktrees remain under
  `.runtime/spine/tmp/worktrees/`
- `6` `.claude/worktrees/agent-*` entries are marked prunable
- `1` non-prunable `.claude/worktrees/l3-promotion-spine-followon` worktree
  remains live on commit `bbf7dc6d`
- dead gap-claim files exist for `GAP-OP-1540`, `1542`, `1694`, `1705`,
  `1706`, `1707`, `1708`, `1709`
- an unexecuted lifecycle hygiene controller packet remains in `domain-state`
- overdue plan artifacts remain under `.runtime/spine/state/plans/`

The system is therefore carrying hidden open state across worktrees, gap
claims, plans, and runtime sediment.

## Friction Telemetry Facts

The friction queue is large enough to be a first-class diagnostic surface even
before recurrence normalization is complete.

Verified directly from `friction-queue.ndjson` on 2026-04-15:

- total friction entries: `1213`
- `filed`: `987`
- `closed`: `161`
- `open`: `36`
- `observed`: `21`
- `matched`: `5`
- `queued`: `3`

One earlier read incorrectly described `1052` items as open. That was wrong.
The queue distinguishes `filed` from `open`, and the verified values above are
the authoritative current counts.

What remains unverified at this time is the precise gate-recurrence breakdown,
because the current queue entries do not expose a clean normalized top-level
gate identifier in every row. That normalization gap is itself part of the
forensic problem.

## Autonomous Dispatch Gap

The autonomy bridge is now narrow enough to name precisely.

The spine already has:

- packet substrate
- loop substrate
- receipt and linkage surfaces
- SSH target authority
- launchd and node-role-aware scheduler surfaces
- watcher-driven completion notification

What is not yet proven to exist is a generic first-class capability that takes
a bounded packet, dispatches it to a headless agent process on a target node,
supervises execution there, and returns a governed receipt without operator
prompt injection.

That is why autonomous dispatch is now a distinct forensic packet seam.
The question is no longer "how do we build autonomy in general."
The question is whether the path from packet-in-runtime-state to receipt-on-node
has any hidden operator dependencies left after node enrollment and workflow
forensics are proven.
