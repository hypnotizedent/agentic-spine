# L4: Proxmox Alignment Diff

> **Lane:** LANE-D (Proxmox Alignment)
> **Loop:** LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
> **Generated:** 2026-02-17
> **Scope:** Cross-repo VM/Proxmox inventory parity audit
> **Status:** READ-ONLY DISCOVERY (no changes made)

---

## Executive Summary

Three source trees contain Proxmox infrastructure data:

| Repo | Authority | Files Audited |
|------|-----------|---------------|
| `agentic-spine` (spine) | **Canonical SSOT** | `vm.lifecycle.yaml`, `ssh.targets.yaml`, `vm.lifecycle.derived.yaml`, `vm.lifecycle.contract.yaml` |
| `workbench` | Operational configs | `infra/data/CONTAINER_INVENTORY.yaml`, `dotfiles/ssh/config.d/tailscale.conf` |
| `ronny-ops` (legacy) | **Superseded** | `infrastructure/docs/locations/SHOP.md`, `infrastructure/dotfiles/ssh/config.d/tailscale.conf`, `infrastructure/data/backup_inventory.json`, `infrastructure/docs/audits/2026-01-01-holistic-infrastructure-audit.md`, `mint-os/docs/.archive/legacy-2025/Session-Logs/proxmox-audit-report.md` |

**Verdict:** 23 mismatches found across clusters. The spine SSOT (`vm.lifecycle.yaml`) is the most current and complete. Legacy `ronny-ops` is significantly stale (missing 8 VMs, wrong IPs, wrong users, wrong cluster naming). Workbench has moderate drift (missing 8 VMs, uses `pve-shop` naming).

---

## Cluster Naming Alignment

| Cluster | Spine SSOT | Workbench | Legacy `ronny-ops` | Mismatch? |
|---------|-----------|-----------|---------------------|-----------|
| Shop (R730XD) | `pve` | `pve-shop` | `pve` / `pve-shop` (mixed) | **YES** — workbench uses `pve-shop` in CONTAINER_INVENTORY; SSH config aliases both `pve` and `pve-shop` |
| Home (Beelink) | `proxmox-home` | `proxmox-home` | `proxmox-home` | OK |

**Note:** The SSH alias `Host pve pve-shop` in both workbench and legacy SSH configs means `pve-shop` resolves correctly at the SSH layer, but the CONTAINER_INVENTORY.yaml `location: pve-shop` diverges from spine canonical `proxmox_host: pve`.

---

## Cluster: `pve` (Dell R730XD — Shop)

### VM Inventory Parity

| VMID | Hostname | Spine Status | Workbench | Legacy `ronny-ops` | Mismatch Detail |
|------|----------|-------------|-----------|---------------------|-----------------|
| 200 | docker-host | **active** | Listed (stale, no containers) | Listed (active, 96GB/16c/300GB) | **LAN IP**: spine=`192.168.1.200`, legacy=`192.168.12.191` |
| 201 | media-stack | **decommissioned** (2026-02-12) | Listed (stale, VM 201) | Listed (active, 16GB/4c/50GB) | **STALE**: legacy+workbench still list as active; spine correctly decommissioned |
| 202 | automation-stack | **active** | Listed (stale, no containers) | Listed (active, 16GB/4c/100GB) | **LAN IP**: spine=`192.168.1.110`, legacy=`192.168.12.228` |
| 203 | immich | **active** | Listed (stale, no containers) | Not in VM table | **Missing** from legacy SHOP.md VM table |
| 204 | infra-core | **active** | Not listed | Not listed | **Missing** from both workbench CONTAINER_INVENTORY and legacy |
| 205 | observability | **active** | Not listed | Not listed | **Missing** from both |
| 206 | dev-tools | **active** | Not listed | Not listed | **Missing** from both |
| 207 | ai-consolidation | **active** | Listed (verified, 2 containers) | Not listed | **Missing** from legacy; workbench has current data |
| 209 | download-stack | **active** | Not listed | Not listed | **Missing** from both (created 2026-02-08) |
| 210 | streaming-stack | **active** | Not listed | Not listed | **Missing** from both (created 2026-02-08) |
| 211 | finance-stack | **active** | Not listed | Not listed | **Missing** from both (created 2026-02-11) |
| 212 | mint-data | **active** | Not listed | Not listed | **Missing** from both (created 2026-02-12) |
| 213 | mint-apps | **active** | Not listed | Not listed | **Missing** from both (created 2026-02-12) |
| 9000 | ubuntu-2404-cloudinit-template | **template** | Not listed | Not listed | Template, not expected in operational inventories |

### Network Drift (Shop)

| VMID | Hostname | Spine LAN IP | Legacy LAN IP | Spine Tailscale | Legacy Tailscale | Subnet Drift? |
|------|----------|-------------|---------------|-----------------|------------------|---------------|
| 200 | docker-host | `192.168.1.200` | `192.168.12.191` | `100.92.156.118` | `100.92.156.118` | **YES** — subnet changed from `192.168.12.0/24` to `192.168.1.0/24` |
| 201 | media-stack | decommissioned | `192.168.12.205` | n/a | `100.117.1.53` | **STALE** — VM destroyed |
| 202 | automation-stack | `192.168.1.110` | `192.168.12.228` | `100.98.70.70` | `100.98.70.70` | **YES** — same subnet migration |
| pve (host) | pve | n/a | `192.168.12.184` | `100.96.211.33` | `100.96.211.33` | **YES** — legacy still shows old `192.168.12.0/24` subnet |

**Root cause:** The shop network was re-addressed from `192.168.12.0/24` (T-Mobile router era) to `192.168.1.0/24` (UDR6 era). Legacy docs still reflect the old subnet.

---

## Cluster: `proxmox-home` (Beelink SER7 — Home)

### VM Inventory Parity

| VMID | Hostname | Spine Status | Workbench | Legacy `ronny-ops` | Mismatch Detail |
|------|----------|-------------|-----------|---------------------|-----------------|
| 100 | homeassistant | **active** | Not listed | Listed (active) | OK — workbench doesn't track home VMs |
| 101 | immich | **stopped** | Not listed | Listed (active) | **STALE**: legacy lists as active; spine correctly marks stopped |
| 102 | vaultwarden | **decommissioned** (2026-02-16) | Listed (stale, no containers) | Listed (active) | **STALE**: legacy+workbench still show active; spine correctly decommissioned |
| 103 | download-home | **stopped** (LXC) | Not listed | Listed (stopped, 34+ days) | Legacy matches spine status |
| 105 | pihole-home | **stopped** (LXC) | Not listed | Not in VM table | Tracked in spine; implicit in legacy Pi-hole docs |

### Legacy-Only Entries (Not in Spine)

| VMID | Hostname | Legacy Status | Spine Status | Note |
|------|----------|-------------|-------------|------|
| 104 | NPM | stopped (LXC) | **Not tracked** | Legacy lists Nginx Proxy Manager LXC; spine omits (likely abandoned) |

---

## SSH Target Alignment

### SSH User Mismatches

| Host | Spine `ssh.targets.yaml` User | Workbench SSH Config User | Legacy SSH Config User | Mismatch? |
|------|------------------------------|---------------------------|------------------------|-----------|
| docker-host | `docker-host` | `docker-host` | `docker-host` | OK |
| pve | `root` | `root` | `root` | OK |
| proxmox-home | `root` | `root` | `root` | OK |
| automation-stack | `automation` | `automation` | `automation` | OK |
| media-stack | decommissioned | not listed | `media` | **STALE** — legacy still has entry |
| vault/vaultwarden | decommissioned (ssh.targets) | `root` | `root` | **STALE** — workbench+legacy still have entry |
| ha | `hassio` | `hassio` | `hassio` | OK |
| immich | `ronny` | `root` | `root` | **MISMATCH** — spine says `ronny`, both configs say `root` |
| pihole-home | `root` | `root` | `root` | OK |
| infra-core | `ubuntu` | `ubuntu` | not listed | OK (workbench current) |
| download-home | `root` | `root` | not listed | OK |

### SSH Hosts Missing from Non-Spine Sources

| SSH Target | In Spine | In Workbench SSH | In Legacy SSH |
|------------|----------|------------------|---------------|
| observability | Yes | No | No |
| dev-tools | Yes | No | No |
| ai-consolidation | Yes | No | No |
| download-stack | Yes | No | No |
| streaming-stack | Yes | No | No |
| finance-stack | Yes | No | No |
| mint-data | Yes | No | No |
| mint-apps | Yes | No | No |
| switch-shop | Yes | No | No |
| idrac-shop | Yes | No | No |
| nvr-shop | Yes | No | No |
| ap-shop | Yes | No | No |
| udr-shop | Yes | No | No |
| udr-home | Yes | No | No |
| nas | Yes | Yes | Yes |

---

## Legacy Audit Report Staleness (proxmox-audit-report.md)

The legacy audit report (`ronny-ops/mint-os/docs/.archive/legacy-2025/Session-Logs/proxmox-audit-report.md`) was generated 2025-12-21 and is now severely stale:

| Aspect | Audit Report (2025-12-21) | Current Spine SSOT (2026-02-17) | Delta |
|--------|--------------------------|----------------------------------|-------|
| VMs on pve | 3 (200, 201, 202) | 13 active + 1 decommissioned + 1 template | +11 VMs |
| VM 201 | Running | Decommissioned (destroyed 2026-02-12) | Destroyed |
| local-lvm capacity | 90% full (critical) | N/A (likely resolved via ZFS migration) | Possibly resolved |
| Backup jobs | None configured | `backup.inventory.yaml` exists | Governance improved |
| Network subnet | `192.168.12.0/24` | `192.168.1.0/24` | Re-addressed |
| Storage pools | tank, media, local-lvm | Same + per-VM ZFS datasets | Expanded |
| Proxmox version | 9.0.3 | Not tracked in spine bindings | Unknown if upgraded |

---

## Workbench CONTAINER_INVENTORY.yaml Staleness

| Issue | Detail |
|-------|--------|
| VM 201 media-stack listed | Decommissioned in spine 2026-02-12; workbench still lists with Tailscale IP `100.117.1.53` |
| VM 102 vaultwarden listed | Decommissioned in spine 2026-02-16; workbench still lists |
| VMs 204-206, 209-213 missing | 8 active VMs not tracked |
| Location field uses `pve-shop` | Spine canonical is `pve` |
| `snapshot_stale: true` on most hosts | Self-documented staleness — last full sweep incomplete |

---

## Gap Candidates

| # | Type | Severity | Description | Affected Files |
|---|------|----------|-------------|----------------|
| 1 | `stale-ssot` | P3 | Workbench `CONTAINER_INVENTORY.yaml` lists decommissioned VMs 201+102 and misses 8 active VMs | `workbench/infra/data/CONTAINER_INVENTORY.yaml` |
| 2 | `stale-ssot` | P3 | Workbench SSH config missing 8 active VM targets (observability, dev-tools, ai-consolidation, download-stack, streaming-stack, finance-stack, mint-data, mint-apps) | `workbench/dotfiles/ssh/config.d/tailscale.conf` |
| 3 | `stale-ssot` | P4 | Legacy SSH config missing 10+ hosts, lists decommissioned media-stack and vaultwarden | `ronny-ops/infrastructure/dotfiles/ssh/config.d/tailscale.conf` |
| 4 | `stale-ssot` | P4 | Legacy SHOP.md uses old `192.168.12.0/24` subnet, lists only 3 VMs | `ronny-ops/infrastructure/docs/locations/SHOP.md` |
| 5 | `stale-ssot` | P4 | Legacy proxmox-audit-report shows 3 VMs, critical storage warnings likely resolved | `ronny-ops/mint-os/docs/.archive/legacy-2025/Session-Logs/proxmox-audit-report.md` |
| 6 | `missing-entry` | P3 | Immich SSH user mismatch: spine says `ronny`, workbench+legacy SSH configs say `root` | `workbench/dotfiles/ssh/config.d/tailscale.conf`, `ronny-ops/infrastructure/dotfiles/ssh/config.d/tailscale.conf` |
| 7 | `stale-ssot` | P4 | Legacy lists VMID 104 (NPM LXC) not tracked in spine `vm.lifecycle.yaml` | `ronny-ops` holistic audit |
| 8 | `stale-ssot` | P3 | Workbench CONTAINER_INVENTORY uses `pve-shop` location; spine canonical is `pve` | `workbench/infra/data/CONTAINER_INVENTORY.yaml` |

---

## Extraction Value Assessment

| Legacy File | Unique Data? | Extract? | Rationale |
|-------------|-------------|----------|-----------|
| `proxmox-audit-report.md` | Hardware specs (disk serials, SMART, ZFS layout) | **Partial** | Physical hardware details not captured in spine bindings — useful for DR reference |
| `SHOP.md` | Camera inventory, rack layout, shopping lists | **Yes** | Camera/NVR/physical plant data has no spine equivalent |
| `proxmox-gitops-evaluation.md` | Architecture evaluation (DEFERRED) | **No** | Decision documented, no active value |
| `backup_inventory.json` | App-level backup schedules | **Partial** | Spine has `backup.inventory.yaml` but legacy has per-app detail |
| `PVE-INCIDENT-HANDOFF.md` | Incident response procedures | **Yes** | Runbook content not yet in spine |
| `STANDARDS_VM_LXC.md` | VM provisioning standards | **Partial** | Spine has `VM_CREATION_CONTRACT.md` but legacy has more detail |
| `SOP_VM_SETUP.md` | Step-by-step VM creation | **Partial** | Overlaps with spine contract |
| Legacy SSH config | Host aliases | **No** | Fully superseded by workbench + spine |

---

## Recommendations

1. **Workbench CONTAINER_INVENTORY.yaml** — remove decommissioned VMs (201, 102), add missing active VMs, normalize `pve-shop` to `pve`.
2. **Workbench SSH config** — add missing 8 VM targets, remove decommissioned entries, fix immich user from `root` to `ronny`.
3. **Legacy ronny-ops** — no remediation needed (repo is being archived). All unique data should be extracted per the table above.
4. **Spine vm.lifecycle.yaml** — consider tracking VMID 104 (NPM LXC) as decommissioned/abandoned for completeness.
5. **Physical plant data** (camera inventory, rack layout, NVR config) from legacy SHOP.md needs a spine-native home if not already covered.

---

*End of L4 Proxmox Alignment Diff*
