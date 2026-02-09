# Change Pack: UDR6 Shop Cutover

> **Retrospective** — This change pack was created after the cutover completed.
> It documents what actually happened and serves as the canonical example of the
> change pack pattern introduced by GAP-OP-065.

## Change Description

| Field | Value |
|------|-------|
| Change ID | LOOP-UDR6-SHOP-CUTOVER-20260209 |
| Date | 2026-02-09 |
| Owner | @ronny |
| What | Re-IP shop LAN from 192.168.12.0/24 to 192.168.1.0/24 behind UDR6 |
| Why | T-Mobile 5G gateway is fully locked (no DHCP/DNS control, no bridge mode) |
| Downtime window | 30-60 min (physical cable swap + cold boot) |
| Rollback strategy | Revert all netplan/interfaces configs, reconnect T-Mobile cable directly to switch |

## IP Map (Old -> New)

| Device | Old IP | New IP | Config Location | Method |
|--------|--------|--------|-----------------|--------|
| UDR6 (new) | — | 192.168.1.1 | UniFi app | factory reset + adopt |
| pve (vmbr0) | 192.168.12.184 | 192.168.1.184 | /etc/network/interfaces | manual edit + reboot |
| docker-host | 192.168.12.190 | 192.168.1.200 | /etc/netplan/50-cloud-init.yaml | netplan apply |
| infra-core | 192.168.12.204 | 192.168.1.204 | /etc/netplan/50-cloud-init.yaml | netplan apply |
| observability | 192.168.12.205 | 192.168.1.205 | /etc/netplan/50-cloud-init.yaml | netplan apply |
| dev-tools | 192.168.12.206 | 192.168.1.206 | /etc/netplan/50-cloud-init.yaml | netplan apply |
| download-stack | 192.168.12.209 | 192.168.1.209 | /etc/netplan/50-cloud-init.yaml | netplan apply |
| streaming-stack | 192.168.12.210 | 192.168.1.210 | /etc/netplan/50-cloud-init.yaml | netplan apply |
| switch | 192.168.12.2 | 192.168.1.2 | switch CLI | console cable (deferred) |
| iDRAC | 192.168.12.250 | 192.168.1.250 | ipmitool | IPMI from pve (deferred) |
| NVR | 192.168.12.216 | 192.168.1.216 | ISAPI | curl from pve (deferred) |
| AP | 192.168.12.249 | 192.168.1.249 | web UI | DHCP reservation (deferred) |

## Rollback Map

| Device | Revert IP | Config File | Revert Command |
|--------|-----------|-------------|----------------|
| pve | 192.168.12.184 | /etc/network/interfaces | restore .bak, reboot |
| docker-host | 192.168.12.190 | /etc/netplan/50-cloud-init.yaml | netplan apply |
| infra-core | 192.168.12.204 | /etc/netplan/50-cloud-init.yaml | netplan apply |
| observability | 192.168.12.205 | /etc/netplan/50-cloud-init.yaml | netplan apply |
| dev-tools | 192.168.12.206 | /etc/netplan/50-cloud-init.yaml | netplan apply |
| download-stack | 192.168.12.209 | /etc/netplan/50-cloud-init.yaml | netplan apply |
| streaming-stack | 192.168.12.210 | /etc/netplan/50-cloud-init.yaml | netplan apply |
| NFS exports | 192.168.12.0/24 | /etc/exports on pve | restore .bak, exportfs -ra |
| Tailscale route | 192.168.12.0/24 | N/A | tailscale set --advertise-routes=192.168.12.0/24 |

## Pre-Cutover Verification Matrix

> Retrospective note: No formal preflight receipts were taken before P2.
> This is the gap that GAP-OP-065 addresses.

- [x] `spine.verify` — PASS (receipt: RCAP-20260209-115817__spine.verify__Rn3im33981)
- [x] `ssh.target.status` — PASS for shop targets (home-only timeouts pre-existing)
- [x] `docker.compose.status` — PASS (media-stack VM 201 decommissioning, pre-existing)
- [x] `services.health.status` — PASS (tdarr refused, spotisub 302, pre-existing)
- [ ] `network.cutover.preflight` — DID NOT EXIST at time of cutover

Known acceptable pre-existing failures:
- pihole-home: connect_timeout (home location, Tailscale flaky)
- download-home: connect_timeout (home location, Tailscale flaky)
- media-stack (VM 201): decommissioning per LOOP-MEDIA-STACK-SPLIT-20260208

## Cutover Sequence

Actual execution order (matched retrospectively to cutover.sequencing.yaml):

| Step | Phase | Action | Actual |
|------|-------|--------|--------|
| 1 | Remote management | Tailscale stable to all shop targets | DONE — SSH via Tailscale verified |
| 2 | Hypervisor | PVE /etc/network/interfaces applied, cold boot | DONE — vmbr0 on 192.168.1.184 |
| 3 | Switch | Re-IP switch management | DEFERRED — still on 192.168.12.2, works as L2 |
| 4 | LAN-only devices | iDRAC re-IP via IPMI | PARTIAL — IPMI command accepted but ARP failed |
| 4 | LAN-only devices | NVR re-IP | DEFERRED — needs on-site |
| 5 | Workloads | NFS remount, Docker restart | DONE — all stacks verified |

### Execution Steps (Actual)

| Step | What | Where | Command | Verify | Result |
|------|------|-------|---------|--------|--------|
| 1 | Unmount NFS | all VMs | `sudo umount -l /media /opt/appdata` | `findmnt -t nfs` empty | DONE |
| 2 | Apply VM netplan | all VMs | `sudo netplan apply` via Tailscale SSH | ip addr shows new IP | DONE |
| 3 | Apply PVE interfaces | pve | edit /etc/network/interfaces, reboot | vmbr0 on .184 | DONE |
| 4 | Update NFS exports | pve | edit /etc/exports, `exportfs -ra` | `exportfs -v` | DONE |
| 5 | Update TS route | pve | `tailscale set --advertise-routes=192.168.1.0/24` | `tailscale status` | DONE |
| 6 | Cable swap | on-site | T-Mobile→UDR6 WAN, UDR6 LAN→switch Gi1/0/1 | ping 192.168.1.1 | DONE |
| 7 | Cold boot PVE | on-site | hold power 10s, power on | SSH via Tailscale | DONE |
| 8 | Remount NFS | all VMs | `sudo mount -a` | `findmnt -t nfs` | DONE |
| 9 | docker-host re-IP | docker-host | netplan static .200 | ip addr | DONE (P3 fix) |
| 10 | infra-core DNS fix | infra-core | `tailscale set --accept-dns=false` | dig resolves | DONE (P3 fix) |
| 11 | CF tunnel fix | infra-core | fix extra_hosts grafana→observability TS IP | curl grafana.ronny.works | DONE (P3 fix) |

## LAN-Only Devices (On-Site Section)

| Device | On-site required? | Re-IP procedure | Result |
|--------|-------------------|-----------------|--------|
| switch | yes (console cable) | CLI: `ip address 192.168.1.2 255.255.255.0` | DEFERRED — works as L2 unmanaged |
| iDRAC | no (IPMI from pve) | `ipmitool lan set 1 ipaddr 192.168.1.250` | PARTIAL — BMC needs cold reset |
| NVR | no (ISAPI from pve) | `curl --digest -X PUT .../ISAPI/System/Network/...` | DEFERRED — needs on-site |

## Post-Cutover Verification Matrix

| Check | Command | Expected | Status |
|-------|---------|----------|--------|
| Gateway reachable | `ping -c1 192.168.1.1` | OK | [x] |
| PVE vmbr0 IP | `ssh pve "ip -4 addr show vmbr0"` | 192.168.1.184 | [x] |
| VM LAN IPs | `ssh <vm> "ip -4 addr"` | VMID-based .2XX | [x] |
| NFS mounts | `ssh <vm> "findmnt -t nfs,nfs4"` | 192.168.1.184:/ | [x] |
| CF endpoints | `curl -I https://n8n.ronny.works` | 200 | [x] |
| CF endpoints | `curl -I https://grafana.ronny.works` | 200 | [x] (after tunnel fix) |
| Pi-hole DNS | `dig @192.168.1.204 example.com A` | NOERROR | [x] |
| LAN-only: switch | `ping -c1 192.168.1.2` from pve | OK | [ ] DEFERRED |
| LAN-only: iDRAC | `ping -c1 192.168.1.250` from pve | OK | [ ] DEFERRED (ARP failed) |
| LAN-only: NVR | `ping -c1 192.168.1.216` from pve | OK | [ ] DEFERRED |

## Deferred Items

| Item | Why Deferred | Follow-up Loop |
|------|-------------|----------------|
| switch re-IP to .2 | Needs console cable on-site, works as L2 unmanaged | on-site visit |
| iDRAC re-IP to .250 | IPMI accepted but ARP failed, needs BMC cold reset | on-site visit |
| NVR re-IP to .216 | Needs on-site ISAPI or web UI access | on-site visit |
| AP re-IP to .249 | May auto-accept via DHCP reservation | on-site visit |

## Documentation Sweep

- [x] `docs/governance/DEVICE_IDENTITY_SSOT.md` -- subnet table, LAN endpoints, VM LAN IPs
- [x] `docs/governance/SHOP_SERVER_SSOT.md` -- network section, switch ports, NFS exports
- [x] `docs/governance/NETWORK_POLICIES.md` -- subnet allocation, DNS strategy
- [x] `docs/governance/CAMERA_SSOT.md` -- NVR IP references
- [x] `ops/bindings/infra.relocation.plan.yaml` -- CIDR entries
- [x] `ops/bindings/operational.gaps.yaml` -- GAP-OP-064 fixed
- [x] Memory files -- MEMORY.md and infrastructure-details.md updated

## Sign-Off

| Milestone | Timestamp | Receipt/Evidence |
|-----------|-----------|------------------|
| Preflight PASS | 2026-02-09 ~11:58 | RCAP-20260209-115817__spine.verify__Rn3im33981 (partial — no formal preflight) |
| P2 cutover complete | 2026-02-09 ~16:00 | ADHOC_20260209_160037_UDR6_CUTOVER_P2 |
| P3 verification PASS | 2026-02-09 ~17:00 | RCAP-20260209-140518__ssh.target.status__Rfcpr59072 |
| Docs sweep complete | 2026-02-09 | commit c330608 |
| Loop closed | pending | P4 pending |
