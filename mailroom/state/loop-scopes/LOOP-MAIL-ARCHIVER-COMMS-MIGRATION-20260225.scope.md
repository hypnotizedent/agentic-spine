---
loop_id: LOOP-MAIL-ARCHIVER-COMMS-MIGRATION-20260225
created: 2026-02-25
status: active
owner: "@ronny"
scope: communications
priority: high
objective: Migrate mail-archiver from finance-stack (VM 211) to communications-stack (VM 214), import 200GB Gmail takeout mbox, establish email account linkage contract, and create backup/retention governance for the mail archive system
---

# Loop Scope: LOOP-MAIL-ARCHIVER-COMMS-MIGRATION-20260225

## Objective

Safely migrate the mail-archiver service from finance-stack (VM 211) to communications-stack (VM 214), import legacy Gmail takeout data, and establish governed email archival with proper contracts, backup, and retention policies.

## Background

- Mail-archiver was originally on docker-host (VM 200), migrated to VM 211 during LOOP-FINANCE-VM-SEPARATION-20260211
- VM 200 (docker-host) is on decommission track — still holds a 200GB Gmail takeout .mbox file that was NEVER imported
- Communications-stack (VM 214) is the canonical governed home for all email/communications services (Stalwart, Radicale)
- Mail-archiver does not belong on the finance stack long-term — it should co-locate with the communications domain

## Gaps Linked

- GAP-OP-921: Mail-archiver relocation VM 211 → VM 214 (high)
- GAP-OP-922: Gmail takeout 200GB mbox import — missing capability/SOP (high)
- GAP-OP-923: Email account linkage contract missing (medium)
- GAP-OP-924: Mail-archiver backup/restore contract missing (medium)
- GAP-OP-925: Mail-archiver storage retention/lifecycle governance missing (medium)

## Execution Phases

| Phase | Action | Status |
|-------|--------|--------|
| P0 | Register gaps + loop (capture-only) | DONE |
| P1 | Control-plane bindings (contracts, vm.lifecycle, compose targets) | DONE |
| P2 | Backup + export from VM 211 (pg_dump, data export, count verification) | NOT STARTED |
| P3 | Shadow deploy on VM 214 (compose, restore, parity check) | NOT STARTED |
| P4 | Gmail mbox import (build capability, import 200GB, verify, delete source) | NOT STARTED |
| P5 | Email account linkage (Gmail/iCloud/Microsoft/Stalwart connections) | NOT STARTED |
| P6 | Traffic cutover (cloudflared/DNS, startup sequencing update) | NOT STARTED |
| P7 | Legacy cleanup (stop on VM 211, update registries, remove from finance probes) | NOT STARTED |

## Unknowns / Blockers

- **BLOCKER-1 [RESOLVED 2026-02-25]**: Exact mail-archiver software identity locked.
  - Image: `s1t5/mailarchiver:latest`
  - Entrypoint: `dotnet MailArchiver.dll`
- **BLOCKER-2 [RESOLVED 2026-02-25]**: Exact Gmail takeout source path locked.
  - Path: `/mnt/docker/mail-archive-import/All-mail.mbox`
  - Size: `189440618235` bytes
- **BLOCKER-3**: Email account list for archiver linkage — which Gmail addresses, which iCloud addresses, which Microsoft/Outlook addresses, which Stalwart spine.ronny.works mailboxes (ops@, alerts@, noreply@?)
- **BLOCKER-4**: Retention policy decision — keep all email forever? Prune after N years? Per-account policies?
- **BLOCKER-5**: Backup cadence decision — daily vzdump? Postgres pg_dump cron? Both? Frequency?

## Constraints

- CAPTURE-ONLY session (2026-02-25): no runtime changes, no VM/container changes, no compose edits, no DNS/tunnel changes, no secret writes, no imports/cutovers
- Docker-host (VM 200) decommission blocked until all data safely migrated
- Communications-stack (VM 214) volume is named (safe for compose lifecycle)
- Finance-stack health probe (finance.stack.status) currently monitors mail-archiver — must be updated at P7

## Success Criteria

- [ ] Mail-archiver running on VM 214 with all data intact (message count parity)
- [ ] 200GB Gmail takeout fully imported with verification receipt
- [ ] Gmail, iCloud, Microsoft, Stalwart accounts linked with connection receipts
- [ ] Backup contract in place with tested restore procedure
- [ ] Retention policy documented and enforced
- [ ] All drift gates passing post-migration
- [ ] Docker-host (VM 200) has zero mail-archiver data remaining
- [ ] finance.stack.status updated to exclude mail-archiver
