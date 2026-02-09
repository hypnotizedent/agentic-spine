# Receipt: ADHOC_20260209_160037_UDR6_CUTOVER_P2

| Field | Value |
|-------|-------|
| Run ID | `ADHOC_20260209_160037_UDR6_CUTOVER_P2` |
| Capability | `adhoc.receipt` |
| Status | done |
| Exit Code | 0 |
| Generated | 2026-02-09T16:00:50Z |
| Model | manual (adhoc receipt) |
| Context | mutating |

## Inputs

| Field | Value |
|-------|-------|
| Command | `qm guest exec (multi-VM staged config apply)` |
| Repo | `/Users/ronnyworks/code/agentic-spine` |

## Outputs

| File | Hash |
|------|------|
| output.txt | (empty) |

---

# Receipt — UDR6 Shop Cutover P2 — Remote Config Apply

| Stamp | Value |
|-------|-------|
| timestamp_utc | 2026-02-09T16:00:50Z |
| run_id | ADHOC_20260209_160037_UDR6_CUTOVER_P2 |
| command | `qm guest exec (multi-VM staged config apply)` |
| exit_status | 0 (all steps passed) |
| repo_sha | 8bf0f58415e9457711c9c930cf66ecff916b8c3a |
| tree_sha | 4ec60d024bd4825ee495eaa5c42bdafb9527611d |
| loop | LOOP-UDR6-SHOP-CUTOVER-20260209 |
| phase | P2 (remote pre-apply) |

---

## Operations Log


### Step 1: Unmount NFS (D-state prevention)

| VM | Mount Points | Result |
|----|-------------|--------|
| 200 (docker-host) | none active | SKIP |
| 209 (download-stack) | /mnt/docker, /mnt/media | `umount -l` OK, verified NO_NFS |
| 210 (streaming-stack) | /mnt/docker, /mnt/media | `umount -l` OK, verified NO_NFS |


### Step 2: Apply Staged Netplan (VM re-IP)

All VMs applied via `qm guest exec <vmid> -- bash -c 'cp .staged -> live && netplan apply'`
NIC: `eth0` (altname `enp0s18`)

| VM | Old IP | New IP (eth0) | Tailscale | Result |
|----|--------|---------------|-----------|--------|
| 204 (infra-core) | 192.168.12.128 | 192.168.1.204/24 | 100.92.91.128 | OK |
| 205 (observability) | 192.168.12.70 | 192.168.1.205/24 | 100.120.163.70 | OK |
| 206 (dev-tools) | 192.168.12.39 | 192.168.1.206/24 | 100.90.167.39 | OK |
| 209 (download-stack) | 192.168.12.76 | 192.168.1.209/24 | 100.107.36.76 | OK |
| 210 (streaming-stack) | 192.168.12.64 | 192.168.1.210/24 | 100.123.207.64 | OK |


### Step 3: Apply PVE Network + NFS Exports

**`/etc/network/interfaces`**: Copied from `.staged`. vmbr0 → 192.168.1.184/24, gw 192.168.1.1. Takes effect after reboot.

**`/etc/exports`**: Copied from `.staged`, `exportfs -ra` applied.
- Warning: `/mnt/easystore/backups` — stale path (pre-existing, non-blocking)
- Active exports verified via `exportfs -v`:
  - 192.168.1.209: /tank/docker/download-stack (rw), /media (rw)
  - 192.168.1.210: /tank/docker/streaming-stack (rw), /media (ro)
  - 192.168.1.0/24: /tank/docker, /tank/backups, /tank/vms (rw)


### Step 4: Apply Staged fstab (NFS client configs)

| VM | NFS mounts (new server IP) | Result |
|----|---------------------------|--------|
| 200 (docker-host) | 192.168.1.184:/tank/docker, /tank/backups | OK |
| 209 (download-stack) | 192.168.1.184:/tank/docker/download-stack, /media (rw) | OK |
| 210 (streaming-stack) | 192.168.1.184:/tank/docker/streaming-stack, /media (ro) | OK |

All using `x-systemd.requires=network-online.target` (safe mount ordering).


### Step 5: Tailscale Subnet Route Update

- Old route: `192.168.12.0/24` (removed)
- New route: `192.168.1.0/24` (advertised, **pending admin approval**)
- `tailscale debug prefs` confirms `AdvertiseRoutes: ["192.168.1.0/24"]`
- **ACTION REQUIRED**: Approve `192.168.1.0/24` in Tailscale admin console → pve node → Edit route settings


---

## Summary

All remote P2 operations completed successfully. The VMs and PVE host are now configured for 192.168.1.0/24 but the physical cable swap and PVE reboot have not happened yet.

### Applied
- [x] NFS unmounted on VMs 209, 210 (VM 200 had none)
- [x] Netplan applied: 5 VMs re-IPed to VMID-based 192.168.1.X
- [x] PVE /etc/network/interfaces updated (takes effect on reboot)
- [x] PVE /etc/exports updated + exportfs -ra (active, new IPs)
- [x] VM fstab updated: 200, 209, 210 pointing to 192.168.1.184
- [x] Tailscale advertise-routes set to 192.168.1.0/24
- [x] PM8072 modprobe + initramfs (applied in prior session)

### Pending (on-site + manual)
- [ ] Approve 192.168.1.0/24 route in Tailscale admin console
- [ ] Physical cable swap: T-Mobile → UDR6 WAN, UDR6 LAN → Switch
- [ ] Cold power-cycle PVE (applies /etc/network/interfaces + MD1400 init)
- [ ] Re-IP: switch (192.168.1.2), iDRAC (192.168.1.250), NVR (192.168.1.216)
- [ ] Remount NFS: `mount -a` on VMs 200/209/210
- [ ] Run full P3 verification checklist


| completed_utc | 2026-02-09T16:04:04Z |

---
_Receipt written by claude-opus (LOOP-UDR6-SHOP-CUTOVER-20260209)_

### Step 6: Cold Boot PVE + P3 Verification

**PVE cold boot** (manual power cycle by operator): came up at 192.168.1.184, gateway 192.168.1.1 (UDR6).

**VM Status (all 10 running):**

| VM | LAN IP | Docker | NFS | Status |
|----|--------|--------|-----|--------|
| 204 (infra-core) | 192.168.1.204 | 11/11 up | n/a | OK |
| 205 (observability) | 192.168.1.205 | up | n/a | OK |
| 206 (dev-tools) | 192.168.1.206 | up | n/a | OK |
| 209 (download-stack) | 192.168.1.209 | 19+ up | mounted (192.168.1.184) | OK |
| 210 (streaming-stack) | 192.168.1.210 | 10/10 up | mounted (192.168.1.184, ro) | OK |

**Service Verification:**
- CF tunnel: 4 connections (mia02/mia05), registered OK
- Pi-hole DNS: resolving via 192.168.1.204
- Gitea (git.ronny.works): pass (cache + db healthy)
- Internet: 8.8.8.8 reachable from PVE (71ms via UDR6→T-Mobile)

**PM8072 note:** `pm80xx: unknown parameter 'new_id' ignored` — wrong modprobe syntax, non-blocking (MD1400 is separate loop)

**Remaining P2 tasks (LAN-only devices, manual):**
- [ ] Re-IP switch: 192.168.1.2
- [ ] Re-IP iDRAC: 192.168.1.250
- [ ] Re-IP NVR: 192.168.1.216


### Step 7: Device Re-IP (iDRAC, NVR, Switch)

Added temporary 192.168.12.184/24 to PVE vmbr0 to reach old-subnet devices.

**iDRAC (192.168.12.250):**
- Pings OK but all TCP ports closed — BMC still initializing after cold boot (normal, 10-15 min)
- Temporary IP removed from PVE

**Deferred commands** (run when iDRAC web server is ready):

```bash
# iDRAC — via Redfish API from PVE
curl -sk -u root:calvin -X PATCH \
  'https://192.168.12.250/redfish/v1/Managers/iDRAC.Embedded.1/EthernetInterfaces/NIC.1' \
  -H 'Content-Type: application/json' \
  -d '{"IPv4Addresses":[{"Address":"192.168.1.250","SubnetMask":"255.255.255.0","Gateway":"192.168.1.1"}]}'

# Or via ipmitool (install first: apt install ipmitool)
ipmitool -I lanplus -H 192.168.12.250 -U root -P <pass> lan set 1 ipaddr 192.168.1.250
ipmitool -I lanplus -H 192.168.12.250 -U root -P <pass> lan set 1 netmask 255.255.255.0
ipmitool -I lanplus -H 192.168.12.250 -U root -P <pass> lan set 1 defgw ipaddr 192.168.1.1

# NVR — via ISAPI from PVE (add temp IP first: ip addr add 192.168.12.184/24 dev vmbr0)
curl --digest -u admin:<pass> -X PUT \
  'http://192.168.12.216/ISAPI/System/Network/interfaces/1/ipAddress' \
  -d '<IPAddress><ipVersion>v4</ipVersion><addressingType>static</addressingType><ipAddress>192.168.1.216</ipAddress><subnetMask>255.255.255.0</subnetMask><DefaultGateway><ipAddress>192.168.1.1</ipAddress></DefaultGateway></IPAddress>'

# Switch (Dell N2024P) — via console cable or web UI at 192.168.12.2
# Management IP: 192.168.1.2/24, gateway 192.168.1.1
```

| Device | Old IP | Target IP | Status |
|--------|--------|-----------|--------|
| iDRAC | 192.168.12.250 | 192.168.1.250 | DEFERRED (BMC initializing) |
| NVR | 192.168.12.216 | 192.168.1.216 | DEFERRED (not responding) |
| Switch | 192.168.12.2 | 192.168.1.2 | DEFERRED (console cable needed) |

