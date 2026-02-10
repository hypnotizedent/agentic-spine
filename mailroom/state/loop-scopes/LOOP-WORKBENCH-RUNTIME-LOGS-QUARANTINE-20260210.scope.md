---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-WORKBENCH-RUNTIME-LOGS-QUARANTINE-20260210
---

# Loop Scope: LOOP-WORKBENCH-RUNTIME-LOGS-QUARANTINE-20260210

## Source
- Certification report: mailroom/outbox/audit-export/2026-02-10-full-certification.md

## Goal
Decide policy and implement quarantine for versioned workbench runtime logs, so runtime sinks remain governed and non-noisy.

## Success Criteria
- Scope doc is clean (no injected command output).
- Next actions are clear and bounded.
- Closeout uses receipts when changes land.

## Phases
- P0: Triage + decision + inventory
- P1: Implement updates (SSOT/bindings/docs)
- P2: Verify (gates + targeted checks)
- P3: Closeout (receipts + loop closure)

## Next Action
Decide whether runtime/logs should be gitignored or relocated; implement chosen policy and ensure no contract violations.

## Evidence (Receipts)
- mailroom/outbox/audit-export/2026-02-10-full-certification.md
