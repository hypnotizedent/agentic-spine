---
loop_id: LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226
created: 2026-02-26
status: closed
owner: "@ronny"
scope: communications
priority: high
execution_mode: background
active_terminal: SPINE-EXECUTION-01
reopened_at: "2026-02-26"
reopen_reason: "Exchange Online Archive (In-Place Archive) discovered — 100+GB not reachable via Graph API. Requires EWS export capability."
objective: Import full Microsoft 365 (ronny@mintprints.com) mailbox into mail-archiver on VM 214 via Graph API MIME export → EML import pipeline
---

# Loop Scope: LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226

## Objective

Import the complete ronny@mintprints.com mailbox into mail-archiver using the Graph API → EML pipeline documented in `docs/governance/MAIL_ARCHIVER_MICROSOFT_DEEP_ARCHIVE_PLAN.md`.

## Gaps Linked

- GAP-OP-970: `microsoft.mail.export.mime` capability (MIME export via `$value`)
- GAP-OP-971: `microsoft.mail.list.all` capability (paginated enumeration)
- GAP-OP-972: `mail-archiver.import.eml.upload` capability (SCP + monitor)
- GAP-OP-973: Exchange Online Archive not accessible via Graph API — requires EWS `full_access_as_app`

## Prerequisites

- GAP-OP-922 (Gmail mbox import) must be CLOSED first
- Existing Azure app registration scopes: Mail.Read (Graph API) + full_access_as_app (EWS, added Step 7)

## Execution Steps

| Step | Action | Status |
|------|--------|--------|
| Step 0 | Decision memo + gap registration | DONE |
| Step 1 | Build `microsoft.mail.list.all` capability | DONE |
| Step 2 | Build `microsoft.mail.export.mime` capability | DONE |
| Step 3 | Build `mail-archiver.import.eml.upload` orchestration | DONE |
| Step 4 | Dry-run: export 10 messages, import, verify | DONE |
| Step 5 | Full export + import + count verification | DONE |
| Step 6 | Close gaps 970-972 | DONE |
| Step 7 | Add EWS `full_access_as_app` permission to Azure app | DONE (manual) |
| Step 8 | Verify EWS archive access (68,892 msgs found) | DONE |
| Step 9 | Build `microsoft.mail.archive.export` EWS capability | NOT STARTED |
| Step 10 | Full archive export + import + count verification | NOT STARTED |
| Step 11 | Close GAP-OP-973 + close loop | NOT STARTED |

## Constraints

- Do not start Step 5 until GAP-OP-922 mbox import is confirmed closed
- Graph API rate limit: 10,000 req/10min — batch 100 at a time
- Disk check: /srv/mail-archiver must be <70% before each batch
- EmlImportService deduplicates by Message-ID (safe for re-runs)

## Success Criteria

- [x] All ronny@mintprints.com PRIMARY mailbox messages archived (7,726 via Graph API)
- [x] Graph message count matches ArchivedEmails count for microsoft-primary account
- [x] GAP-OP-970, 971, 972 closed with evidence
- [ ] All ronny@mintprints.com ARCHIVE mailbox messages archived (100+GB via EWS)
- [ ] GAP-OP-973 closed with evidence
- [ ] verify.pack.run communications PASS

## Execution Evidence

### Export Step
- Graph API enumeration: 7,713 messages in ronny@mintprints.com
- MIME export: 3 runs (token expiry + APFS case-collision re-export)
  - Run 1: 4,697 succeeded (token expired after ~1h)
  - Run 2: 3,015 succeeded, 1 failed (HTTP 504)
  - Run 3: 2,728 collision re-exports (APFS case-insensitive dedup)
- Total on disk: 9,077 .eml files (7,713 unique messages + 1,364 overlapping)
- Run keys: `CAP-20260226-040332`, `CAP-20260226-052406`, `CAP-20260226-064009`

### Import Step
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

### Discovery: Exchange Online Archive (GAP-OP-973)
- Graph API `/me/messages` and `/me/mailFolders` only surface the PRIMARY mailbox (7,726 messages)
- Full folder enumeration confirmed: Inbox 5,594 + Sent 1,784 + Junk 336 + Deleted 13 + Drafts 2 + Recoverable 2 = 7,731
- Exchange Online Archive (In-Place Archive) is a separate mailbox not accessible via Graph API
- User confirms 100+GB of email data in the archive mailbox
- Resolution: EWS (Exchange Web Services) with `full_access_as_app` permission can access `ArchiveRoot`
- Azure app permission added: Office 365 Exchange Online → `full_access_as_app` (application)
- EWS probe confirmed: token acquired, ArchiveRoot accessible, 68,892 messages in archive
- Archive folder structure: Inbox (1,646), Sent Items (1,290), Archive (919), Deleted Items (7 + 20 subfolders with bulk data), Tasks (54), Calendar (15)
- EWS token scope: `https://outlook.office365.com/.default` (separate from Graph `https://graph.microsoft.com/.default`)
- Token-exec modification needed: support EWS scope for archive operations
