---
loop_id: LOOP-CROSS-SITE-MAINTENANCE-PARITY-20260227-20260228
created: 2026-02-28
status: active
owner: "@ronny"
scope: cross
priority: medium
objective: Normalize maintenance lifecycle governance so all sites (shop, home, future 3rd) are held to the same standard. LXC containers, NAS nodes, and Proxmox hosts must be first-class citizens in the orchestration boundary. Covers 4 gap groups: LXC lifecycle in maintenance scripts, NAS lifecycle governance, home site parity, and script site-abstraction for 3rd-site readiness.
---

# Loop Scope: LOOP-CROSS-SITE-MAINTENANCE-PARITY-20260227-20260228

## Objective

Normalize maintenance lifecycle governance so all sites (shop, home, future 3rd) are held to the same standard. LXC containers, NAS nodes, and Proxmox hosts must be first-class citizens in the orchestration boundary. Covers 4 gap groups: LXC lifecycle in maintenance scripts, NAS lifecycle governance, home site parity, and script site-abstraction for 3rd-site readiness.

## Steps
- Step 1: capture and classify findings (COMPLETE — 26 gaps filed)
- Step 2: implement changes
- Step 3: verify and close out

## Linked Gaps (26)

### Group A: LXC Container Lifecycle — NOT GOVERNED (5 gaps)
- GAP-OP-1037: infra-proxmox-maintenance uses only qm — no pct (LXC) shutdown/startup support [CRITICAL]
- GAP-OP-1038: LXC 105 (pihole-home) absent from startup.sequencing.yaml [CRITICAL]
- GAP-OP-1039: resolve_vm_order() Python only reads vm_ids key — ignores lxc_ids [CRITICAL]
- GAP-OP-1040: assert_qm_exists() / is_qm_running() fail on LXC container IDs [HIGH]
- GAP-OP-1041: infra-post-power-recovery only checks docker ps — no pct list / LXC inspection [HIGH]

### Group B: Synology NAS Lifecycle — NOT GOVERNED (6 gaps)
- GAP-OP-1042: No nas.shutdown capability [CRITICAL]
- GAP-OP-1043: No nas.startup capability [CRITICAL]
- GAP-OP-1044: NAS not in startup.sequencing.yaml — no dependency ordering [CRITICAL]
- GAP-OP-1045: NAS not in SERVICE_REGISTRY.yaml — no SLO, domain, terminal role [HIGH]
- GAP-OP-1046: NAS NFS mount dependencies undeclared — silent failure on NAS down [HIGH]
- GAP-OP-1047: D139 gate scope insufficient — validates presence only, not lifecycle [MEDIUM]

### Group C: Home vs Shop Site Parity (7 gaps)
- GAP-OP-1048: Recovery phase hardcoded to skip home site entirely [CRITICAL]
- GAP-OP-1049: REBOOT_HEALTH_GATE.md covers shop only — no home site procedure [HIGH]
- GAP-OP-1050: Home site has zero observability capabilities (shop has 15+) [HIGH]
- GAP-OP-1061: Home has 2 health probes vs shop 30+ [HIGH]
- GAP-OP-1058: Home backup: no offsite sync, no app-level, no prune [MEDIUM]
- GAP-OP-1059: Home storage policy undeclared in infra.storage.placement.policy.yaml [MEDIUM]
- GAP-OP-1060: LXC 105 backup 69h stale — no gate enforces freshness precondition [MEDIUM]

### Group D: Script Site-Abstraction — Blocks 3rd Site (8 gaps)
- GAP-OP-1062: infra-maintenance-window rejects non-shop/home site names [CRITICAL]
- GAP-OP-1063: shutdown_sites() / startup_sites() hardcoded case statements [CRITICAL]
- GAP-OP-1064: enforce_shop_oob_policy() checks SITE_ID != shop literally [CRITICAL]
- GAP-OP-1065: OOB guard LAN devices hardcoded (idrac-shop, switch-shop, nvr-shop) [HIGH]
- GAP-OP-1066: Poweroff flags site-specific (--poweroff-shop / --poweroff-home) [HIGH]
- GAP-OP-1067: Default host ID pve hardcoded in multiple scripts [MEDIUM]
- GAP-OP-1068: Recovery decision hardcoded (skip if home) — should be contract-driven [HIGH]
- GAP-OP-1069: OOB subnet hardcoded to 192.168.1.0/24 (shop LAN) [MEDIUM]

## Severity Summary
- CRITICAL: 11
- HIGH: 10
- MEDIUM: 5

## Success Criteria
- All 26 linked gaps resolved (fixed or documented-as-accepted-risk).
- infra.maintenance.window supports LXC lifecycle for home site.
- NAS has shutdown/startup capabilities and is in startup.sequencing.yaml.
- Scripts read site list from contract — 3rd site onboarding requires binding-only changes.
- Relevant verify pack(s) pass.

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.
