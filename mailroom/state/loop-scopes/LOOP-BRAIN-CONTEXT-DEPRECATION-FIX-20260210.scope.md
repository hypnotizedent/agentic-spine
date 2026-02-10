---
status: closed
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-BRAIN-CONTEXT-DEPRECATION-FIX-20260210
---

# Loop Scope: LOOP-BRAIN-CONTEXT-DEPRECATION-FIX-20260210

> **Status:** CLOSED

## Source
- Certification report: mailroom/outbox/audit-export/2026-02-10-full-certification.md

## Goal
Remove deprecated guidance from the brain layer and ensure the context rules align with the current workflow (repo search first, SSOT first).

## Resolution

**P0 (Triage):** Rule 2 in `docs/brain/rules.md` already says "SSOT FIRST" (not "RAG FIRST" / "mint ask"). The `_imported/claude-commands/ask.md` and `incidents.md` files carry proper deprecation notices. No deprecated guidance remains in the active brain layer.

**P1 (Verify):** `generate-context.sh` regenerated `docs/brain/context.md` — output confirmed clean (Rule 2 = "SSOT FIRST", no mint ask references in active guidance).

**P2 (Gates):** `spine.verify` 50/50 PASS.

**P3 (Close):** Loop closed 2026-02-10.

## Evidence (Receipts)
- mailroom/outbox/audit-export/2026-02-10-full-certification.md
- docs/brain/rules.md (Rule 2 = SSOT FIRST)
- docs/brain/context.md (regenerated, clean)
