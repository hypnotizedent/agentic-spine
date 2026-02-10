---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-WORKBENCH-PATH-CANON-ALIGN-20260210
---

# Loop Scope: LOOP-WORKBENCH-PATH-CANON-ALIGN-20260210

## Source
- Certification report: mailroom/outbox/audit-export/2026-02-10-full-certification.md

## Goal
Align workbench docs to spine canonical paths (use ~/code/..., avoid ~/Code/... and legacy paths).

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
Inventory workbench non-legacy docs with uppercase path claims; patch to match spine contract and re-verify gates.

## Evidence (Receipts)
- mailroom/outbox/audit-export/2026-02-10-full-certification.md
-
## Work Completed

- Workbench branch: `codex/LOOP-WORKBENCH-PATH-CANON-ALIGN-20260210`
- Workbench commit: `5bfdab5` (updates `WORKBENCH_CONTRACT.md`, `docs/infrastructure/MCP_AUTHORITY.md`)

## Verification

- `spine.verify` PASS receipt: `receipts/sessions/RCAP-20260210-085629__spine.verify__Rg29z9299/receipt.md`
