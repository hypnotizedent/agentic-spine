# LOOP-UDR6-SHOP-CUTOVER-20260209

> **Status:** CLOSING (cutover complete, device re-IP deferred)
> **Owner:** @ronny
> **Created:** 2026-02-09
> **Severity:** medium
> **Origin:** GAP-OP-064 (no shop gateway, T-Mobile locked)
> **Gate:** D52 (UDR6 gateway assertion)

---

## Executive Summary

T-Mobile 5G Home Internet at the shop is fully locked down (no DHCP/DNS config, no bridge mode). The shop LAN (192.168.12.0/24) is flat with T-Mobile owning DHCP and DNS. This blocks Pi-hole DNS, VLAN segmentation, and proper network management.

A UniFi UDR6 (previously at home, replaced by UDR7) will be inserted between T-Mobile and the Dell N2024P switch. Shop LAN re-IPs to 192.168.1.0/24 with UDR6 owning DHCP and DNS pointing to Pi-hole.

Double-NAT topology is acceptable since all public access uses Cloudflare tunnels.

---

## Phases

| Phase | Description | Status |
|-------|-------------|--------|
| P0 | Audit (topology, devices, IPs, gaps) | **DONE** |
| P1 | Pre-stage: SSOT docs, governance, runbook | **DONE** |
| P1.5 | SSH pre-staging: netplan, PVE interfaces, PM8072 | **DONE** |
| P1.6 | Remote config apply: netplan, exports, fstab, TS route | **DONE** |
| P2 | Physical cutover: cable swap, cold boot | **DONE** (device re-IP pending) |
| P3 | Verification: connectivity, NFS, services, DNS | **DONE** (core verified) |
| P4 | Post-cutover: finalize docs, close gaps | PENDING |

---

## P1: Pre-Stage (DONE — 2026-02-09)

| Item | File | Status |
|------|------|--------|
| DEVICE_IDENTITY_SSOT.md | Updated: subnet, LAN endpoints, VM IPs, quick ref | **DONE** |
| SHOP_SERVER_SSOT.md | Updated: topology, subnet, switch ports, NFS exports, DHCP task | **DONE** |
| NETWORK_POLICIES.md | Updated: NET-02/03/04/06 | **DONE** |
| CAMERA_SSOT.md | Updated: NVR IP references | **DONE** |
| infra.relocation.plan.yaml | Updated: CIDR entries | **DONE** |
| operational.gaps.yaml | Added: GAP-OP-064 | **DONE** |
| D52 drift gate | Created: d52-udr6-gateway-assertion.sh | **DONE** |
| NETWORK_RUNBOOK.md | Created: reusable network change procedures | **DONE** |
| Loop registered | open_loops.jsonl entry | **DONE** |
| Memory files updated | MEMORY.md, infrastructure-details.md, governance-details.md | **DONE** |
| pihole staged config | Updated FTLCONF_LOCAL_IPV4 to 192.168.1.204 | **DONE** |
| DR_RUNBOOK.md | Updated iDRAC IP | **DONE** |
| SHOP_VM_ARCHITECTURE.md | Updated NFS LAN IPs | **DONE** |

---

## P2: Physical Cutover (PENDING)

### Pre-Cutover (remote, via Tailscale)
1. Factory reset UDR6, adopt in UniFi app, configure: LAN 192.168.1.0/24, DHCP .100-.199, DNS→192.168.1.204
2. Unmount NFS on all VMs (`umount -l`)
3. Apply VM netplan changes (SSH via Tailscale)
4. Apply PVE `/etc/network/interfaces` change
5. Update NFS `/etc/exports` on pve
6. Update Tailscale subnet route: `tailscale set --advertise-routes=192.168.1.0/24`
7. Stage PM8072 modprobe config for MD1400 (LOOP-MD1400-SAS-RECOVERY combined)

### On-Site
8. Cable swap: T-Mobile→UDR6 WAN, UDR6 LAN→Switch Gi1/0/1
9. Cold power-cycle PVE (hold power 10s, power on)
10. Re-IP: switch (192.168.1.2), iDRAC (192.168.1.250), NVR (192.168.1.216)
11. Remount NFS on VMs

---

## P3: Verification Checklist

See NETWORK_RUNBOOK.md and full plan for detailed verification matrix covering:
- Network connectivity (pve, VMs, internet, UDR6)
- VM reachability (all via Tailscale)
- NFS mounts (from 192.168.1.184)
- Services (docker ps, CF tunnel, Pi-hole DNS)
- LAN-only devices (switch, iDRAC, NVR)
- MD1400 (if combined cold boot)

---

## Blocks / Unblocks

| Item | Direction | What |
|------|-----------|------|
| NET-02 | UNBLOCKS | Shop subnet allocation finalized |
| NET-03 | UNBLOCKS | DNS strategy implemented (UDR DHCP→Pi-hole) |
| NET-06 | PARTIALLY UNBLOCKS | UDR6 deployed, VLANs now possible (future phase) |
| LOOP-MD1400-SAS-RECOVERY-20260208 | COMBINES | Same cold boot opportunity |

---

## Risk Mitigations

| Risk | Mitigation |
|------|------------|
| NFS D-state | Unmount ALL NFS before IP change |
| VMs unreachable | Tailscale overlay survives subnet change |
| CF tunnel drop | Auto-reconnects ~30s |
| Switch unreachable | Works as L2 without mgmt IP; re-IP later |
| Rollback | Keep T-Mobile cable available; revert all configs |
| Pi-hole not ready | UDR fallback DNS: 1.1.1.1 / 8.8.8.8 |

---

## IP Map

| Device | Old IP | New IP |
|--------|--------|--------|
| UDR6 (new) | — | 192.168.1.1 |
| pve (vmbr0) | 192.168.12.184 | 192.168.1.184 |
| docker-host | 192.168.12.190 | 192.168.1.190 |
| infra-core | 192.168.12.204 | 192.168.1.204 |
| observability | 192.168.12.205 | 192.168.1.205 |
| dev-tools | 192.168.12.206 | 192.168.1.206 |
| download-stack | 192.168.12.209 | 192.168.1.209 |
| streaming-stack | 192.168.12.210 | 192.168.1.210 |
| switch | 192.168.12.2 | 192.168.1.2 |
| iDRAC | 192.168.12.250 | 192.168.1.250 |
| NVR | 192.168.12.216 | 192.168.1.216 |
| AP | 192.168.12.249 | 192.168.1.249 |
