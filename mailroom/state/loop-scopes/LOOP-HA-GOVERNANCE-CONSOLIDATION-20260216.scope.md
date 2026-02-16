---
status: closed
owner: "@ronny"
created: 2026-02-16
closed: 2026-02-16
---

# LOOP-HA-GOVERNANCE-CONSOLIDATION-20260216

> **Status:** closed
> **Owner:** @ronny
> **Created:** 2026-02-16

---

## Goal

Reduce HA governance overhead after rapid growth (17 bindings, 36 caps, 12 gates, 9 docs).
Make the HA surface self-documenting, lower noise, and define ongoing maintenance cadence.

## Phases

| Phase | Scope | Gap | Status |
|-------|-------|-----|--------|
| P0 | Loop registration + gap filing | — | **DONE** |
| P1 | HA doc index — single routing table for all HA docs | GAP-OP-522 | **DONE** |
| P2 | Orphan device classification — wired into device map builder | GAP-OP-523 | **DONE** |
| P3 | Merge tiny bindings (scenes/helpers/scripts) into baseline | GAP-OP-524 | **CLOSED** (wontfix — two-tier design intentional) |
| P4 | Define HA maintenance cadence — what to run, when, why | GAP-OP-525 | **DONE** |

---

## Constraints

- Do NOT delete existing docs — only add routing index
- Do NOT change binding schemas without updating consuming gates/caps
- spine.verify must PASS after each phase
- Orphan classification must be backward-compatible (existing scripts don't break)
- Tiny binding merge must update all consuming caps/gates that reference the old files
