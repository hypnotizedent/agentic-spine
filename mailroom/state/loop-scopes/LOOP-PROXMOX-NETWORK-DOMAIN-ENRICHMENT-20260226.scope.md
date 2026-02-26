---
loop_id: LOOP-PROXMOX-NETWORK-DOMAIN-ENRICHMENT-20260226
created: 2026-02-26
status: closed
owner: "@ronny"
scope: governance
priority: medium
objective: Enrich proxmox-network + backup domain packs with storage gate D234, add storage_tier cross-reference to vm.lifecycle.yaml for cross-registry normalization.
related_loops:
  - LOOP-STORAGE-BOOT-DRIVE-AUDIT-20260226
---

# Loop Scope: LOOP-PROXMOX-NETWORK-DOMAIN-ENRICHMENT-20260226

## Objective

Enrich proxmox-network and backup domain packs with the new storage placement gate D234 and add path triggers for the storage placement policy. Add `storage_tier` field to `vm.lifecycle.yaml` for cross-registry normalization with `infra.storage.placement.policy.yaml`.

## Context

The proxmox-network domain pack (26 gates) is missing coverage for D234 (storage boot-drive audit). The backup domain pack (5 gates) also lacks D234. Meanwhile, `vm.lifecycle.yaml` has no `storage_tier` field, creating a cross-registry gap with `infra.storage.placement.policy.yaml`.

D234 currently PASSES even with boot-drive violations because VMs 204-214 SSH via Tailscale (not reachable from macOS). Adding D234 to proxmox-network won't break the pack.

## Phases

- P1: Create loop scope (this file)
- P2: Add D234 to proxmox-network + backup domain packs with path triggers
- P3: Add secondary_domains for D234 in gate.execution.topology.yaml
- P4: Add storage_tier field to all 14 active VMs in vm.lifecycle.yaml
- P5: Verify (no gate breakage across proxmox-network, backup, infra packs)

## Success Criteria

- D234 present in proxmox-network and backup domain packs
- Path triggers added for storage placement policy
- D234 secondary_domains includes backup
- All 14 active VMs have storage_tier field
- All affected verify packs PASS

## Definition Of Done

- gate.domain.profiles.yaml updated
- gate.execution.topology.yaml updated
- vm.lifecycle.yaml updated with storage_tier
- verify.pack.run proxmox-network PASS
- verify.pack.run backup PASS
- verify.pack.run infra PASS (unchanged)
