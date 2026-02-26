---
loop_id: LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226
created: 2026-02-26
status: active
owner: "@ronny"
scope: communications
priority: medium
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
| Step 1 | Build `microsoft.mail.list.all` capability | NOT STARTED |
| Step 2 | Build `microsoft.mail.export.mime` capability | NOT STARTED |
| Step 3 | Build `mail-archiver.import.eml.upload` orchestration | NOT STARTED |
| Step 4 | Dry-run: export 10 messages, import, verify | NOT STARTED |
| Step 5 | Full export + import + count verification | NOT STARTED |
| Step 6 | Close gaps + loop | NOT STARTED |

## Constraints

- Do not start Step 5 until GAP-OP-922 mbox import is confirmed closed
- Graph API rate limit: 10,000 req/10min — batch 100 at a time
- Disk check: /srv/mail-archiver must be <70% before each batch
- EmlImportService deduplicates by Message-ID (safe for re-runs)

## Success Criteria

- [ ] All ronny@mintprints.com messages archived in mail-archiver
- [ ] Graph message count matches ArchivedEmails count for microsoft-primary account
- [ ] GAP-OP-970, 971, 972 closed with evidence
- [ ] verify.pack.run communications PASS
