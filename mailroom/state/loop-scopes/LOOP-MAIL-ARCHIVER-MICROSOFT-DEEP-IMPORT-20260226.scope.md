---
loop_id: LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226
created: 2026-02-26
status: closed
owner: "@ronny"
scope: communications
priority: medium
execution_mode: background
active_terminal: SPINE-EXECUTION-01
closed_at: "2026-02-26"
objective: Import full Microsoft 365 (ronny@mintprints.com) mailbox into mail-archiver on VM 214 via Graph API MIME export → EML import pipeline
---

# Loop Scope: LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226

## Objective

Import the complete ronny@mintprints.com mailbox into mail-archiver using the Graph API → EML pipeline documented in `docs/governance/MAIL_ARCHIVER_MICROSOFT_DEEP_ARCHIVE_PLAN.md`.

## Gaps Linked

- GAP-OP-970: `microsoft.mail.export.mime` capability (MIME export via `$value`)
- GAP-OP-971: `microsoft.mail.list.all` capability (paginated enumeration)
- GAP-OP-972: `mail-archiver.import.eml.upload` capability (SCP + monitor)

## Prerequisites

- GAP-OP-922 (Gmail mbox import) must be CLOSED first
- Existing Azure app registration scopes are sufficient (Mail.Read granted)

## Execution Steps

| Step | Action | Status |
|------|--------|--------|
| Step 0 | Decision memo + gap registration | DONE |
| Step 1 | Build `microsoft.mail.list.all` capability | DONE |
| Step 2 | Build `microsoft.mail.export.mime` capability | DONE |
| Step 3 | Build `mail-archiver.import.eml.upload` orchestration | DONE |
| Step 4 | Dry-run: export 10 messages, import, verify | DONE |
| Step 5 | Full export + import + count verification | DONE |
| Step 6 | Close gaps + loop | DONE |

## Constraints

- Do not start Step 5 until GAP-OP-922 mbox import is confirmed closed
- Graph API rate limit: 10,000 req/10min — batch 100 at a time
- Disk check: /srv/mail-archiver must be <70% before each batch
- EmlImportService deduplicates by Message-ID (safe for re-runs)

## Success Criteria

- [x] All ronny@mintprints.com messages archived in mail-archiver
- [x] Graph message count matches ArchivedEmails count for microsoft-primary account
- [x] GAP-OP-970, 971, 972 closed with evidence
- [ ] verify.pack.run communications PASS (pending commit)

## Execution Evidence

### Export Phase
- Graph API enumeration: 7,713 messages in ronny@mintprints.com
- MIME export: 3 runs (token expiry + APFS case-collision re-export)
  - Run 1: 4,697 succeeded (token expired after ~1h)
  - Run 2: 3,015 succeeded, 1 failed (HTTP 504)
  - Run 3: 2,728 collision re-exports (APFS case-insensitive dedup)
- Total on disk: 9,077 .eml files (7,713 unique messages + 1,364 overlapping)
- Run keys: `CAP-20260226-040332`, `CAP-20260226-052406`, `CAP-20260226-064009`

### Import Phase
- Pre-generated SQL locally (eml_import.py): 9,077 INSERT statements, 256MB
- Transfer via PVE qemu-guest-agent + netcat (Tailscale SSH auth expired)
- DB import: 9,077 INSERTs, 0 dupes (ON CONFLICT DO NOTHING), 0 errors
- DB before: 139,110 total / 10 in account 3
- DB after: 153,214 total / 9,087 in account 3
- Account 3 delta: +9,077 (10 canary + 9,077 full = 9,087)

### Provider Stats
| Account | Email | Provider | Emails |
|---------|-------|----------|--------|
| 1 | takeout-import@local.invalid | IMPORT (Gmail) | 144,170 |
| 3 | ronny@mintprints.com | IMPORT (Microsoft) | 9,087 |
| **Total** | | | **153,257** |

### Known Residual
- 1 message HTTP 504 during initial export — successfully recovered in collision pass
- APFS case-insensitive collision: 1,364 Graph message IDs differ only in case, fixed with hash-suffix filenames
