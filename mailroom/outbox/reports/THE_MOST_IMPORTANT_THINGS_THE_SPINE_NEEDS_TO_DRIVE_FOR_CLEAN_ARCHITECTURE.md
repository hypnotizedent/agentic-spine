# The Most Important Things The Spine Needs To Drive For Clean Architecture

Status: final-form working authority  
Audience: agents first, operator second  
Scope: the platform corrections forced by failures exposed between 2026-03-25 and 2026-04-09

## Start Here

Read [NORTH_STAR.md](/Users/ronnyworks/code/agentic-spine/NORTH_STAR.md) first.

This document does not replace North Star.
It sharpens it.

North Star says the spine is a production-grade governed execution system.
That means the spine is not judged by how much it can describe.
It is judged by whether it makes real work repeatable, unattended, recoverable, and boring.

This document exists because the platform failed that test in several basic ways.

## The Platform Standard

The spine is for:

- reducing operator friction
- preserving recoverability under stress
- making critical state explicit
- making critical maintenance predictable
- preventing one machine, one terminal, one agent, or one operator from staying special forever

If the platform cannot preserve those properties during failure, it is not mature.

## The Brutal Truth

The spine got bloated because it accumulated surfaces faster than it accumulated hard guarantees.

The operator tolerated that because watching agents fail was informative.
That was useful for learning, but it also exposed the real gap:

- too many capabilities
- too many gates
- too many historical names
- too many stale projections
- too many partial truths
- not enough non-negotiable invariants

The failure was not lack of sophistication.
The failure was lack of closure.

## What Actually Failed

### 1. Capability Count Replaced Capability Importance

The spine had too many capabilities that did not matter when the estate was actually under stress.

The real test was simple:

- can an agent find the correct maintenance path
- can an agent find the correct shutdown and startup path
- can an agent find the correct recovery path
- can an agent distinguish cosmetic cleanup from real risk

The answer was not good enough.

### 2. Backup Truth Was Fragmented

There was not one boring backup plane.

There were historical identities and lanes:

- `backup-cold`
- `backup-holds`
- `tank-backups`
- per-app backup lanes
- `vzdump` lanes
- config lanes

That is not one backup system.
That is drift.

The direct consequence was severe:

- live backup files were moved into `/md1400/backups`
- the old `backup-cold` identity still pinned more than `10T` through snapshots
- an empty-looking path still burdened the pool

That should have been impossible.

### 3. Storage Naming Drift Was Tolerated

The platform allowed names that described history instead of meaning:

- `stage`
- `archive`
- `backup-cold`
- `tombstones`
- dataset names that no longer matched mountpoints
- share names that no longer matched storage truth

That is not cosmetic drift.
It breaks reasoning.

### 4. Physical Change Was Governed But Not Closed

A governed loop is not the same thing as finished truth.

The boot-drive swap proved that.

The dangerous gap was:

- physical work may have happened in a governed loop
- but authoritative hardware truth still described the old arrangement
- the new boot path was not proven and written back as canonical truth

That means the work was not done.

### 5. Remote Recovery Was Not Finished

iDRAC existed, but not as a complete operator surface.

Done means:

- reachable from outside the shop
- known URL or IP
- known tested credentials
- tested virtual console
- tested power control
- at least one real disaster drill

Anything less is unfinished.

### 6. Snapshot Policy Was Invisible Until It Hurt

Snapshots were real.
Snapshots were active.
Snapshots retained terabytes.

But snapshot truth was not treated as platform truth.

On `pve`, the live answer was:

- engine: `sanoid`
- scheduler: `sanoid.timer`
- policy source: `/etc/sanoid/sanoid.conf`
- live names: `autosnap_*`
- effective default policy on `md1400`: `daily=7`, `weekly=2`, `monthly=1`

The actual failure:

- inherited snapshot policy kept old backup identities alive
- empty dataset shells were not harmless
- live files moved away, but capacity stayed pinned

That is not an edge case.
That is a design miss.

### 7. Presentation And Browse Layers Were Allowed To Matter Too Much

`archive`, `live-share`, Samba publication, Finder mounts, MacFUSE, local LaunchAgents, and local bash glue were treated like convenience.

They were not convenience.
They were operating surfaces.

That meant:

- a remote storage concept became entangled with a laptop-local mount surface
- Finder and local user-path behavior distorted the operator's perception of system truth
- toggling local Mac settings affected the operator's ability to reason about the estate

That is not resilience.

### 8. The Operator Workstation Was Allowed To Become Part Of The Runtime

Ronny's MacBook quietly became more than a client.

That is backwards.

The workstation may attach.
It may browse.
It may operate.

It must not become hidden platform substrate.

North Star already says the platform must not depend on one machine staying special forever.
This failure was that warning made concrete.

### 9. Stale Projections And Weak Telemetry Created False Confidence

Recent spine-lite work reduced real dead weight, but it also left stale projection surfaces behind.

That means an agent can still read something that looks canonical while actually reading residue from an older shape of the spine.

At the same time, critical maintenance work on md1400 had to fall back to direct runtime inspection because governed telemetry and receipt surfaces were not obvious enough in the live capability layer.

That is not agent-obvious governance.

### 10. Generic Tombstone And Migration Buckets Hid Meaning

`tombstones` and other generic holding names concealed meaning instead of exposing it.

The actual remaining content was specific:

- `200-docker-host` was a Mint-era cold VM capsule

The name was worse than the contents.

### 11. VM Lifecycle Truth Is Missing

Dead VMs, cold capsules, stale backup lanes, and migrated services are still too dependent on operator memory.

That means the platform lacks one boring lifecycle model for:

- active
- migrated
- cold-capsule
- purge-ready
- deleted

### 12. VM Storage Truth Is Still Too Spread Out

Live VM storage is spread across multiple runtime surfaces:

- `local-lvm` boot disks
- `data-vms`
- `tank/immich`
- `md1400-vms`
- stale `tank-vms` references still attached as `unused` disks

Some of this spread is intentional.
Some is residue.

The problem is that the distinction is not made obvious enough by the platform itself.

### 13. The Platform Could Explain The Correct Flow But Could Not Execute It

This is one of the most important failures from tonight.

The spine could explain the intended lifecycle cleanly:

- report artifact
- deferred plan
- promoted loop
- receipts and evidence
- distilled authority

That explanation felt correct because it was correct.

But the official path did not execute cleanly.

The specific failure was not conceptual.
It was operational:

- the planner capability surface existed
- the plans lifecycle contract existed
- the SQLite authority tables existed
- the projection surfaces existed
- but the actual create path was broken

The live break was simple and unacceptable:

- `planning-plans-create` depended on `plans_sql_authority`
- that module was missing
- the command failed
- direct-write fallback would have required working around the governed path

That means the platform can still describe a boring path without actually providing one.

That is not a small defect.
That is a control-plane failure.

If the system can explain how deferred intent should be persisted, but cannot persist it through its own canonical mutation path, then the operator is pushed back into improvisation.

That is exactly what the spine is supposed to eliminate.

## The Real Correction

The answer is not more gates.
It is fewer, sharper platform guarantees.

The spine must become boring in the places where failure is most expensive:

- identity
- storage
- backup
- recovery
- lifecycle closure

The platform must not only explain the intended lifecycle.
It must execute it end to end through its own canonical paths.

If a report should become a plan, that creation path must work.
If a plan should become a loop, that promotion path must work.
If execution should emit receipts and evidence, those surfaces must be writable and discoverable without operator improvisation.

## The Missing Split: Control Plane Vs Translator Membrane

Two different failures can produce the same bad night:

- the spine does not make the correct authority surface obvious enough
- the translator membrane does not force itself onto the highest-authority surface first

They are not the same failure.
They must not be merged.

### Control-Plane Diagnosis

What the spine is still missing for agents:

- one unmistakable authority order for investigation
- one discoverable starting surface per problem class
- one canonical path from capability to binding to writer to runtime effect
- one boring rule for what must be inspected first before runtime archaeology begins

This is why an agent can still drift from:

- backup writer truth
- to VM runtime symptoms
- to storage side effects

without the platform interrupting that drift.

The information may exist.
That is not enough.

The system must make the correct first surface unavoidable.

For backup drift, the correct order is:

1. capability
2. authoritative binding
3. writer or transport
4. runtime destination
5. live data

If the agent can begin at step 5 and still sound plausible, the control plane is not shaped correctly.

### Translator-Membrane Diagnosis

What the translator membrane is still missing when it receives Ronny's intent:

- stronger refusal to start from visible runtime symptoms
- stronger insistence on authority order before inspection
- stronger detection of when Ronny is implicitly asking for control-plane truth, not runtime explanation
- stronger distinction between:
  - "what is writing"
  - "what is storing"
  - "what is broken"
  - "what capability governs this"

The membrane must not just translate words.
It must force the first investigative move onto the highest-authority surface available.

If Ronny asks about backup drift, the membrane should route to:

- backup capability
- backup binding
- backup writer

before it ever inspects VM placement, disk state, or runtime directories.

If Ronny asks about storage drift, the membrane should route to:

- storage identity
- storage placement
- storage lifecycle

before it starts narrating folder trees.

The membrane is not allowed to become another improvising operator.
Its job is to preserve authority order under pressure.

## Translator Node And Placement

The translator is not just a chat behavior.
It is part of platform architecture.

If the translator depends on one laptop, one terminal posture, one local mount, or one local helper path, then the platform is still fragile.

The correct shape is:

- the translator membrane remains the protocol adapter between Ronny and the spine
- long-lived runtime helpers, adapters, and background duties live on governed nodes
- the workstation remains a client and control surface, not hidden infrastructure

This means node placement matters.

The translator may attach from a workstation.
But the durable execution surfaces it depends on should live on governed nodes with:

- known runtime identity
- known recovery path
- known storage truth
- known backup truth
- known lifecycle closure

In practice, this means the 730XD and similar nodes should absorb durable platform duties that were allowed to drift onto the MacBook.

The translator should not need a second terminal, a parallel human prompt, or laptop-local glue to discover the correct path through the spine.
If it does, node placement and control-plane shape are both still wrong.

## L1, L2, L3 After This Failure

### L1 — Spine Engine

L1 owns generic, estate-critical control-plane truth.

L1 must not name product workflows, encode product policy, or carry product-specific runtime truth.

L1 must own the generic stack that boring infrastructure depends on:

- `storage.identity`
  - canonical answer for pool, dataset, mountpoint, and meaning
- `storage.placement`
  - canonical answer for where boot, runtime data, cold media, backup, and capsules belong
- `storage.lifecycle`
  - canonical lifecycle model for active, migrated, cold-capsule, purge-ready, and deleted
- `backup.identity`
  - one authoritative backup plane with one restore-intent layout
- `backup.coverage`
  - one authoritative answer for what is covered, how, and whether coverage is complete
- `snapshot.policy`
  - one explicit answer for autosnapshot intent, retention, burden, and policy source
- `recovery.path`
  - one explicit answer for SSH, hypervisor control, OOB access, and disaster access
- `maintenance.transaction`
  - one predictable transaction for precheck, blast radius, shutdown ordering, startup ordering, and recovery
- `runtime.surface.classification`
  - one distinction between runtime truth, browse truth, projection residue, and dead surfaces
- `drain.closure`
  - one closure surface for migrations, stale disks, stale backups, stale snapshots, and stale aliases
- `intent.persistence`
  - one canonical deferred-intent path from report to plan to loop, and it must be executable without shell archaeology or direct authority surgery

If the system can still say:

- "some backups are writing to the old place"
- "we need to inspect multiple surfaces to understand one VM"
- "that path is probably dead but we should check"
- "the official planner exists but the operator may need to work around it"

then L1 is not finished.

### L2 — Shared Adapters

L2 owns reusable boundaries shared across workloads.

That includes:

- SSH resolution
- secrets status
- Tailscale status
- Proxmox host and guest control
- iDRAC status
- Samba/share publication
- backup transport and verification
- snapshot visibility

L2 must be discoverable without operator memory.

L2 must also surface the platform's own lifecycle tools clearly enough that an agent does not have to inspect bindings, scripts, SQLite schemas, and projection files just to determine whether the planning path is real.

### L3 — Product Runtime

L3 owns product and workload truth.

That includes:

- Mint
- media
- communications
- finance
- home
- future workloads

L3 depends on L1 and L2.
L1 and L2 must not depend on L3 surviving.

## The Required Intent Lifecycle

This is the boring flow the platform must make real:

1. A report or architecture brief may begin as a report artifact.
2. If it represents deferred work, it becomes a plan through the canonical planning mutation path.
3. If it is approved for execution, it promotes into a loop.
4. Execution produces receipts and evidence.
5. Only the truths that survive execution get promoted into durable authority surfaces.

This lifecycle is important because it prevents two bad outcomes:

- reports dying in outbox folders
- operators bypassing governed persistence because the official path is broken

The platform must make this lifecycle so boring that an agent can do it correctly on the first try.

## What The Next Agent Must Understand

If you are the next agent reading this:

- the explanation layer may look coherent before the execution layer is actually healthy
- do not assume a capability exists just because the contract, map, or lifecycle doc says it should
- test the real mutation path before depending on it
- if the official path is broken, record that as a platform defect instead of silently inventing a second system
- the goal is not to route around the spine
- the goal is to make the spine's own path work

## Non-Negotiable Estate Invariants

### 1. One Backup Plane

There must be one authoritative backup root on md1400:

- `/md1400/backups`

Inside it, restore intent must be obvious:

- `/vm-images`
- `/app-data`
- `/db-dumps`
- `/configs`
- `/exports`

This must not stop at naming.

L1 backup truth must make these things explicit and non-optional:

- every backup writer resolves from one authoritative surface
- every backup class has declared coverage
- every backup lands in the correct restore-intent home by default
- live VM runtime data stays off the md1400 backup plane by default

### 2. One Media Cold Plane

There must be one authoritative cold media root:

- `/md1400/media-cold`

Inside it:

- `/movies`
- `/tv`

Nothing else.

### 3. Dataset, Mountpoint, And Meaning Must Match

These must align:

- dataset name
- mountpoint
- human meaning

If they do not, the platform is lying.

### 4. Hardware Change Is Not Done Until Truth Changes

Any physical change affecting boot, controllers, pool topology, slots, or cabling is incomplete until:

- the machine boots
- the recovery path still works
- the authoritative hardware truth is updated
- the new state is canonical

### 5. Lockout Recovery Must Be Proven

The platform must preserve one real path back in when:

- host is down
- Tailscale is down
- apps are down
- secrets-backed systems are unavailable

At minimum:

- reachable OOB path from outside the shop
- known URL or IP
- known working credentials
- tested virtual console
- tested power control
- one reachable LAN-side jump machine
- one proven disaster drill

### 6. Snapshot Policy Must Be Explicit

For every authoritative dataset, the spine must know:

- should it be snapshotted
- why
- how often
- how much retention
- where policy is managed
- how to inspect live burden

Inherited autosnapshot policy is dangerous by default.

If a parent is under recursive autosnap, child or retired identities can keep retaining blocks long after live files are gone.

### 7. Boring From Birth

No more temporary names hardening into reality:

- `stage`
- `archive`
- `backup-cold`
- `tombstones`

If a surface is temporary, it must drain or be retired.
If it persists, it must be renamed into truth.

The same rule applies to backup writers and backup destinations.

### 8. The Workstation Must Not Carry Platform Runtime Weight

No critical runtime behavior should depend on:

- MacFUSE mounts
- local LaunchAgents
- local bash wrappers
- one workstation staying logged in, mounted, or healthy

The laptop should open a terminal into the system.
It should not be the system.

### 9. Long-Lived Background Duties Must Run On Nodes

If something must survive session loss and remain part of the platform story, it belongs on a governed node.

In this estate, that means the 730XD and similar durable nodes should carry:

- share publication
- automation daemons
- background syncs
- mount mediation
- runtime adapters
- long-lived helper services

### 10. Canonical Read Surfaces Must Be Unmistakable

The spine must make it obvious which surfaces are:

- canonical truth
- shimmed transition
- projection residue
- dead history

If an agent can read the wrong file and still sound plausible, truth is not sharp enough.

## What Boring VM Lifecycle Must Mean

### VM Create

`vm.create` must not be a gamble.

It should inherit from L1:

- predictable storage placement
- predictable backup enrollment
- predictable recovery registration
- predictable maintenance discipline

### VM Retire

`vm.retire` must not become baggage cleanup debt.

It should inherit from L1:

- lifecycle state transition
- backup reevaluation
- snapshot cleanup
- stale disk retirement
- cold-capsule decision
- purge-ready logic

The translator membrane should still surface the few decisions Ronny actually needs to make.
But the transaction itself should be cookie-cutter.

## Minimal Verify Surfaces That Matter

### L1 Verify Must Answer

- is the engine attachable and truthful
- is the identity/storage/backup/recovery model coherent
- are the canonical read surfaces actually canonical
- are maintenance and recovery capabilities discoverable
- does host maintenance declare blast radius before execution
- does every backup writer resolve to the canonical backup plane
- is backup coverage complete enough to be stated as truth
- is live VM storage clearly separated from backup storage

### L2 Verify Must Answer

- can we reach control surfaces
- can we control the hypervisor safely
- can we resolve secrets
- can we reach the recovery plane
- can we see snapshot burden and policy
- can we discover whether workstation-local glue is still in a critical path
- can we inspect backup writer resolution and coverage without archaeology

### L3 Verify Must Answer

- are the product runtimes healthy enough to do real work

Nothing more should be elevated into “critical” unless it affects operator continuity.

## Drift Gates That Actually Matter

Not hundreds.
Only the ones tied directly to operator pain and platform failure.

Examples:

- snapshot debt on a primary pool exceeds threshold
- backup plane identity is fragmented
- dataset name, mountpoint, and meaning diverge
- boot hardware truth differs from authoritative inventory
- no proven remote recovery path exists
- a critical host can be rebooted but not recovered remotely
- a workstation LaunchAgent, MacFUSE mount, or local wrapper is in a critical path
- a projected authority file is no longer regenerable from current truth
- a maintenance workflow requires shell inspection because governed telemetry is missing
- a backup writer still targets a historical path
- backup coverage cannot be stated clearly
- live VM runtime data is mixed into the cold backup plane
- old migration disks survive as `unused` references without explicit justification

## What Agents Must Be Able To Do Without Operator Hand-Holding

Agents must be able to discover and drive:

- maintenance precheck
- guest shutdown ordering
- guest startup ordering
- host reboot path
- pool and dataset inventory
- backup writer resolution
- backup coverage inspection
- snapshot burden inspection
- shell-vs-snapshot debt distinction
- iDRAC reachability
- remote recovery readiness
- runtime truth vs browse truth
- canonical vs historical read surfaces
- VM current placement vs target placement vs stale residue
- whether a storage surface is runtime, backup, capsule, or dead history

If an operator must remember these manually, the spine has not encoded the estate strongly enough.

## Immediate Direction

From this point forward:

- reduce capability surface area to what agents actually need
- normalize storage and backup naming from birth
- make snapshot policy explicit and visible
- treat hardware truth as first-class authority
- require closure on physical changes
- elevate remote recovery into a first-class invariant
- remove workstation-side runtime glue from critical paths
- move long-lived platform behavior onto governed nodes
- govern share publication and browse surfaces as real architecture
- eliminate stale projections that are no longer regenerable
- make receipts and telemetry discoverable from the live capability layer
- force blast-radius declaration before host-level maintenance
- make backup writer resolution and backup coverage part of L1 truth
- keep live VM runtime off the md1400 backup plane by default
- make VM create and VM retire cookie-cutter transactions backed by L1

That is what clean architecture means here.

Not elegance.
Not ceremony.
Not gate count.

Operational truth under stress.
