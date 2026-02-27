---
status: draft
owner: "@ronny"
last_verified: 2026-02-26
scope: communications-mail-archiver-overlap-baseline
---

# Mail Archiver Alias Overlap Baseline (2026-02-26)

## Purpose

Capture the canonical pre-dedupe overlap baseline after Stalwart runtime account canonicalization (`MailAccountId=2`).

## Canonical MailAccounts

| MailAccountId | Name | EmailAddress | Provider | State |
|---|---|---|---|---|
| 1 | Takeout Import | takeout-import@local.invalid | IMPORT | active/import-only |
| 2 | Stalwart Ops | ops@spine.ronny.works | IMAP | active |
| 3 | Microsoft Import | ronny@mintprints.com | IMPORT | active/import-only |
| 4 | iCloud Primary | ronny@hantash.com | IMAP | active |

## Archived Counts

| MailAccountId | Archived Emails |
|---|---|
| 1 | 223,631 |
| 2 | 2 |
| 3 | 9,087 |
| 4 | 1,820 |

## Header Alias Presence Baseline

Metric: number of archived rows whose `From/To/Cc/Bcc` contains the alias string.

| MailAccountId | hypnotizedent@gmail.com | ronny@hantash.com | ronny@mintprints.com | info@mintprints.com | ops@spine.ronny.works |
|---|---:|---:|---:|---:|---:|
| 1 | 18,985 | 8,218 | 2,637 | 128,040 | 0 |
| 2 | 0 | 0 | 0 | 0 | 2 |
| 3 | 8 | 2 | 8,911 | 3,769 | 1 |
| 4 | 2 | 1,537 | 1 | 2 | 0 |

## Message-ID Intersection Baseline

| Pair | Overlap Message-IDs |
|---|---:|
| 1_vs_2 | 0 |
| 1_vs_3 | 1 |
| 1_vs_4 | 0 |
| 2_vs_3 | 0 |
| 2_vs_4 | 0 |
| 3_vs_4 | 1 |

## Governance Decision

- Preserve all ingested mail now.
- Do not dedupe in this lane.
- Dedupe/overlap reduction is deferred to `GAP-OP-1002`.

## Related Receipts

- `CAP-20260226-184322__communications.mailarchiver.import.status__Rs06h19633`
- `CAP-20260226-184322__services.health.status__Rej4219635`
- `CAP-20260226-184322__services.health.status__Rck3i19636`
- `CAP-20260226-184322__verify.pack.run__Rvx6619637`
- `CAP-20260226-184322__verify.pack.run__Rj1v619634`
