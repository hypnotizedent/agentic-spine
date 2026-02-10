---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-BRAIN-CONTEXT-DEPRECATION-FIX-20260210
---

# Loop Scope: LOOP-BRAIN-CONTEXT-DEPRECATION-FIX-20260210

## Source
- Certification report: mailroom/outbox/audit-export/2026-02-10-full-certification.md

## Goal
Remove deprecated guidance from the brain layer and ensure the context rules align with the current workflow (repo search first, SSOT first).

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
Scan docs/brain/context.md for deprecated commands and align with docs/governance/SESSION_PROTOCOL.md; record exact changes needed.

## Evidence (Receipts)
- mailroom/outbox/audit-export/2026-02-10-full-certification.md
