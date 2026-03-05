---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-27
scope: communications-mail-archiver-overlap-cleanup
---

# Mail Archiver Overlap Cleanup Playbook

## Objective

Pre-stage a deterministic, replay-safe cleanup workflow for `GAP-OP-1002` so the
worker can execute cleanup only after Microsoft deep archive import completes and
account counts are stable.

## Governance Inputs

- Gap: `GAP-OP-1002` (`ops/bindings/operational.gaps.yaml`)
- Parent loop: `LOOP-MAIL-ARCHIVER-OVERLAP-CLEANUP-20260226`
- Alias baseline: `docs/governance/domains/communications/MAIL_ARCHIVER_ALIAS_OVERLAP_BASELINE_20260226.md`
- Account linkage: `ops/bindings/mail.archiver.account.linkage.contract.yaml`
- Alias boundaries: `ops/bindings/mail.archiver.alias.boundary.contract.yaml`
- Retention rules: `ops/bindings/mail.archiver.retention.contract.yaml`

## Canonical Boundary Model

Use `MailAccountId` as provenance authority. Do not collapse rows across accounts
unless policy explicitly allows it.

- Account 1: Gmail takeout historical lane
- Account 2: Stalwart ops lane
- Account 3: Microsoft mintprints business lane
- Account 4: iCloud personal lane

Cross-account overlap is preserved by default. Cleanup focuses on deterministic
within-account import artifacts first.

## Classification Taxonomy

1. `strict_dedupe_candidate`
- Same `MailAccountId`
- Same `ContentHash`
- Group size > 1
- Action: safe preview candidate (keep lowest `Id`, delete others only after approval)

2. `manual_review_candidate`
- Same `MailAccountId`
- Same `MessageId`
- Different `ContentHash`
- Action: preserve until reviewed

3. `preserve_cross_account_overlap`
- Same `MessageId` appears in multiple account IDs
- Action: preserve all copies

4. `unsubscribe_noise_signal`
- Content contains unsubscribe/opt-out/newsletter indicators
- Action: classification-only for retrieval ranking, not deletion

5. `possible_zero_purpose`
- `unsubscribe_noise_signal`
- not outgoing
- no attachments
- Action: review queue only, not auto-delete

## What To Look For

- `unsubscribe`/`manage preferences`/`opt out` signal prevalence by account
- High-volume sender domains that dominate noise
- Same alias crossing accounts in the same year (timeline drift hotspot)
- Strict duplicate groups likely caused by re-import/retry artifacts

## Dry-Run Capability

Use the governed read-only capability:

```bash
./bin/ops cap run communications.mailarchiver.overlap.plan
./bin/ops cap run communications.mailarchiver.overlap.plan -- --json
```

This outputs:
- overlap classification (strict duplicates, manual review candidates, cross-account overlap)
- unsubscribe/noise counts and top sender domains
- alias/account hit matrix
- alias timeline multi-account hotspots
- execution checklist for later cleanup lane

## Import Path Guardrail (pre-cleanup)

When deep archive files are already on VM 214, use remote import mode:

```bash
echo "yes" | ./bin/ops cap run communications.mailarchiver.import.eml.remote -- --remote-dir /srv/mail-archiver/import/ews-archive-full --account-id 3
```

Use local upload mode only when files exist on the operator machine:

```bash
echo "yes" | ./bin/ops cap run communications.mailarchiver.import.eml.upload -- --source-dir /local/path/with/eml
```

## Execution Checklist (when import is done)

1. Confirm import completion
- `GAP-OP-973` fixed
- `communications.mailarchiver.import.status` shows stable `db_archived_emails_count` over two windows
- no active import jobs

2. Freeze a pre-cleanup snapshot
- capture overlap report JSON
- capture import status receipt
- capture account totals

3. Approve strict candidate scope only
- include only `strict_dedupe_candidate`
- exclude cross-account overlap and manual-review classes

4. Execute governed cleanup mutation
- apply lowest-`Id` keep rule per strict duplicate group
- record run keys and manifest of affected row IDs

5. Post-clean verification
- rerun overlap report
- validate strict duplicate count drops to target
- validate cross-account overlap unchanged

6. Close loop/gap
- update `GAP-OP-1002` notes with before/after metrics
- close parent loop with receipts

## Disaster Retrieval Guidance

Use boundary-first retrieval before content-first retrieval.

1. Determine incident lane
- mintprints business: account 3 first
- personal historical: accounts 1 and 4 first
- spine ops audit: account 2 first

2. Resolve alias timeline
- use alias boundary contract validity windows
- if alias appears in multiple accounts for the same year, keep both lanes in search scope

3. Search in priority order
- account boundary
- alias list
- time window
- subject/body constraints

This preserves forensic traceability while keeping agent navigation deterministic.
