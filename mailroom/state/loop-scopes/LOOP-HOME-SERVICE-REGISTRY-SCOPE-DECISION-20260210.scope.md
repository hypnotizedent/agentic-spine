---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-HOME-SERVICE-REGISTRY-SCOPE-DECISION-20260210
---

# Loop Scope: LOOP-HOME-SERVICE-REGISTRY-SCOPE-DECISION-20260210

## Source
- Certification report: mailroom/outbox/audit-export/2026-02-10-full-certification.md

## Goal
Decide and enforce whether home services belong in SERVICE_REGISTRY.yaml, then bring parity with bindings and health checks.

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
Define SERVICE_REGISTRY scope rules for home; if in-scope, add missing home services with host/site normalization and verify related bindings.

## Evidence (Receipts)
- mailroom/outbox/audit-export/2026-02-10-full-certification.md
