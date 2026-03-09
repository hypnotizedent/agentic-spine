---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-08
scope: backup-onboarding
---

# Backup Onboarding Checklist

Purpose: enforce a deterministic onboarding flow whenever a new VM/service is
introduced so backups do not drift outside governance.

Use this checklist with D69 VM creation governance and backup domain SSOT.

## 1. Intake

- Service/VM ID assigned and present in `ops/bindings/vm.lifecycle.yaml`.
- Recovery classification decided: `critical`, `important`, or `rebuildable`.
- Initial RPO/RTO target captured in loop notes.

## 2. VM-Level Backup Enrollment

- Add VM/CT to correct `vzdump` job (`pve` or `proxmox-home`).
- Verify with receipt:

```bash
./bin/ops cap run backup.vzdump.status
./bin/ops cap run backup.vzdump.status proxmox-home
```

- If missing, mutate with governed capability:

```bash
./bin/ops cap run backup.vzdump.vmid.set -- --host <target> --job-id <job_id> --vmids <csv>
```

## 3. App-Level Backup Decision

- Decide app-level requirement (`required` or `vzdump-only`) with written rationale.
- Freeze exclusions up front so regenerable payloads do not creep into canonical backups.
- Explicitly record if the service falls into one of these excluded classes:
  - large media payload
  - duplicate MinIO payload copy
  - Immich photo corpus
  - regenerable metadata/cache surface
- If required:
  - Implement executable backup script on owning host.
  - Schedule cron/systemd timer.
  - Ensure canonical destination storage exists and is writable.
  - Run one live backup and confirm artifacts.

## 4. SSOT Registration

- Add/adjust target(s) in `ops/bindings/backup.inventory.yaml`.
- Add schedule visibility entry in `ops/bindings/backup.calendar.yaml`.
- Generate calendar artifact:

```bash
./bin/ops cap run backup.calendar.generate
```

## 5. Restore SOP

- Create or update service restore SOP in `docs/governance/`.
- Must include:
  - backup artifact paths and naming
  - restore commands
  - secrets recovery namespace/path
  - validation commands post-restore

## 6. Offsite + Notification Wiring

- Decide offsite replication required/not-required (with reason).
- Backup receipts and backup-monitor alerts must target `backups@spine.ronny.works`.
- Ensure degraded backup alerts are wired (`backup.monitor` + communications queue).
- Verify queue path remains healthy:

```bash
./bin/ops cap run backup.monitor
./bin/ops cap run communications.alerts.queue.slo.status
```

## 7. Verification + Gap Closure

- Run backup health verify:

```bash
./bin/ops cap run backup.status
```

- Confirm new targets show expected freshness.
- Close linked loop gaps with strict receipts only after verification passes.

## Canonical Plane Reminder

- Shop VM/LXC source artifacts: `tank/backups/vzdump/dump/`
- Shop cold backups: `md1400/backup-cold/...`
- Home HA + home Pi-hole: Synology
