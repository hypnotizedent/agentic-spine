---
loop_id: LOOP-MAIL-ARCHIVER-OVERLAP-CLEANUP-20260226
created: 2026-02-26
status: planned
owner: "@ronny"
scope: communications
priority: medium
horizon: later
execution_readiness: blocked
next_review: "2026-03-15"
objective: Execute governed mail-archiver overlap cleanup only after all provider imports are complete and stable.
---

# Loop Scope: LOOP-MAIL-ARCHIVER-OVERLAP-CLEANUP-20260226

## Problem Statement

Mail-archiver has intentional cross-account alias overlap across Gmail/iCloud/Microsoft/Stalwart. Cleanup must not run while provider imports are still active, or duplicates and counts can shift mid-lane.

## Gaps Linked

- GAP-OP-1002: Alias-overlap cleanup and dedupe policy execution.

## Preconditions

- GAP-OP-973 is fixed (Microsoft deep archive import complete).
- Provider account counts are stable across two polling windows.
- No active import jobs for account IDs 1, 2, 3, 4.

## Deliverables

- Canonical overlap classification report (safe-to-dedupe vs preserve).
- Replay-safe dedupe plan with rollback criteria.
- Governed execution receipts for any cleanup mutation.

## Execution Steps

| Step | Action | Status |
|------|--------|--------|
| Step 1 | Confirm import completion and account-count stability | TODO |
| Step 2 | Produce deterministic overlap classification from Message-ID + headers | READY (tooling staged) |
| Step 3 | Draft/approve dedupe policy by provider/account boundary | READY (policy/playbook staged) |
| Step 4 | Execute cleanup with governed receipts and post-clean verification | TODO |

## Pre-Staged Assets (2026-02-27)

- Governed read-only classifier capability:
  - `communications.mailarchiver.overlap.plan`
  - script: `ops/plugins/communications/bin/communications-mail-archiver-overlap-plan`
- Governed remote import capability (for VM214-resident EWS exports):
  - `communications.mailarchiver.import.eml.remote`
  - script: `ops/plugins/communications/bin/communications-mail-archiver-import-eml-remote`
- Canonical alias/timeline boundary contract:
  - `ops/bindings/mail.archiver.alias.boundary.contract.yaml`
- Cleanup execution playbook:
  - `docs/governance/domains/communications/MAIL_ARCHIVER_OVERLAP_CLEANUP_PLAYBOOK.md`

These assets allow dry-run overlap classification and policy-ready decisioning now, while deferring any mutation until preconditions are met.

## Pre-Stage Dry-Run Evidence (2026-02-27)

- Run key: `CAP-20260226-215422__communications.mailarchiver.overlap.plan__Rpzgm46350`
- Snapshot:
  - `table_rows`: 234,540
  - `strict_dedupe_candidate_rows` (same account + same ContentHash): 1,390
  - `manual_review_groups` (same MessageId, differing hashes): 1 group / 4 rows
  - `cross_account_overlap_groups`: 2
  - `alias_multi_account_year_hotspots`: 5

This evidence is classification-only. No mail rows were mutated.

## Pre-Import Overlap Baseline (captured 2026-02-26 20:50 EST)

### Account Inventory
| DB ID | Email | Provider | Count |
|-------|-------|----------|-------|
| 1 | hypnotizedent@gmail.com | Gmail (takeout) | 223,631 |
| 2 | ops@spine.ronny.works | Stalwart (IMAP) | 2 |
| 3 | ronny@mintprints.com | Microsoft (Import) | 9,087 |
| 4 | ronny@hantash.com | iCloud (IMAP) | 1,820 |
| **Total** | | | **234,540** |

### Overlap Analysis
- Cross-account duplicates (same MessageId, different accounts): **2 messages**
  - 1 message shared between accounts 1 (Gmail) and 3 (Microsoft)
  - 1 message shared between accounts 3 (Microsoft) and 4 (iCloud)
- Within-account duplicates (same MessageId, same account): **1,379 in account 3**
  - Root cause: APFS case-insensitive collision during Graph API export created duplicate .eml files with different filenames but same Message-ID, imported as separate rows
- Null/empty MessageId: **0** across all accounts

### Proposed Dedupe Policy
1. **Cross-account duplicates: PRESERVE ALL** — 2 messages across different accounts represent different delivery contexts (forwarding/aliasing). Keep both copies, each bound to its source account.
2. **Within-account duplicates: SAFE TO DEDUPE** — 1,379 rows in account 3 with identical MessageId. Keep the row with the lowest `Id` (earliest insert), delete the duplicate. This is a data artifact from APFS collision handling, not a genuine duplicate delivery.
3. **Rollback**: Before deletion, export affected row IDs + MessageIds to a manifest. If needed, re-import from source .eml files.
4. **Post-archive-import recheck**: After GAP-OP-973 EWS archive import completes (~59K new messages), re-run overlap analysis. The within-account duplicate count may increase if the EWS export contains messages already imported via Graph API.

## Constraints

- Do not run dedupe while import loops are active.
- Preserve legal/compliance archive integrity.
- Keep iCloud (ronny lane) and Stalwart (agent lane) boundaries explicit in reporting.
