---
status: open
owner: "@ronny"
last_verified: 2026-02-12
scope: loop-scope
loop_id: LOOP-HOME-INFRA-DOC-PARITY-20260212
severity: medium
---

# Loop Scope: LOOP-HOME-INFRA-DOC-PARITY-20260212

## Goal

Bring home infrastructure (proxmox-home, Beelink SER7) documentation to parity
with shop infrastructure (pve, R730XD). Currently shop has 3-14x more SSOT
coverage across all binding categories.

## Problem / Current State

Audit on 2026-02-12 found the following parity gaps between shop and home:

| Category | Shop | Home | Ratio |
|---|---|---|---|
| SSH targets | 16 | 5 | 3.2x |
| Docker compose targets | 10 | 0 | N/A |
| VM lifecycle entries | 12 | 0 | N/A |
| Backup inventory (enabled) | 17 | 1 of 5 | 17x |
| Secrets namespaces | 42 | 5 | 8.4x |
| Health probes | 44 | 0 | N/A |
| Lesson docs | 14 | 1 | 14x |
| Capabilities (infra) | 15 | 0 | N/A |

Root cause: home infra pre-dates spine governance and was never retrofitted.

## Success Criteria

1. Home VMs (100, 101, 102, 103, 105) registered in `vm.lifecycle.yaml`
2. Home docker stacks registered in `docker.compose.targets.yaml`
3. Home services have health probes in `services.health.yaml`
4. Backup inventory entries enabled (flip `enabled: false` -> `true` after artifact validation)
5. Home network governance docs created (onboarding, audit runbook)
6. At least 1 home-specific operational capability exists
7. Key home service lesson docs created (HA, Vaultwarden, Pi-hole, download-home)

## Phases

### P1: SSOT Binding Retrofit
- [ ] Add VMs 100, 101, 102, 103, 105 to `vm.lifecycle.yaml`
- [ ] Add home docker hosts/stacks to `docker.compose.targets.yaml`
- [ ] Add home health probes to `services.health.yaml`
- [ ] Validate and enable remaining backup inventory entries

### P2: Network Governance Docs
- [ ] Create `HOME_NETWORK_DEVICE_ONBOARDING.md` (parallel to shop runbook)
- [ ] Create home network audit runbook or extend shop runbook for dual-site

### P3: Operational Capabilities
- [ ] Add home backup status capability (or extend existing to cover home)
- [ ] Add home VM check capability

### P4: Lesson Documentation
- [ ] Home Assistant operational lessons
- [ ] Vaultwarden-home backup/restore runbook
- [ ] Pi-hole-home configuration lessons
- [ ] Download-home (LXC 103) operational notes

## Receipts

- Gap: GAP-OP-117 (registered in this proposal)
- Proposal: CP-20260212-014446__home-infrastructure-documentation-parity (scope + gap registration)
