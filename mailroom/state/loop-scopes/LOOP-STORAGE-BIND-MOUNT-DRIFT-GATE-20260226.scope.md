---
loop_id: LOOP-STORAGE-BIND-MOUNT-DRIFT-GATE-20260226
created: 2026-02-26
status: active
owner: "@ronny"
scope: storage
priority: high
objective: Enforce governed non-boot bind-mount policy for high-write service paths and prevent boot-disk exhaustion regressions across VM stacks.
---

# Loop Scope: LOOP-STORAGE-BIND-MOUNT-DRIFT-GATE-20260226

## Objective

Enforce governed non-boot bind-mount policy for high-write service paths and prevent boot-disk exhaustion regressions across VM stacks.

## Phases
- P0: register-governance-gap
- P1: implement-drift-gate
- P2: fix-mail-archiver-storage-paths
- P3: verify-import-completion

## Success Criteria
- New storage governance gap filed and linked
- Drift gate exists and is wired into verify surfaces
- Mail-archiver uploads persist to /srv/mail-archiver non-boot disk
- Full Google backup import complete and verified

## Definition Of Done
- No high-write mail-archiver path writes to boot overlay
- Gate fails deterministically on missing/incorrect bind mount
- Receipts recorded for gap, runtime fix, and import completion
