# Mail-Archiver Microsoft Deep Archive Plan

> Status: authoritative
> Last verified: 2026-02-26
> Owner: @ronny

## Objective

Import the full Microsoft 365 (ronny@mintprints.com) mailbox into mail-archiver on VM 214 as a deep archive. This covers all historical email, not just recent messages.

## Recommended Ingestion Path: Graph API → EML → mail-archiver

**Single clear choice: Graph MIME export pipeline.**

### Why Graph → EML (not OAuth IMAP)

| Factor | Graph MIME export | OAuth IMAP |
|--------|-------------------|------------|
| Auth model | Client credentials (app-only, already working) | Requires delegated OAuth2 ROPC or interactive flow |
| Scope requirement | `Mail.Read` (already granted) | IMAP.AccessAsUser.All (needs new consent) |
| Export format | Native MIME via `GET /messages/{id}/$value` → .eml | IMAP FETCH → .eml (same result, harder auth) |
| Pagination | `$top` + `$skip` or `@odata.nextLink` delta tokens | IMAP UIDs (less ergonomic for bulk) |
| Rate limits | 10,000 req/10min per app (well documented) | IMAP throttling (undocumented, aggressive) |
| Existing capability | `microsoft.mail.search` + `microsoft.mail.get` proven | No IMAP capability exists |
| Import target | mail-archiver EML import service (watches `/app/uploads/eml`) | Same (would still need EML conversion) |

**Verdict**: Graph MIME export reuses the existing proven auth flow, needs only one new capability (`microsoft.mail.export.mime`), and feeds directly into mail-archiver's EML import background service.

## Architecture

```
Microsoft Graph API                    VM 214 (communications-stack)
  GET /messages?$top=100               ┌─────────────────────────┐
  GET /messages/{id}/$value (.eml)     │  /srv/mail-archiver/    │
       │                               │    uploads/eml/         │
       │  (SCP/SSH batch copy)         │      *.eml files        │
       ▼                               │         │               │
  Local staging dir                    │  EmlImportService       │
  /tmp/microsoft-export/               │  (background watcher)   │
       │                               │         │               │
       └───── scp batch ──────────────→│  mail-archiver-db       │
                                       │  (ArchivedEmails table) │
                                       └─────────────────────────┘
```

### Pipeline Steps

1. **Enumerate**: `GET /users/{upn}/messages?$top=100&$select=id,receivedDateTime&$orderby=receivedDateTime` with `@odata.nextLink` pagination
2. **Export**: For each message ID, `GET /users/{upn}/messages/{id}/$value` (returns RFC 5322 MIME) → save as `{id}.eml`
3. **Transfer**: `scp` batch of .eml files to `communications-stack:/srv/mail-archiver/uploads/eml/`
4. **Import**: EmlImportService auto-detects new files and ingests (dedup by Message-ID header)
5. **Verify**: Compare Graph message count vs ArchivedEmails count for the microsoft-primary account

## Azure App Registration / Scopes

### Current State (mintprints.com M365 tenant)
- App registration: exists (client_credentials grant working)
- Secrets: `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` in Infisical
- Scopes granted: `Mail.Read`, `Mail.ReadWrite`, `Mail.Send`, `Calendars.ReadWrite`, `User.Read.All`

### Required for Deep Archive
- **Mail.Read** — already granted, sufficient for both `$value` MIME export and message listing
- **No new Azure scopes needed** — the existing app registration has everything required

## MCP Role

### Existing Tools (sufficient for orchestration)
- `microsoft.mail.search` — can list/search messages (proven working)
- `microsoft.mail.get` — can get message metadata by ID (proven working)

### Missing Capabilities (new)
- `microsoft.mail.export.mime` — `GET /messages/{id}/$value` with `Accept: application/mime` → save .eml file
- `microsoft.mail.list.all` — paginated full-mailbox enumeration via `@odata.nextLink` (not search, all messages)
- `mail-archiver.import.eml.upload` — SCP .eml batch to VM 214 uploads/eml dir + monitor EmlImportService

## Security Boundaries

- **Read-only ingest**: Graph calls are GET only (no POST/PATCH/DELETE)
- **No send**: Export pipeline does not use Mail.Send scope
- **No delete**: BLOCKED_ACTIONS in microsoft_tools.py enforces this
- **Network boundary**: Graph API calls from macbook → internet; SCP from macbook → Tailscale → VM 214
- **Dedup safety**: mail-archiver EmlImportService deduplicates by Message-ID header
- **Secrets**: Existing Infisical paths, no new secrets needed

## Throughput / Rate-Limit Strategy

### Graph API Limits
- **Application**: 10,000 requests per 10 minutes per tenant
- **Budget**: `$value` export = 1 request per message
- **Batch size**: 100 messages listed per page, export 100 → SCP → next batch
- **Backpressure**: If 429 response, honor `Retry-After` header, exponential backoff
- **Estimated total**: mintprints.com mailbox likely 10K–50K messages → 1–5 hours

### EML Import Rate
- mail-archiver EmlImportService is I/O-bound on Postgres INSERT
- Current MBox import processes ~250 emails/min → EML should be comparable
- Safe to upload in batches of 100–500 .eml files

### Coexistence with Active MBox Import
- MBoxImportService and EmlImportService are independent background services
- They watch different directories (`/app/uploads/mbox` vs `/app/uploads/eml`)
- **No conflict** — EML import can run while MBox import completes
- However, **recommended to wait** until GAP-OP-922 MBox import finishes to avoid DB contention

## Failure + Rollback Plan

### Failure Modes
1. **Graph 429 (throttled)**: Retry with `Retry-After`; resume from last exported ID
2. **Graph 5xx**: Retry 3x with backoff; log and skip after 3 failures
3. **SCP failure**: Retry transfer; files are idempotent (same filename = overwrite)
4. **EmlImportService crash**: Container restart; service auto-resumes on remaining files
5. **Disk full**: Pre-check: `df /srv/mail-archiver` must be <70% before starting batch

### Rollback
- EML files in `/srv/mail-archiver/uploads/eml/` can be deleted
- Imported messages can be identified by account/provider tag and bulk-deleted from DB if needed
- No external state is modified (Graph mailbox is read-only)

## Exact Runbook Commands (execute after GAP-OP-922 closes)

```bash
# 1. Verify GAP-OP-922 is closed and MBox import is done
./bin/ops cap run gaps.status | grep GAP-OP-922

# 2. Verify disk headroom on VM 214
ssh communications-stack "df -h /srv/mail-archiver"
# Must be <70% used

# 3. Run microsoft.mail.list.all to get total message count
./bin/ops cap run microsoft.mail.list.all --format count-only

# 4. Run microsoft.mail.export.mime in batched mode
./bin/ops cap run microsoft.mail.export.mime --batch-size 100 --output-dir /tmp/microsoft-export/

# 5. Transfer batch to VM 214
scp /tmp/microsoft-export/*.eml communications-stack:/srv/mail-archiver/uploads/eml/

# 6. Monitor EmlImportService progress
ssh communications-stack "sudo docker logs -f mail-archiver 2>&1 | grep EmlImportService"

# 7. Verify counts match
ssh communications-stack "sudo docker exec mail-archiver-db psql -U mailuser -d MailArchiver -t -c \"SELECT COUNT(*) FROM mail_archiver.\\\"ArchivedEmails\\\"\""

# 8. Close gap
./bin/ops cap run gaps.close --id GAP-OP-970 --status fixed --fixed-in "<commit>"

# 9. Verify
./bin/ops cap run verify.pack.run communications
```

## References

- Account linkage contract: `ops/bindings/mail.archiver.account.linkage.contract.yaml` (microsoft-primary entry)
- Communications stack contract: `ops/bindings/communications.stack.contract.yaml`
- Microsoft Graph MIME export: `GET /users/{upn}/messages/{id}/$value`
- EmlImportService: watches `/app/uploads/eml/` directory on VM 214
- Parent loop: LOOP-MAIL-ARCHIVER-COMMS-MIGRATION-20260225
