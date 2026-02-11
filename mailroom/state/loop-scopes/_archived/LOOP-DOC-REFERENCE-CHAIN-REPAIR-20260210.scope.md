---
status: closed
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-DOC-REFERENCE-CHAIN-REPAIR-20260210
---

# Loop Scope: LOOP-DOC-REFERENCE-CHAIN-REPAIR-20260210

> **Status:** CLOSED

## Source
- Certification report: mailroom/outbox/audit-export/2026-02-10-full-certification.md

## Goal
Repair broken internal doc reference chains so links match existing files and the authority chain stays navigable.

## Resolution

8 broken references found and fixed:

1. **INFRASTRUCTURE_MAP.md** — 4 architecture doc links (MONEY_FLOWS, PRICING_DATA_LAYER, PRICING_UI_INTEGRATION, DATABASE_SCHEMA) pointed to non-existent spine files. These are workbench-scoped mint-os docs. Removed dead links, added note about workbench scope.
2. **AGENT_BOUNDARIES.md** — `./README.md` → `GOVERNANCE_INDEX.md`
3. **SCRIPTS_AUTHORITY.md** — `./README.md` → `GOVERNANCE_INDEX.md`
4. **GOVERNANCE_INDEX.md** — Removed `../DOC_MAP.md` link (file doesn't exist), removed `ARCHIVE_POLICY.md` link and index entry (file doesn't exist).

## Evidence (Receipts)
- docs/governance/INFRASTRUCTURE_MAP.md (4 dead links fixed)
- docs/governance/AGENT_BOUNDARIES.md (1 link fixed)
- docs/governance/SCRIPTS_AUTHORITY.md (1 link fixed)
- docs/governance/GOVERNANCE_INDEX.md (2 dead refs removed)
