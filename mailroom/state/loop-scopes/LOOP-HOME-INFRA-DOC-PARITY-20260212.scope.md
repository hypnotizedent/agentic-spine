---
status: closed
owner: "@ronny"
last_verified: 2026-02-12
scope: loop-scope
loop_id: LOOP-HOME-INFRA-DOC-PARITY-20260212
severity: medium
closed: 2026-02-12
---

# Loop Scope: LOOP-HOME-INFRA-DOC-PARITY-20260212

## Goal

Bring home infrastructure (proxmox-home, Beelink SER7) documentation to parity
with shop infrastructure (pve, R730XD). Currently shop has 3-14x more SSOT
coverage across all binding categories.

## Problem / Current State

Audit on 2026-02-12 found the following parity gaps between shop and home:

| Category | Shop | Home (before) | Home (after) |
|---|---|---|---|
| SSH targets | 16 | 5 | 5 (unchanged — already had targets) |
| Docker compose targets | 10 | 0 | **1** (vaultwarden-home) |
| VM lifecycle entries | 12 | 0 | **5** (VMs 100-102, LXCs 103,105) |
| Backup inventory (enabled) | 17 | 1 of 5 | **2 of 5** (VM 100 enabled) |
| Health probes | 44 | 0 | **3** (HA, Vaultwarden, Pi-hole) |
| Lesson docs | 14 | 1 | **5** (+HA, Vaultwarden, Pi-hole, download-home) |
| Capabilities (infra) | 15 | 0 | **3** (backup.status, vm.status, health.check) |
| Network governance docs | 4 | 0 | **2** (onboarding, audit runbook) |

Root cause: home infra pre-dates spine governance and was never retrofitted.

## Success Criteria

1. [x] Home VMs (100, 101, 102, 103, 105) registered in `vm.lifecycle.yaml`
2. [x] Home docker stacks registered in `docker.compose.targets.yaml`
3. [x] Home services have health probes in `services.health.yaml`
4. [~] Backup inventory entries enabled (2 of 5 — LXCs blocked by GAP-OP-118, VM 101 pending Sun)
5. [x] Home network governance docs created (onboarding, audit runbook)
6. [x] At least 1 home-specific operational capability exists (3 created)
7. [x] Key home service lesson docs created (HA, Vaultwarden, Pi-hole, download-home)

## Phases

### P1: SSOT Binding Retrofit — COMPLETE
- [x] Add VMs 100, 101, 102, 103, 105 to `vm.lifecycle.yaml` (5 entries, live specs from SSH)
- [x] Add home docker hosts/stacks to `docker.compose.targets.yaml` (vaultwarden-home)
- [x] Add home health probes to `services.health.yaml` (3 probes)
- [x] Validate and enable backup inventory entries (VM 100 enabled; LXC 103 FAILING — GAP-OP-118)

### P2: Network Governance Docs — COMPLETE
- [x] Create `HOME_NETWORK_DEVICE_ONBOARDING.md` (parallel to shop runbook)
- [x] Create `HOME_NETWORK_AUDIT_RUNBOOK.md` (parallel to shop runbook)

### P3: Operational Capabilities — COMPLETE
- [x] Add `home.backup.status` capability (SSH to proxmox-home, check artifact freshness)
- [x] Add `home.vm.status` capability (qm list + pct list via SSH)
- [x] Add `home.health.check` capability (HTTP probes for HA + Vaultwarden)

### P4: Lesson Documentation — COMPLETE
- [x] `HOME_ASSISTANT_LESSONS.md` (architecture, coordinators, integrations, fixes)
- [x] `VAULTWARDEN_HOME_RUNBOOK.md` (architecture, backup, restore, health)
- [x] `PIHOLE_HOME_LESSONS.md` (stopped state, re-enablement steps, v6 notes)
- [x] `DOWNLOAD_HOME_NOTES.md` (stopped state, GAP-OP-118, volume mapping rule)

## Remaining Work (deferred)

- GAP-OP-118: LXC vzdump NFS permission failure — blocks LXC 103/105 backup enablement
- VM 101 P2 weekly backup: first run Sun Feb 15 — cannot validate until then
- Secrets namespace expansion for home services (deferred, low priority)

## Receipts

- Gap: GAP-OP-117 (registered), GAP-OP-118 (registered)
- Proposal 1: CP-20260212-014446__home-infrastructure-documentation-parity (scope + gap — applied ffa1716)
- Proposal 2: CP-20260212-080601__home-infra-p1-ssot-binding-retrofit (P1 bindings — applied 06c673b)
- Proposal 3: CP-20260212-083216__home-infra-p2-p3-p4-docs-caps-lessons (P2-P4 docs + caps + lessons)
