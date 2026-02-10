---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-HASS-SSOT-AUTOGRADE-20260210
---

# Loop Scope: LOOP-HASS-SSOT-AUTOGRADE-20260210

## Goal
Make Home Assistant SSOT updates receipted and repeatable: pull facts from HA
API, propose a diff, and update the SSOT doc with a proof trail.

## Success Criteria
- A read-only capability can fetch HA facts (bounded) and produce a proposed SSOT patch.
- A separate mutating capability can apply the patch (worktree-only).
- Output is deterministic (same inputs yield same patch ordering).
- Receipts link: capability run → updated SSOT doc(s).

## Phases
- P0: Identify canonical HA SSOT doc scope + required facts
- P1: Implement `ha.ssot.propose` (read-only)
- P2: Implement `ha.ssot.apply` (mutating, governed)
- P3: Closeout + docs

## Evidence (Receipts)
- (link receipts here)

