# LOOP-CODEX-WORKTREE-REMOTE-ANCHOR-20260210

> **Status:** CLOSED
> **Owner:** @ronny
> **Created:** 2026-02-10
> **Severity:** high

## Problem

`spine.verify` D48 is failing because a codex worktree branch exists locally but has no `origin/<branch>` remote-tracking ref (reported as orphaned).

## Scope

- Repair D48 by ensuring the codex worktree branch is either pushed to origin or removed if intentionally local-only.
- Re-run `./bin/ops cap run spine.verify` to prove D48 is PASS.

## Acceptance

- `spine.verify` PASS with D48 PASS.
- Receipt path recorded here.

## Evidence

- Receipt (`spine.verify` PASS, includes D48 PASS): `receipts/sessions/RCAP-20260210-084747__spine.verify__Rf3so75832/receipt.md`
