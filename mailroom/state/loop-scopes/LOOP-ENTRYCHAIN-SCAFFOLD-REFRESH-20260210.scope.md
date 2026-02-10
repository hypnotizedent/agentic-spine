---
status: closed
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-ENTRYCHAIN-SCAFFOLD-REFRESH-20260210
---

# Loop Scope: LOOP-ENTRYCHAIN-SCAFFOLD-REFRESH-20260210

> **Status:** CLOSED

## Source
- Certification report: mailroom/outbox/audit-export/2026-02-10-full-certification.md

## Goal
Refresh SPINE_SCAFFOLD.md and the entry chain docs to match current canonical paths, gates, and capabilities.

## Resolution

Updated SPINE_SCAFFOLD.md with all current values:
- Paths: `$HOME/Code/` → `$HOME/code/` (D42 enforced)
- Tag: v0.1.23 → v0.1.24-spine-canon
- Gates: D1-D25 (25) → D1-D57 (50 active), full list updated
- Capabilities: 36 → 145
- Bindings: 7 → 28
- SSOT registry: 58 → 32
- All stale section counts corrected

SPINE_SESSION_HEADER.md was already refreshed in LOOP-SESSION-HEADER-GATES-REFRESH.

## Evidence (Receipts)
- SPINE_SCAFFOLD.md (updated)
- SPINE_SESSION_HEADER.md (updated in prior loop)
