---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-10
verification_method: receipt + on-site audit + live-ssh-inspection
scope: shop-infrastructure
parent_receipts:
  - "DELL_N2024P_FACTORY_RESET_20260205_122838"
---

# SHOP SERVER SSOT

> Canonical, spine-native description of the **Shop rack**.
>
> **Covers:** Dell R730XD (`pve`), MD1400 DAS, Dell N2024P switch, NVR/cameras, UPS, and the Shop LAN.
>
> **Authority boundary:**
> - Hostnames/IPs: [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) (canonical)
> - Hardware/topology/ops procedures: this doc (canonical within `shop-infrastructure`)
>
> **No secrets rule:** Credentials, RTSP URLs, WiFi SSIDs, and passwords must be stored in Infisical. This repo never contains secret values.

---

## Quick Reference (No Secrets)

| Component | Canonical Name | Access | Credentials (Infisical) |
|----------|-----------------|--------|--------------------------|
| Gateway | `udr-shop` (UniFi UDR6) | `https://192.168.1.1` or UniFi app | N/A (adopted via UniFi app) |
| Proxmox host | `pve` | `ssh pve` or `https://pve:8006` | `infrastructure/prod:/spine/shop/pve/*` |
| iDRAC | `idrac-shop` | `https://192.168.1.250` | `infrastructure/prod:/spine/shop/idrac/*` |
| Switch | `switch-shop` (Dell N2024P) | `http://192.168.1.2` or `ssh admin@192.168.1.2` | `infrastructure/prod:/spine/shop/switch/*` |
| NVR | `nvr-shop` | `http://192.168.1.216` | `infrastructure/prod:/spine/shop/nvr/*` |
| WiFi AP | `ap-shop` (EAP225) | `http://192.168.1.185` | `infrastructure/prod:/spine/shop/wifi/*` |

Notes:
- If an IP above ever conflicts with [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md), treat this table as stale and update it.
- If a service is reachable only by LAN IP, it is **not** a Tier-1 dependency (Tailscale is the control plane).

---

## Physical Infrastructure

### Rack: Rittal VRIS38S (42U)

| Property | Value |
|----------|-------|
| Model | Rittal VRIS38S |
| Height | 42U |
| Serial | 164115 |
| Build Date | 2000-04-11 |
| Location | Shop floor |
| Patch Panels | 2x Vertical Cable Cat6 24-port (top unlabeled, bottom labeled) |

### Service Tags & Serial Numbers

| Equipment | Service Tag / Serial | Rack Position | Notes |
|-----------|---------------------|---------------|-------|
| Dell PowerEdge R730XD | HSZZD42 | U17-18 | Main production server |
| Dell MD1400 DAS | HRW2F42 | U14-16 | Direct Attached Storage |
| Dell Networking N2024P | — (MAC: F8:B1:56:73:A0:D0) | U39 | 24-port PoE+ switch |
| APC Back-UPS Pro 900 | BVN900M1 | Floor | 900VA UPS |
| Hikvision ERI-K216-P16 | ERI-K216-P161620220307CCRRJ54340404WCVU | Upstairs 9U rack (separate) | 16-channel PoE NVR |
| TP-Link EAP225 | — (MAC: 54:AF:97:2F:C6:6E, mgmt: 192.168.1.185) | — | WiFi AP — kernel 3.3.8, dropbear SSH (ssh-rsa only) |

### Rack Inventory

| Component | Model | Role | Verified |
|----------|-------|------|----------|
| Router | UniFi Dream Router 6 (UDR6) | Shop gateway, DHCP, DNS relay (192.168.1.1) | 2026-02-09 |
| Server | Dell PowerEdge R730XD (12-bay LFF) | Shop hypervisor (`pve`) | 2026-02-08 |
| DAS | Dell MD1400 | Bulk storage shelf (cabled, driver blocked — GAP-OP-037) | 2026-02-08 |
| Switch | Dell N2024P | Shop LAN switching / PoE (24-port, 190W PoE budget) | 2026-02-05 |
| UPS | APC Back-UPS Pro 900 | 900VA / 540W, ~10-15 min runtime at full load | 2026-02-08 |
| NVR | Hikvision ERI-K216-P16 | 16-channel PoE NVR (upstairs 9U rack, separate from main) | 2026-02-05 |
| WiFi AP | TP-Link EAP225 | Shop WiFi (SSIDs: "Production" 5GHz, "Production 2.5" 2.4GHz) | 2026-02-10 |

### R730XD Hardware Specifications

| Component | Value | Verified |
|-----------|-------|----------|
| **Service Tag** | HSZZD42 | 2026-02-08 |
| **Model** | Dell PowerEdge R730XD (2U) | 2026-01-21 |
| **Rails** | DP/N 0FYK4G (installed) | 2026-02-08 |
| **CPU** | 2x Intel Xeon E5-2640 v3 (16 cores / 32 threads, 2.6GHz) | 2026-01-21 |
| **RAM** | 192GB DDR4 ECC (12x 16GB DIMMs, 12/24 slots populated) | 2026-02-08 |
| **Power** | 2x 750W Platinum PSU (redundant) | 2026-02-08 |
| **Proxmox Version** | 9.1.4 (PVE 9.1.0) | 2026-02-08 |
| **Kernel** | 6.14.8-2-pve | 2026-02-08 |
| **Boot Drives** | 2x Seagate ST9500620SS 500GB SAS 2.5" (rear flex bays) | 2026-02-08 |
| **Drive Bays** | 12x 3.5" LFF (front) + 2x 2.5" SFF (rear flex) | 2026-02-08 |
| **Controller/HBA** | Dell HBA330 Mini (Broadcom LSI SAS3008, IT mode, FW 16.00.11.00) | 2026-02-08 |
| **Second SAS** | Microchip PM8072 SPCv 12G 16-port (PCIe, driver blocked — GAP-OP-037) | 2026-02-08 |
| **NICs** | 4x 1GbE (eno1-4) + iDRAC, only eno1 active (bridged to vmbr0) | 2026-02-08 |

**Drive bay population (12 front 3.5" LFF):**
- Slots 0-7: 8x Seagate ST4000NM0063 4TB SAS (Constellation ES.3) → `tank` pool
- Slots 8-11: 4x Seagate ST8000AS0002 8TB SATA (Archive/SMR) → `media` pool
- All 12 front bays occupied. No free drive slots.

**Second SAS controller note (GAP-OP-037 / LOOP-MD1400-SAS-RECOVERY-20260208):**
The PM8072 (PCIe slot 82:00.0) connects to the MD1400 DAS via Dell SAS cable (DP/N 0GYK61).
The cable is connected and the MD1400 is powered on (owner-verified 2026-02-08), but the
`pm80xx` kernel driver cannot bind due to a PCI vendor ID mismatch:
- **Actual device:** `11f8:8072` (Microchip Technology, post-acquisition)
- **Driver expects:** `117C:8072` (PMC-Sierra, pre-acquisition)

Hot-loading the driver with `new_id` fails — the PM8072 firmware requires cold-boot
initialization (MPI handshake timeout, `chip_init failed [ret: -16]`).
On-site cold boot with AC drain was performed (2026-02-09) and still failed; treat the PM8072 as hardware/firmware defective and follow the replace/reflash path in the loop scope.

### ZFS Storage Pools

| Pool | Size | Allocated | Free | Capacity | Health | Verified |
|------|------|-----------|------|----------|--------|----------|
| **media** | 29.1T | 16.7T | 12.4T | 57% | ONLINE | 2026-02-08 |
| **tank** | 29.1T | 7.39T | 21.7T | 25% | ONLINE | 2026-02-08 |

**media pool:** RAIDZ1, 4x Seagate ST8000AS0002 8TB (Archive/SMR drives)
- Serials: Z840A33Q, Z840A22Z, Z840A33F, Z840AAFE
- **WARNING:** SMR drives are suboptimal for ZFS. Monitor for performance degradation.
- Last scrub: in progress (started 2026-02-08 00:24), 0 errors so far
- Weekly scrub cron: `0 4 * * 0` (added since last audit)

**tank pool:** RAIDZ2, 8x Seagate ST4000NM0063 4TB (Constellation ES.3, enterprise SAS)
- Serials: Z1Z86298, Z1Z85V4W, Z1Z84YNR, Z1Z85V47, Z1Z862H5, Z1Z8629N, Z1Z85TFE, Z1Z861ZN
- Last scrub: 2026-02-08, 0 errors (completed in 4h18m)

**tank datasets (2026-02-10):**
- `tank/docker`: 610GB (was 567GB on 2026-02-07)
- `tank/docker/download-stack`: 12.3GB (new — media stack split)
- `tank/docker/streaming-stack`: 6.70GB (new — media stack split)
- `tank/docker/databases`: 205K
- `tank/backups`: 3.49TB
- `tank/immich/photos`: 1.15TB
- `tank/immich/db`: 205K
- `tank/vms`: 108GB (was 256K — VM disk images growing)

### VM Inventory (2026-02-10)

| VMID | Name | Status | RAM | Boot Disk | Notes |
|------|------|--------|-----|-----------|-------|
| 200 | docker-host | running | 96GB | 300GB | Mint OS production |
| 201 | media-stack | **destroyed** | — | — | Decommissioned 2026-02-10 (split to 209/210, VM destroyed) |
| 202 | automation-stack | running | 16GB | 100GB | n8n + Ollama |
| 203 | immich | running | 16GB | 50GB | Shop photos (Tailscale: immich-1) |
| 204 | infra-core | running | 8GB | 50GB | Core infra (cloudflared, pihole, infisical, vaultwarden, caddy-auth) |
| 205 | observability | running | 8GB | 50GB | Prometheus, Grafana, Loki, Uptime Kuma |
| 206 | dev-tools | running | 8GB | 50GB | Gitea, Gitea Actions runner, PostgreSQL |
| 207 | ai-consolidation | running | 32GB | 200GB | Qdrant + AnythingLLM (DHCP, onboot=1) |
| 209 | download-stack | running | 8GB | 50GB | radarr, sonarr, lidarr, prowlarr, sabnzbd, tdarr, trailarr |
| 210 | streaming-stack | running | 8GB | 50GB | jellyfin, navidrome, jellyseerr, bazarr, homarr |
| 9000 | template | stopped | 2GB | 3.5GB | Ubuntu 24.04 cloud-init template |

**Total RAM allocated:** 216GB across 9 running VMs (host has 192GB — overcommitted by 24GB, acceptable with balloon/KSM)

**NOTE:** vzdump backup job covers all 9 running shop VMs: `200,202,203,204,205,206,207,209,210`. Verify with `./bin/ops cap run backup.status`.

### NFS Exports from PVE (2026-02-09)

| Export | Client | Purpose | Mode |
|--------|--------|---------|------|
| `/tank/docker` | 192.168.1.0/24 | Docker volumes | rw |
| `/tank/backups` | docker-host (192.168.1.200) | Backup target | rw |
| `/tank/vms` | docker-host (192.168.1.200) | VM storage | rw |
| `/tank/docker/download-stack` | download-stack (192.168.1.209) | Download app configs | rw |
| `/media` | download-stack (192.168.1.209) | Media files | rw |
| `/tank/docker/streaming-stack` | streaming-stack (192.168.1.210) | Streaming app configs | rw |
| `/media` | streaming-stack (192.168.1.210) | Media files | **ro** |

All exports use `sync,no_subtree_check,no_root_squash` over **LAN IPs** (not Tailscale — avoids D-state deadlock). streaming-stack has read-only `/media` access (consumers only, no writes).

### MD1400 DAS Specifications

| Component | Value | Verified |
|-----------|-------|----------|
| **Service Tag** | HRW2F42 | 2026-02-08 |
| **Rails** | DP/N 0JRJ9P (installed) | 2026-02-08 |
| **Enclosure** | 12-bay 3.5" SATA/SAS | 2026-02-08 |
| **SAS Cable** | Dell DP/N 0GYK61 (Mini-SAS HD SFF-8644, connected) | 2026-02-08 |
| **Connection** | PM8072 HBA → MD1400 | 2026-02-08 |
| **Drives** | Unknown — invisible to OS (GAP-OP-037) | 2026-02-08 |
| **Status** | Powered + cabled, but driver cannot bind. See LOOP-MD1400-SAS-RECOVERY-20260208 | 2026-02-08 |

### UPS Specifications

| Component | Value | Verified |
|-----------|-------|----------|
| **Model** | APC Back-UPS Pro 900 | 2026-02-08 |
| **Serial** | BVN900M1 | 2026-02-08 |
| **Capacity** | 900VA / 540W | 2026-02-08 |
| **Runtime** | ~10-15 min at full load | 2026-02-08 |
| **Outlets** | 8 total (4 battery + surge, 4 surge only) | 2026-02-08 |
| **Connected Equipment** | R730XD, MD1400, N2024P | 2026-02-08 |

### Accessories & Cables

| Item | Part Number | Use | Status |
|------|-------------|-----|--------|
| R730XD Rails | 0FYK4G | Server rack mount | Installed |
| MD1400 Rails | 0JRJ9P | DAS rack mount | Installed |
| SAS Cable | 0GYK61 | PM8072 HBA → MD1400 | Connected |

### Hardware Compatibility Notes

- **R730XD:** 12x 3.5" LFF front bays (all occupied), 2x 2.5" SFF rear flex bays (boot drives). No free drive slots.
- **R730XD HBA330 Mini:** IT-mode SAS3008, direct JBOD passthrough to ZFS. No RAID controller — drives are passed through directly.
- **MD1400:** 12-bay 3.5" shelf. Physically cabled (Dell 0GYK61 SAS cable, owner-verified). **PM8072 driver cannot bind** — PCI vendor ID mismatch (0x11f8 Microchip vs 0x117C PMC-Sierra in kernel driver) + firmware requires cold boot init. Zero drives visible. See GAP-OP-037 / LOOP-MD1400-SAS-RECOVERY-20260208.

---

## Network (Shop)

### Topology

```
Internet → T-Mobile 5G GW (CGNAT, locked — double NAT)
              → UDR6 WAN (DHCP from T-Mobile) — 192.168.1.1
                  → Dell N2024P Switch (192.168.1.2, Gi1/0/1)
                      ├─ Gi1/0/2: R730XD vmbr0 (pve, 192.168.1.184)
                      ├─ Gi1/0/3: R730XD iDRAC (192.168.1.250)
                      ├─ Gi1/0/4: NVR (192.168.1.216)
                      ├─ Gi1/0/5-23: Available
                      └─ Gi1/0/24: WiFi AP EAP225 (192.168.1.185)
```

### Subnet

| Item | Value |
|------|-------|
| Subnet | `192.168.1.0/24` |
| Gateway | `192.168.1.1` (UniFi UDR6) |
| Switch | `192.168.1.2` (Dell N2024P, VLAN 1 management) |
| DHCP range | `192.168.1.100–192.168.1.199` (UDR6) |
| DHCP DNS | `192.168.1.204` (Pi-hole on infra-core) |
| WAN | T-Mobile 5G Home Internet (~865/309 Mbps, CGNAT) |

### Switch Port Assignments (Dell N2024P)

| Port | Device | MAC | IP | Status |
|------|--------|-----|-----|--------|
| Gi1/0/1 | UDR6 LAN (uplink) | — | 192.168.1.1 | UP @ 1Gbps |
| Gi1/0/2 | R730XD (PVE, vmbr0) | 44:A8:42:22:2C:A6 | 192.168.1.184 | UP @ 1Gbps |
| Gi1/0/3 | R730XD (iDRAC) | 44:A8:42:26:C3:11 | 192.168.1.250 | UP @ 1Gbps |
| Gi1/0/4 | NVR (Hikvision ERI-K216-P16) | 24:0F:9B:30:F1:E7 | 192.168.1.216 | UP @ 1Gbps |
| Gi1/0/5-23 | Available | — | — | Down |
| Gi1/0/24 | TP-Link EAP225 (WiFi AP) | 54:AF:97:2F:C6:6E | 192.168.1.185 | UP @ 1Gbps |
| Te1/0/1-2 | 10G SFP+ (unused) | — | — | Down |

### Camera Network

Cameras are on the NVR's internal PoE network (`192.168.254.0/24`), fed by a Netgear PoE switch connected to the NVR's PoE ports. Separate from the shop LAN.

| Component | Value |
|-----------|-------|
| **NVR** | Hikvision ERI-K216-P16 (16-channel, FW V4.30.216) |
| **NVR Location** | Upstairs 9U rack (separate from main rack) |
| **Camera VLAN** | 192.168.254.0/24 (NVR internal) |
| **NVR IP (Shop LAN)** | 192.168.1.216 (`nvr-shop`) |
| **Camera Switch** | Netgear PoE switch (uplink to NVR PoE ports) |
| **Total Channels** | 16 (12 configured, 8 online, 4 offline) |

See [CAMERA_SSOT.md](CAMERA_SSOT.md) for the full channel registry, Frigate readiness config, storage details, and verification commands.

---

## Virtualization / Workloads (Shop)

### Proxmox Host: `pve`

This is the Shop hypervisor. Core VM inventory (foundational scope):

| VM | Purpose | Foundational Scope |
|----|---------|--------------------|
| `docker-host` | Production docker workloads (Mint OS) | yes |
| `infra-core` | Core infra (cloudflared, pihole, infisical, vaultwarden, caddy-auth) | yes |
| `observability` | Monitoring (prometheus, grafana, loki, uptime-kuma) | yes |
| `dev-tools` | Git forge + CI (gitea, actions runner) | yes |
| `automation-stack` | Automation / n8n / Ollama | yes |
| `download-stack` | Download automation (*arr stack, sabnzbd, tdarr) | yes |
| `streaming-stack` | Media streaming (jellyfin, navidrome, jellyseerr) | yes |
| `ai-consolidation` | AI workloads | deferred |
| `media-stack` | Decommissioned 2026-02-10 (VM 201 destroyed; split to 209/210) | decommissioned |
| `immich` | Photos | deferred |

If you need to make a placement decision ("where should this run?"):
1. Read [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) for the Tier table.
2. Use this doc for capacity/constraints (hardware + what already runs here).
3. If still unclear, open a mailroom item and create/attach an open loop.

---

## Scheduled Tasks (pve) — verified 2026-02-10

| Schedule | Command | Purpose | Status |
|----------|---------|---------|--------|
| `0 2 * * *` | `/usr/local/bin/zfs-snapshot.sh` | Daily ZFS snapshot of root datasets | ACTIVE |
| `0 3 * * 0` | `zpool scrub tank` | Weekly scrub of tank pool | ACTIVE |
| `0 4 * * 0` | `zpool scrub media` | Weekly scrub of media pool | ACTIVE (new) |
| `02:00 daily` | vzdump VMs `200,202,203,204,205,206,207,209,210` | Snapshot backup to tank-backups (zstd, keep-last=2) | ACTIVE |

**Source:** crontab (`crontab -l`) and `/etc/pve/jobs.cfg`.

**Notes:**
- vzdump covers all 9 running shop VMs (VM 201 decommissioned 2026-02-10; GAP-OP-030 closed).

---

## Verification Commands (Safe)

Run from the MacBook (over Tailscale):

```bash
# Tier 1 reachability
for host in pve docker-host proxmox-home; do
  echo "=== $host ==="
  ssh -o ConnectTimeout=5 $host uptime 2>/dev/null || echo "UNREACHABLE"
done

# Proxmox version / health (shop)
ssh pve 'pveversion -v | head -5'
ssh pve 'pvesm status'
```

---

## Open Loop

This SSOT previously used a single umbrella loop (`OL_SHOP_BASELINE_FINISH`) for unfinished physical audits.
That umbrella loop is now **closed (2026-02-10)** and remaining work is tracked as explicit loops to prevent drift.

| Loop ID | Meaning |
|--------|---------|
| `LOOP-MD1400-SAS-RECOVERY-20260208` | MD1400 storage still dark; PM8072 init fails even after cold boot (replacement/reflash path). |
| `LOOP-SHOP-EDGE-CREDS-AND-INVENTORY-20260210` | Seed missing shop device creds in Infisical + capture service tags/serials (N2024P, iDRAC, NVR, UniFi/UDR). |

**VERIFIED REMOTELY (2026-02-08):**
- R730XD: 12x 3.5" LFF front + 2x 2.5" rear flex (from dmesg enclosure slots 0-11)
- R730XD HBA: Dell HBA330 Mini (LSI SAS3008, IT mode, FW 16.00.11.00)
- R730XD RAM: 12x 16GB DIMMs (192GB), 12/24 slots populated
- R730XD NICs: 4x 1GbE, only eno1 active
- Tank drive serials: Z1Z86298, Z1Z85V4W, Z1Z84YNR, Z1Z85V47, Z1Z862H5, Z1Z8629N, Z1Z85TFE, Z1Z861ZN
- PM8072 second SAS controller present but no driver/no drives visible
- NVR: Hikvision ERI-K216-P16 on Gi1/0/4 (see [CAMERA_SSOT.md](CAMERA_SSOT.md) for channel details)
- Switch: Dell N2024P at 192.168.1.2 (L2 only, UDR6 is gateway at .1)
- Tailscale subnet routing: pve advertises 192.168.1.0/24 (ip_forward persisted)

**BLOCKED (requires hardware fix — LOOP-MD1400-SAS-RECOVERY-20260208):**
- MD1400 DAS: Drive population, models, serials, health — cable connected, shelf powered, but PM8072 init still fails even after on-site cold boot (GAP-OP-037). Proceed with controller replace/reflash path.

**VERIFIED REMOTELY (2026-02-10) — WiFi AP (EAP225):**
- SSH connected via `pve` jump host, `network.ap.facts.capture` capability PASS.
- Receipt: `CAP-20260210-150242__network.ap.facts.capture__Rxy4z41187`
- Fixes applied: Infisical `AP_SSH_PASSWORD` corrected (was username "Production", now correct password); `ssh.targets.yaml` username case fixed (`Production`); SSH host key algo (`ssh-rsa`) added for dropbear compat; script hardened for restricted busybox shell (no `/dev/null` writes).
- Facts: kernel 3.3.8, MAC 54:af:97:2f:c6:6e, IP 192.168.1.185, SSIDs: "Production" (5GHz/ath10), "Production 2.5" (2.4GHz/ath0), mesh backhaul (bkhap1).

**Camera system details:** Now tracked in [CAMERA_SSOT.md](CAMERA_SSOT.md) and LOOP-CAMERA-BASELINE-20260208 (offline cameras, IP conflict, physical location audit).

---

## Evidence / Receipts

- `receipts/sessions/DELL_N2024P_FACTORY_RESET_20260205_122838/receipt.md`
- `receipts/sessions/RCAP-20260210-150242__network.ap.facts.capture__Rxy4z41187/receipt.md`

---

## Open Network Tasks (shop)

- [x] **DHCP DNS cutover**: UDR6 deployed as shop gateway (192.168.1.1). Shop LAN re-IPed to 192.168.1.0/24. DHCP→UDR6, DNS→Pi-hole (192.168.1.204). Loop: LOOP-UDR6-SHOP-CUTOVER-20260209. Gate: D52.
- [x] **vzdump backup gap**: All 10 VMs in vzdump job. Offsite sync (pve → NAS over Tailscale) wired for VMs 204-210.

---

## Related Documents

- [CAMERA_SSOT.md](CAMERA_SSOT.md)
- [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md)
- [MINILAB_SSOT.md](MINILAB_SSOT.md)
- [MACBOOK_SSOT.md](MACBOOK_SSOT.md)
- [NETWORK_RUNBOOK.md](NETWORK_RUNBOOK.md)
- [SECRETS_POLICY.md](SECRETS_POLICY.md)
- [SSOT_UPDATE_TEMPLATE.md](SSOT_UPDATE_TEMPLATE.md)
