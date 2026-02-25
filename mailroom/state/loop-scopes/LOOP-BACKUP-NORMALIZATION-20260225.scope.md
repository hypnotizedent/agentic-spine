---
status: active
owner: "@ronny"
last_verified: 2026-02-25
scope: loop-scope
loop_id: LOOP-BACKUP-NORMALIZATION-20260225
severity: high
---

# Loop Scope: LOOP-BACKUP-NORMALIZATION-20260225

## Objective

Normalize all backup governance across both sites (shop R730XD + home Beelink) into a single governed, systematic, predetermined backup system. Fix ungoverned Proxmox email routing, build backup notification pipeline through Stalwart, publish backup schedule to Radicale calendar home, create missing restore SOPs, clean stale inventory entries, and establish onboarding contract for new services.

## Problem / Current State (2026-02-25)

Audit findings:
- Proxmox-home sends backup notification emails directly to personal inbox via built-in postfix, bypassing Stalwart on VM 214
- No automated pipeline: backup fails → alert queued → email sent (147 pending alert intents in comms queue)
- Backup calendar exists in `backup.calendar.yaml` (8 events) but is NOT published to Radicale — invisible alongside other calendar events
- Missing restore SOPs: Stalwart (VM 214), Finance stack (VM 211), Home Assistant (VM 100)
- VMs 211-214 may be missing from actual `/etc/pve/jobs.cfg` vzdump job (calendar binding only lists 200,202-210)
- Dead home entries: VM 101 (destroyed), VM 102 (decommissioned), LXC 103 (destroyed) still in inventory
- No backup onboarding contract for new services/VMs

## Success Criteria

1. Proxmox email on both hosts either disabled or relayed through Stalwart SMTPS
2. Backup notification pipeline: `backup.status` detects stale → queues alert intent → `communications.alerts.flush` sends via Stalwart
3. All backup calendar events published to Radicale calendar home (visible on iPhone/calendar)
4. Restore SOPs created for Stalwart, Finance stack, Home Assistant
5. VMs 211-214 confirmed in pve vzdump job (or added via `backup.vzdump.vmid.set`)
6. Stale home entries cleaned from `backup.inventory.yaml` and `backup.calendar.yaml`
7. Backup onboarding checklist added to BACKUP_GOVERNANCE.md
8. All gaps closed, verify pass

## Phases

### Phase 0: Proxmox Email Routing Fix (P0 — HIGH)
- [ ] SSH to `proxmox-home`: reconfigure postfix to relay through Stalwart SMTPS (465) or disable email notifications
- [ ] SSH to `pve`: same — relay through Stalwart or disable
- [ ] Verify no more direct-to-personal-inbox emails from Proxmox
- [ ] File drift gate: Proxmox notification relay must use Stalwart or be disabled

### Phase 1: Vzdump Job Verification + Inventory Hygiene
- [ ] Run `backup.vzdump.status` to capture actual `/etc/pve/jobs.cfg` state
- [ ] Verify VMs 211, 212, 213, 214 are in vzdump job; if missing, add via `backup.vzdump.vmid.set`
- [ ] Remove/mark decommissioned entries: VM 101, VM 102, LXC 103 from inventory
- [ ] Remove dead `home-vzdump-p1-daily` job from proxmox-home (LXC 103 destroyed)
- [ ] Remove dead VM 101 from `backup-home-p2-weekly` job on proxmox-home
- [ ] Update `backup.calendar.yaml` to remove dead events, add VMs 211-214 if newly enrolled
- [ ] Run `backup.vzdump.prune` dry-run to assess retention compliance

### Phase 2: Backup Notification Pipeline
- [ ] Create `backup.monitor` capability — wraps `backup.status`, queues alerts for stale/failed via comms alert pipeline
- [ ] Define notification contract: which failures → severity → sender (alerts@spine.ronny.works)
- [ ] Wire to control-cycle cadence or standalone cron
- [ ] File drift gate: backup notification pipeline must be active

### Phase 3: Radicale Calendar Integration
- [ ] Publish all `backup.calendar.yaml` events to Radicale via `calendar.home.event.create`
- [ ] Include app-level cron jobs and offsite sync schedule
- [ ] Verify staggered windows visible on calendar
- [ ] File drift gate or extend D146: backup events must exist in Radicale calendar home

### Phase 4: Missing Restore SOPs
- [ ] Create `STALWART_BACKUP_RESTORE.md` (VM 214 — config, volumes, TLS certs, mailbox data)
- [ ] Create `FINANCE_STACK_BACKUP_RESTORE.md` (VM 211 — Firefly III pg_dump, Paperless export, Ghostfolio DB)
- [ ] Create `HOMEASSISTANT_BACKUP_RESTORE.md` (VM 100 — ha.backup.create, VM-level, HAOS specifics)
- [ ] Enable app-level backup for Firefly III (pg_dump to NAS, add to inventory + calendar)
- [ ] Update BACKUP_GOVERNANCE.md hierarchy table with new SOPs

### Phase 5: Onboarding Contract
- [ ] Add "Backup Onboarding Checklist" section to BACKUP_GOVERNANCE.md
- [ ] Define: vzdump enrollment, app-level assessment, inventory entry, calendar event, restore SOP, offsite sync decision
- [ ] Verify D69 (vm-creation-governance-lock) covers backup onboarding or create companion gate

## Definition of Done

- All 8 gaps closed
- Verify pass on infra pack + core pack
- No Proxmox emails hitting personal inbox
- Backup schedule visible on Radicale calendar
- Stale/failed backups produce governed email alerts
- Every active VM has backup coverage + restore path documented
- New service onboarding checklist prevents future drift
