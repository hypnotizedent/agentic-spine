---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-28
scope: git-workflow-discipline
version: 1.0
machine_enforcement: not_yet_machine_enforced
source_triangulation:
  - docs/governance/SPINE.md
  - docs/governance/LOCAL_CONTROL_PLANE_CONTRACT.md
  - docs/governance/AUTONOMOUS_MULTI_NODE_VISION.md
  - ops/bindings/governed.change.lifecycle.contract.yaml
  - ops/bindings/spine.self-governance.lifecycle.contract.yaml
  - .runtime/spine/state/domain-state/spine/execution-packets-20260326/SPINE_CLOSURE_CAMPAIGN_INDEX_20260326.md
---

# Git Workflow Discipline

This document establishes the current governed operating policy for push
discipline, branch and PR posture, and the missing attestation-to-remote sync
link.

It exists because the March 2026 campaign proved that commit discipline and
verification discipline improved faster than remote-sync discipline. High
quality work still accumulated locally until a human remembered to push it.

That is a workflow hole, not a personal reminder problem.

## Relationship To Other Authorities

- [`SPINE.md`](SPINE.md) is the minimal operating contract for daily use.
- [`LOCAL_CONTROL_PLANE_CONTRACT.md`](LOCAL_CONTROL_PLANE_CONTRACT.md) defines
  root-main, worktree, and workstation posture.
- [`AUTONOMOUS_MULTI_NODE_VISION.md`](AUTONOMOUS_MULTI_NODE_VISION.md) defines
  the future state where the operator is not the message bus.
- [`governed.change.lifecycle.contract.yaml`](../../ops/bindings/governed.change.lifecycle.contract.yaml)
  defines change-process route rules.
- [`spine.self-governance.lifecycle.contract.yaml`](../../ops/bindings/spine.self-governance.lifecycle.contract.yaml)
  defines the `change_class` selector used by the companion contract.

This document answers a narrower question:

> When must work leave the laptop and become remote truth?

## The Hole Being Closed

Before this document, repo truth governed:
- attach
- scope
- staged landing discipline
- verification
- loop closure

But it did not govern:
- when a landed local commit must be pushed
- when a review branch or PR is preferred over direct push to `main`
- how push state should appear in attestation or receipts

That meant remote sync depended on memory, translator reminders, or end-of-day
luck.

## Immediate Operating Policy

These rules are effective now, even before machine enforcement exists.

### Rule 1: Push After Landed Implementation Passes

If a repo-owned implementation pass lands cleanly and targeted verification is
green, push it before starting the next implementation pass.

The only allowed reasons to delay push are:
- the repo is intentionally held for operator review before publication
- the landing is incomplete because parent artifacts or receipts are still open
- the remote is unavailable or the push fails

If push is delayed, the blocker must be stated explicitly in the closeout
surface or session summary. Silent accumulation is not acceptable.

### Rule 2: Push Before New Meaning Chains Continue

Before starting implementation for a `new_truth` concern, the active repo should
be remotely synced or the divergence should be explicit and intentional.

The point is not ceremony. The point is to prevent new governed meaning from
stacking on top of unpublished local-only truth.

### Rule 3: Session Close Requires Push Or Blocker

If a session ends with a clean checkout that is ahead of `origin/main`, either:
- push the work, or
- record the exact blocker that prevented push

"Forgot to push" is not a valid blocker.

### Rule 4: Maximum Local Accumulation

Do not accumulate more than:
- `10` local commits, or
- `1` active working session

without either pushing or explicitly recording why push is being delayed.

This threshold is intentionally conservative. It can be revised later, but the
default must bias toward remote continuity, not local pileup.

## Branch And PR Posture

Push discipline and PR discipline are related but not identical.

### Direct Push To `main`

Direct push to `main` is allowed only when all of the following are true:
- the work is a bounded governed landing
- root-main mutation complied with existing main-guard rules
- the scope is small enough to review as one exact slice
- verification and receipts are complete
- the operator has intentionally chosen direct landing rather than a review lane

This posture is normal for:
- single-operator `ordinary_fix`
- bounded `emergency_repair`
- exact controller-owned landings

### Managed Worktree / Branch Preferred

Managed worktree plus branch is preferred when any of the following are true:
- the work is broad or concurrent
- the write scope is not one exact slice
- multiple terminals or workers are involved
- the repo is not in a clean controller landing window
- operator review should happen before merge

### `new_truth` Posture

`new_truth` should prefer a reviewable branch/worktree flow with explicit
operator review before merge to `main`.

Direct main landing for `new_truth` is not forbidden, but it must remain the
exception:
- bounded
- explicitly elected
- reviewable as one exact slice
- justified in the receipt trail

The goal is not to force PR theater onto every change. The goal is to keep
meaning-bearing changes from disappearing into silent direct-push habits.

## Attestation And Receipt Gap

Current attestation and status artifacts often capture:
- commit SHA
- verification outcome
- next action

They do not yet reliably capture remote-sync state.

That gap remains real.

Future attestation surfaces should include at minimum:
- `pushed_to_remote`
- `remote_branch`
- `push_sha`
- `push_status`
- `push_timestamp_utc`

Until that schema exists, human summaries and status artifacts must state
whether the repo is:
- behind
- ahead
- or synced

## Historical Pattern Being Corrected

The repo already showed two opposite bad patterns:

- earlier high-velocity periods where commits and pushes happened constantly,
  often without enough governed review
- the March 2026 governance campaign, where commit quality improved sharply but
  push discipline collapsed and local-only truth accumulated

The target posture is neither extreme.

The desired pattern is:
- bounded governed commits
- targeted verification
- prompt remote sync
- explicit review posture when a PR or branch lane is warranted

## What This Does Not Yet Do

This document does not yet provide:
- a machine-readable `git.workflow.contract.yaml`
- automatic attestation fields for push state
- automatic PR routing by `change_class`
- push enforcement gates

Those remain follow-on implementation work.

## Governing Classification

This concern is `new_truth`.

This document makes the workflow requirement explicit now:
- remote sync is part of governed closure
- push timing is not a memory trick
- PR posture depends on scope and change class

The machine-readable contract, attestation integration, and enforcement gates
should follow as a later implementation concern.
