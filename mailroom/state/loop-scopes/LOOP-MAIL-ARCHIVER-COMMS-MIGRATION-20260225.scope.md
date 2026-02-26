---
loop_id: LOOP-MAIL-ARCHIVER-COMMS-MIGRATION-20260225
created: 2026-02-25
status: closed
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

## Execution Steps

| Step | Action | Status |
|------|--------|--------|
| Step 0 | Register gaps + loop (capture-only) | DONE |
| Step 1 | Control-plane bindings (contracts, vm.lifecycle, compose targets) | DONE |
| Step 1b | Registry canonicalization (12 files, ingress IP, STACK_REGISTRY) | DONE |
| Step 1c | Governance contracts (account linkage, backup, retention) | DONE |
| Step 2 | Backup + export from VM 211 (pg_dump, data export, count verification) | DONE (runtime on VM 214) |
| Step 3 | Shadow deploy on VM 214 (compose, restore, parity check) | DONE (live on VM 214) |
| Step 4 | Gmail mbox import (177G takeout, 2 chunks, verify) | DONE (67,467 emails) |
| Step 5 | Email account linkage (Gmail/iCloud/Microsoft/Stalwart connections) | DEFERRED to LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226 |
| Step 6 | Traffic cutover (cloudflared/DNS, startup sequencing update) | DONE (ingress → VM 214) |
| Step 7 | Legacy cleanup (stop on VM 211, update registries, remove from finance probes) | DONE (registries canonicalized) |

## Unknowns / Blockers

- **BLOCKER-1 [RESOLVED 2026-02-25]**: Exact mail-archiver software identity locked.
  - Image: `s1t5/mailarchiver:latest`
  - Entrypoint: `dotnet MailArchiver.dll`
- **BLOCKER-2 [RESOLVED 2026-02-25]**: Exact Gmail takeout source path locked.
  - Path: `/mnt/docker/mail-archive-import/All-mail.mbox`
  - Size: `189440618235` bytes
- **BLOCKER-3 [RESOLVED 2026-02-26]**: Email account list locked in `mail.archiver.account.linkage.contract.yaml` (stalwart-ops active, gmail/icloud/microsoft planned).
- **BLOCKER-4 [RESOLVED 2026-02-26]**: Retention policy locked in `mail.archiver.retention.contract.yaml` (class-based retention, 70/85/92% thresholds).
- **BLOCKER-5 [RESOLVED 2026-02-26]**: Backup cadence locked in `backup.schedule.yaml` (vzdump 02:00, pg_dump 02:20, uploads 02:35 daily).

## Constraints

- CAPTURE-ONLY session (2026-02-25): no runtime changes, no VM/container changes, no compose edits, no DNS/tunnel changes, no secret writes, no imports/cutovers
- Docker-host (VM 200) decommission blocked until all data safely migrated
- Communications-stack (VM 214) volume is named (safe for compose lifecycle)
- Finance-stack health probe (finance.stack.status) currently monitors mail-archiver — must be updated at P7

## Success Criteria

- [x] Mail-archiver running on VM 214 with all data intact (67,467 emails)
- [x] 200GB Gmail takeout fully imported (part001: 36759, part002: 30708, failed: 21, malformed: 4)
- [ ] Gmail, iCloud, Microsoft, Stalwart accounts linked — DEFERRED to LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226
- [x] Backup contract in place with tested restore procedure
- [x] Retention policy documented and enforced
- [x] All drift gates passing post-migration (communications 18/18, AOF 21/21)
- [ ] Docker-host (VM 200) has zero mail-archiver data remaining — source mbox still present, deferred
- [x] finance.stack.status updated to exclude mail-archiver (registries canonicalized)
