---
loop_id: LOOP-MAIL-ARCHIVER-STALWART-CANONICAL-20260226
created: 2026-02-26
status: closed
owner: "@ronny"
scope: communications
priority: high
objective: Register and activate canonical Stalwart archive account in mail-archiver as MailAccountId=2, capture alias overlap baseline receipts, and defer dedupe as a governed follow-up gap.
---

# Loop Scope: LOOP-MAIL-ARCHIVER-STALWART-CANONICAL-20260226

## Problem Statement

Mail-archiver currently has active account IDs 1, 3, and 4, with ID 2 missing. The Stalwart archive lane is contract-declared but runtime mapping is not canonicalized to ID 2. Alias overlap exists across Gmail/iCloud/Microsoft archives and must be baselined for later cleanup.

## Deliverables

- Register loop-linked gaps for:
  - Stalwart runtime canonicalization to account ID 2.
  - Alias overlap cleanup planning/deferred execution.
- Create/activate Stalwart archive account ID 2 and bind it to the app user.
- Record overlap evidence (counts and overlap intersections) in governed docs with receipt linkage.
- Keep current behavior: ingest everything now, dedupe later.

## Execution Steps

| Step | Action | Status |
|------|--------|--------|
| Step 1 | Loop + gap registration | DONE |
| Step 2 | Stalwart account runtime canonicalization (ID 2) | DONE |
| Step 3 | Alias overlap baseline evidence + impact note | DONE |
| Step 4 | Verification + gap closure | DONE |

## Gaps Linked

- GAP-OP-1001: Stalwart runtime canonicalization to MailAccountId=2
- GAP-OP-1002: Re-parented to LOOP-MAIL-ARCHIVER-OVERLAP-CLEANUP-20260226 (deferred)

## Acceptance Criteria

- MailAccountId=2 exists and maps to Stalwart archival account.
- Stalwart account is enabled and sync path validates without credential errors.
- Overlap baseline is documented with query outputs and linked receipts.
- Deferred dedupe cleanup is tracked in an open gap with parent loop linkage.

## Constraints

- Respect boundary separation: iCloud (ronny lane) and Stalwart (agent/comms lane) remain distinct.
- No deletion/dedupe in this loop.
- Do not touch Mint lane files or loops.

## Closure Notes

- Stalwart account canonicalization objective is complete.
- Overlap cleanup objective intentionally separated into dedicated loop:
  `LOOP-MAIL-ARCHIVER-OVERLAP-CLEANUP-20260226`.
