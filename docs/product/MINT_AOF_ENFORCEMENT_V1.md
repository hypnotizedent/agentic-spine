---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: mint-aof-enforcement-v1
parent_loop: LOOP-MINT-AOF-BASELINE-V1-20260217
---

# Mint AOF Enforcement v1

## Enforcement Boundary

Enforcement is proposal-preflight only in this wave. No new global drift gates are introduced.

## Enforcement Rules

1. Preflight checks evaluate only files changed by the proposal.
2. Core/domain verification remains required before mutating apply.
3. Mint baseline checks operate as a changed-files ratchet.

## Changed-Files Ratchet Policy

1. Any changed Mint file must conform to baseline contract v1.
2. Unchanged legacy files are not retroactively blocked in this wave.
3. Every new/modified surface must align with canonical templates first.

## Template-First Scaffolding Policy

1. New Mint lanes start from canonical templates.
2. Direct ad-hoc scaffolding is disallowed unless exception is approved.
3. Template updates require explicit compatibility notes.

## Exception Protocol

1. Exception must include reason, scope, owner, and expiry date.
2. Exception must list compensating controls and rollback path.
3. Exception expires automatically at stated date and must be removed or renewed.
4. Expired exceptions are treated as non-compliant in follow-up preflight.
