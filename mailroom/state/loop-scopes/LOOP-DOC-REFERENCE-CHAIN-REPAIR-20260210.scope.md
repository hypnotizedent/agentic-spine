---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-DOC-REFERENCE-CHAIN-REPAIR-20260210
---

# Loop Scope: LOOP-DOC-REFERENCE-CHAIN-REPAIR-20260210

## Source
- Certification report: mailroom/outbox/audit-export/2026-02-10-full-certification.md

## Goal
Repair broken internal doc reference chains so links match existing files and the authority chain stays navigable.

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
From the certification report, enumerate broken references; fix links or add missing target docs as appropriate.

## Evidence (Receipts)
- mailroom/outbox/audit-export/2026-02-10-full-certification.md
