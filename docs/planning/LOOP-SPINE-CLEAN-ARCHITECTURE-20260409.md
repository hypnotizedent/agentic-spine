# LOOP-SPINE-CLEAN-ARCHITECTURE-20260409

Status: planning brief
Authority posture: main-checkout planning artifact
Repo: `/Users/ronnyworks/code/agentic-spine`

## Why This Exists

The canonical report brief for this work is:

- [`mailroom/outbox/reports/THE_MOST_IMPORTANT_THINGS_THE_SPINE_NEEDS_TO_DRIVE_FOR_CLEAN_ARCHITECTURE.md`](/Users/ronnyworks/code/agentic-spine/mailroom/outbox/reports/THE_MOST_IMPORTANT_THINGS_THE_SPINE_NEEDS_TO_DRIVE_FOR_CLEAN_ARCHITECTURE.md)

That document is the architecture brief.

This file exists for a narrower purpose:

- preserve the first boring execution order
- record the first boring execution order
- keep the next agent out of rediscovery

## Objective

Turn the clean-architecture brief into boring, executable platform work.

This plan is not for more theory.
It is for converting the list into a bounded sequence of real fixes.

## Scope

In scope:

- L1 storage/backup/recovery capability truth
- backup plane normalization
- VM lifecycle boringness
- snapshot policy truth
- intent persistence truth
- attach/setup/loop flow truth
- workstation-vs-node runtime boundary

Out of scope:

- product-specific runtime feature work
- speculative new governance layers
- parallel cleanup outside this lane unless explicitly elected

## First Boring Execution Order

Work this in this order, not in emotional order.

### Step 1. Fix The Spine's Own Lifecycle Path

Goal:

- make the platform able to persist deferred intent and loop work through its own canonical path

Concrete targets:

- `planning-plans-create`
- `planning-plans-promote`
- `loops-create`
- any missing support modules or contracts they actually require

Why first:

- if the spine cannot create plans or loops cleanly, everything else becomes workaround theater

Definition of done:

- an agent can create a plan
- promote a plan or open a loop
- do that without direct SQLite surgery
- do that from the documented CLI path

### Step 2. Fix Backup Writer Truth

Goal:

- one authoritative backup plane on md1400

Concrete targets:

- stop new writes to `backup-cold`
- make `/md1400/backups` the boring, canonical restore-intent root
- identify the authoritative backup-writer surface in L1/L2

Definition of done:

- every active backup writer resolves from one clear source
- no current job writes into retired backup identities

### Step 3. Fix Snapshot Policy Truth

Goal:

- snapshots become explicit platform truth, not hidden inheritance

Concrete targets:

- where snapshot policy is defined
- where retention is defined
- where burden is visible
- which datasets must never inherit old autosnap behavior accidentally

Definition of done:

- an agent can answer snapshot origin, retention, live burden, and disable/retire semantics without shell archaeology

### Step 4. Fix VM Runtime Placement Truth

Goal:

- boring explanation and boring defaults for VM placement

Concrete targets:

- boot surface
- runtime data surface
- special-case exceptions
- stale `unused` disk residue

Definition of done:

- one canonical read surface explains where a VM lives and why
- stale `unused` disks become explicit drift, not tolerated leftovers

### Step 5. Fix VM Retirement / Capsule Closure

Goal:

- retirement becomes cookie-cutter

Concrete targets:

- active -> migrated -> cold-capsule -> purge-ready -> deleted
- backup reevaluation on retirement
- old aliases, snapshots, and stale writers closed as part of retirement

Definition of done:

- retiring a VM no longer depends on operator memory

### Step 6. Fix Recovery Truth

Goal:

- lockout recovery is a real platform feature, not a half-finished setup

Concrete targets:

- iDRAC reachability
- one LAN-side jump path
- one real disaster drill contract

Definition of done:

- the platform can prove how to recover when the hypervisor is down

### Step 7. Fix Workstation Runtime Weight

Goal:

- operator laptop is a client again, not hidden substrate

Concrete targets:

- MacFUSE dependence
- Finder truth dependence
- LaunchAgents carrying durable runtime meaning
- background duties that belong on nodes

Definition of done:

- long-lived duties run on governed nodes
- workstation surfaces are convenience only

## Rules For This Lane

- do not bypass broken spine lifecycle paths silently
- if a canonical path is broken, record that as a platform defect and then fix the path
- do not invent more governance to describe what a missing capability should have done
- prefer boring defaults over explanatory sprawl

## Hand-Off Note

If you are the next agent:

- start with the report brief
- then use this file as the execution order
- the first thing to prove is not storage cleanup
- the first thing to prove is that the spine can create and carry its own governed work without operator improvisation
