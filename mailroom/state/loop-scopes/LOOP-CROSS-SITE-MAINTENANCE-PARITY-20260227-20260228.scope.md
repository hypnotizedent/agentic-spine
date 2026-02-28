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
- Step 0: Initial forensic sweep — capture script-level gaps (COMPLETE — 26 gaps filed)
- Step 1: Deep forensic audit — Proxmox, HA, UniFi, NAS (COMPLETE — 35 additional gaps filed)
- Step 2: Implement changes
- Step 3: Verify and close out

## Linked Gaps (61 total)

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

### Group E: Normalization — DNS, SSOT Drift, Stale Data (10 gaps)
- GAP-OP-1110: Home DNS policy fragmented across 3 resolvers with no contract [CRITICAL]
- GAP-OP-1111: Pi-hole binary missing on LXC 105 — DNS filtering dead [CRITICAL]
- GAP-OP-1121: HA Proxmox shop integration stale — 200+ unavailable entities [HIGH]
- GAP-OP-1130: HOME_NETWORK_DEVICE_ONBOARDING.md and AUDIT_RUNBOOK stale [MEDIUM]
- GAP-OP-1131: Tailscale SSOT drift — nvidia-shield, firestick, accept-routes false [MEDIUM]
- GAP-OP-1132: UDR7 gateway MAC mismatch in registry [MEDIUM]
- GAP-OP-1133: 2 unknown devices on home network not in any registry [MEDIUM]
- GAP-OP-1135: PVE 8.4.1 vs shop 9.1.4 + 19 pending APT updates [MEDIUM]
- GAP-OP-1136: Orphan LVM volumes + stale backups for destroyed VMs [MEDIUM]
- GAP-OP-1139: HA token name inconsistency (HA_API_TOKEN vs IOT_HA_API_TOKEN) [MEDIUM]

### Group F: Governance — PVE Boot, Security, Domains (10 gaps)
- GAP-OP-1112: PVE boot-order race — 3 services FAILED after reboot [CRITICAL]
- GAP-OP-1113: LXC 105 missing onboot:1 [CRITICAL] (FIXED this session)
- GAP-OP-1114: pvescheduler FAILED — backup jobs not running [CRITICAL] (FIXED this session)
- GAP-OP-1115: Home site boot recovery contract missing [CRITICAL]
- GAP-OP-1122: No VLAN segmentation — flat 10.0.0.0/24 [HIGH]
- GAP-OP-1123: SSH security not hardened — root password auth, no firewall [HIGH]
- GAP-OP-1124: proxmox-boot-tool broken — kernel updates may not propagate to EFI [HIGH]
- GAP-OP-1125: Home site zero domain decomposition [HIGH]
- GAP-OP-1134: Postfix mail delivery broken — backup notifications failing [MEDIUM]
- GAP-OP-1137: Home VM/LXC provisioning profile missing [MEDIUM]

### Group G: HA Integration Health + Power Cycle Resilience (10 gaps)
- GAP-OP-1116: HA dashboards missing after power cycle [HIGH]
- GAP-OP-1117: Two HA addons failed to start at boot [HIGH]
- GAP-OP-1118: Jellyfin auth expired (container ID c4c376c45905) [HIGH]
- GAP-OP-1119: ZWave JS integration in setup_retry [HIGH]
- GAP-OP-1120: Zigbee2MQTT all entities unavailable [HIGH]
- GAP-OP-1127: HA integration health contract missing [HIGH]
- GAP-OP-1126: WiFi IoT DHCP reservations unverified [HIGH]
- GAP-OP-1128: Switches not normalized — no IP clustering contract [MEDIUM]
- GAP-OP-1129: OTBR setup_retry — Thread network down [MEDIUM]
- GAP-OP-1138: US-8-60W switch all entities unavailable [MEDIUM]

### Group H: Low Priority — Cleanup + Optimization (5 gaps)
- GAP-OP-1140: HA automations stale (mailbox 4mo, auto_dismiss never) [LOW]
- GAP-OP-1141: NAS single NIC — no link aggregation [LOW]
- GAP-OP-1142: CPU governor performance on 24/7 mini-PC [LOW]
- GAP-OP-1143: Ghost USB NIC + unused WiFi interface residuals [LOW]
- GAP-OP-1144: No home compose target bindings active [LOW]

## Severity Summary
- CRITICAL: 17
- HIGH: 22
- MEDIUM: 17
- LOW: 5

## Immediate Fixes Applied This Session
- LXC 105: `pct set 105 -onboot 1` (GAP-OP-1113)
- pvescheduler: `systemctl restart pvescheduler` (GAP-OP-1114)
- pve-firewall: `systemctl restart pve-firewall` (GAP-OP-1112 partial)
- /etc/hosts: fixed stale `192.168.12.202 pve.prox pve` → `10.0.0.179 proxmox-home.local proxmox-home`

## Success Criteria
- All 61 linked gaps resolved (fixed or documented-as-accepted-risk).
- infra.maintenance.window supports LXC lifecycle for home site.
- NAS has shutdown/startup capabilities and is in startup.sequencing.yaml.
- Scripts read site list from contract — 3rd site onboarding requires binding-only changes.
- Home site has boot recovery contract, DNS policy, VLAN segmentation plan.
- HA integrations all healthy after power cycle with post-boot verification.
- All SSOTs updated (device registry, onboarding docs, Tailscale, DHCP audit).
- Relevant verify pack(s) pass.

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.
