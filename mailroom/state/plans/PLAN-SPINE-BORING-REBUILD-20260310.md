# PLAN: Spine Boring Rebuild

> **Loop:** LOOP-SPINE-BORING-REBUILD-20260310
> **Status:** active (horizon: now)
> **Owner:** @ronny
> **Created:** 2026-03-10

## Executive Summary

This is a deep qualification and rebuild session for `agentic-spine` as a product.

The objective is not cosmetic cleanup. The objective is to determine, with file-level rigor, what the spine is supposed to be, what it is not supposed to be, what must be pulled out, and how to keep it boring after the extraction.

The key architectural insight driving this plan:
- the spine should be boring control-plane source
- the mailroom should not live inside the spine repo as live runtime
- receipts/evidence should not compete with governance source for attention
- GitHub should become a productized starter surface, not a mirror of Ronny's live internal forge

## Mission Statement

Read every folder and file inside `agentic-spine` and determine whether it is:
- true control-plane source
- live runtime
- evidence/proof
- reusable foundation source
- archive residue
- unresolved and needing operator judgment

The rebuild must preserve healthy growth. The worker is not allowed to stop at the first blocker or perform destructive moves in order to "clean things up."

## Non-Destructive Operating Rules

1. First pass is classification and truth mapping only.
2. Do not move or delete files simply because they look out of place.
3. If a proposed move could break runtime behavior, convert it into an extraction recommendation and continue the audit.
4. If a folder contains mixed artifact types, classify at the file level instead of forcing a premature folder-level move.
5. If a surface is unclear, mark it `needs-operator-decision` and continue downstream work.
6. The worker must continue until the job is done. Blockers become logged decisions, not stop conditions.

## Boringness Definition

A boring spine should feel like:
- entrypoints
- bindings
- capability implementations
- verification surfaces
- canonical human docs
- fixtures/tests

A boring spine should not feel like:
- live queue runtime
- session exhaust
- leases/locks/heartbeats
- logs
- archived output
- historical planning debris
- mirror/publication mechanics

Boring means:
- one writer type per folder
- one artifact class per folder whenever possible
- one obvious path for each concern
- source and generated matter separated physically
- workflow hygiene encoded in lifecycle, not in human reminders

## File Qualification Rubric

Each file must receive:
- `qualification`: `spine-source` | `runtime-only` | `evidence-only` | `foundation-source` | `archive-only` | `needs-operator-decision`
- `reason`: one sentence explaining why
- `risk_if_moved_now`: `low` | `medium` | `high`
- `target_home`: current path if it stays, or proposed non-spine home if it leaves
- `notes`: behavior, dependency, or contract caveats

## Folder Sweep Method

### 1. Root Sweep

Question:
- What is a boring spine root allowed to contain?

Deliverables:
- root inventory
- root keep/remove qualification list
- identification of legacy workflow era overlap (`.worktrees`, `.wt`, branch naming, archived verify surfaces, mirror assumptions)

### 2. `bin/` Sweep

Question:
- Which entrypoints are genuinely canonical, and which are legacy wrappers or leaked implementation details?

Deliverables:
- boring `bin/` shape
- list of thin wrappers vs logic-heavy scripts

### 3. `ops/` Sweep

Question:
- What is the true control-plane engine, and what inside `ops/` is archive/staged/generated baggage?

Deliverables:
- source-only engine map
- capability/binding/library boundary map
- staging/archive debt map

### 4. `surfaces/` Sweep

Question:
- Which verify/policy surfaces are live, and which are archived but still pretending to be current?

Deliverables:
- live vs archive verify map
- surface ownership map
- enforcement gap list

### 5. `docs/` Sweep

Question:
- Which docs are canonical, which are generated, which are runtime-adjacent, and which are historical residue?

Deliverables:
- canonical doc set
- duplicate-truth map
- generated-doc location recommendations

### 6. `fixtures/` Sweep

Question:
- Which fixtures are true synthetic inputs versus captured runtime artifacts?

Deliverables:
- boring fixture taxonomy

### 7. `mailroom/` + `receipts/` Sweep

Question:
- What must leave the spine because it is runtime/evidence rather than control-plane source?

Deliverables:
- mailroom extraction map
- runtime root definition
- evidence root definition
- keep-in-spine exception list, if any

### 8. Productization Sweep

Question:
- What subset of the spine becomes the public GitHub starter surface, and what reusable extracted material belongs in a separate foundation?

Deliverables:
- public starter surface definition
- private operator-only surface definition
- extracted foundation definition

## Wave Order

1. **W0 Baseline Truth Lock**
2. **W1 Parallel Source Tree Qualification**
3. **W2 Runtime and Evidence Extraction Map**
4. **W3 Public Starter and Foundation Boundary**
5. **W4 Non-Regression Guard Design**
6. **W5 Final Synthesis and Coordination Review**

## Required Outputs From The Worker Sweep

- Top-level folder scorecard
- Subfolder scorecards for every hot-path folder
- File-level qualification manifests for the audited surfaces
- Mailroom extraction boundary map
- Evidence/receipts boundary map
- Foundation extraction map
- Public GitHub starter surface definition
- Non-regression guard proposal so the spine stays boring
- Open operator-decision register for unresolved edge cases

## Blocker Policy

The worker must not stop at:
- ambiguous file ownership
- partial contract drift
- old workflow overlap
- mixed folder contents
- unclear public/private boundary

Instead:
- classify what is known
- mark the uncertain item explicitly
- continue auditing adjacent files and folders

The only reason to stop is destructive risk to current behavior that cannot be analyzed safely without operator approval.

## Final Done

Done means:
- 100 percent clarity on what the spine is and does
- 100 percent clarity on what must leave the spine
- a boring definition for every major folder in the spine
- a defined foundation home for extracted reusable surfaces
- a defined public productized starter surface for GitHub
- a non-regression model so this does not become governance sprawl again

This plan exists to support a granular rebuild session, not a cosmetic cleanup pass.
