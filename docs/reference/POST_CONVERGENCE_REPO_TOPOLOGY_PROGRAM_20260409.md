---
status: authoritative
owner: "@operator"
last_verified: 2026-04-09
scope: post-convergence-repo-topology
---

# Post-Convergence Repo Topology Program

This program starts after the spine convergence program was declared complete on 2026-04-09.

It is not an extraction program.
It is a repo-topology simplification program.

## Objective

Reduce overlapping repo authority so the steady-state workspace becomes easier to operate.

Target steady state:

- `$SPINE_ROOT`
  - kernel
  - governance
  - shared rails
  - verify/gates
  - compatibility shims/seams
- `$WORKBENCH_ROOT`
  - domain operational truth
  - operator tooling
  - infra compose/config/reference surfaces
- `$HOME/code/mint-modules`
  - Mint product truth
- `$HOME/code/ronny-products`
  - incubator / parked / experimental products

## In Scope

1. Consolidate communications authority into `workbench/agents/communications`
2. Consolidate media authority into `workbench/agents/media`
3. Decide whether `agentic-foundation` is:
   - merged into `workbench`, or
   - narrowed to a non-overlapping infra-primitives repo
4. Archive or tombstone any staging repos that are no longer load-bearing

## Out Of Scope

- reopening the spine extraction program
- changing the spine definition of done
- rewriting routing/capability/gate topology for aesthetics alone
- deleting load-bearing repos before their callers are redirected

## Current Truth

As of 2026-04-09:

- `communications-domain` is still load-bearing for spine comms shims
- `media-domain` is still load-bearing for spine media shims
- `agentic-foundation` and `workbench` have overlapping charters around infra/domain implementation source
- the spine program is already done; these questions do not block normal spine use

## Program Phases

### Phase 1 — Communications Consolidation

- move canonical comms scripts/contracts from `communications-domain` into `workbench/agents/communications`
- repoint spine comms shims/seams to workbench
- leave blocked runtime rails in spine if still intentional
- only after all callers are truthful may `communications-domain` be archived

### Phase 2 — Media Consolidation

- move canonical media scripts/contracts from `media-domain` into `workbench/agents/media`
- repoint spine media shims/seams to workbench
- leave shared media rails in spine
- only after all callers are truthful may `media-domain` be archived

### Phase 3 — Foundation Boundary Decision

- classify everything in `agentic-foundation` as one of:
  - merge_to_workbench
  - keep_as_foundation
  - archive
- if `agentic-foundation` remains, its charter must no longer overlap `workbench`

### Phase 4 — Retire Staging Repos

- archive/tombstone any repo that is no longer canonical and no longer load-bearing
- do not delete by assumption; prove no live callers remain first

## Success Criteria

This program is done when all of the following are true:

- spine comms shims no longer depend on `communications-domain`
- spine media shims no longer depend on `media-domain`
- `workbench` is the canonical home for communications/media domain operations
- `agentic-foundation` is either merged, archived, or narrowed to a non-overlapping role
- no retired staging repo remains load-bearing by accident

## Stop Rule

Stop this program once repo authority is boring again.

Do not keep going for elegance.
Do not reopen spine extraction.
Do not do repo surgery that does not reduce actual authority overlap.

## First Recommended Wave

Start with communications consolidation into workbench.

Reason:

- communications already has an established workbench agent home
- the standalone repo is small
- the spine shims are already path-detached
- the remaining work is mostly canonicalization and repointing, not architectural discovery
