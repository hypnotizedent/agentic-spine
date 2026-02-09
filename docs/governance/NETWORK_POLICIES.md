---
status: draft
owner: "@ronny"
last_verified: 2026-02-08
scope: network-governance
---

# Network Policies

Purpose: baseline network governance for multi-site homelab. Covers Tailscale ACLs,
subnet allocation, DNS strategy, and network segmentation.

## Tailscale ACL Policy (NET-01)

Current state: No ACL policy applied. All Tailscale nodes can reach all other nodes
on all ports. Acceptable at 2 sites with single operator.

Target policy (before adding 3rd site):
- Infrastructure group: pve, proxmox-home, infra-core, observability, dev-tools
- Media group: download-stack, streaming-stack
- AI group: ai-consolidation, automation-stack
- Storage group: nas, docker-host
- Control plane: macbook (full access)
- Home group: ha, vault, pihole-home

ACL rules:
- macbook → all (operator access)
- infrastructure ↔ infrastructure (full mesh)
- media ↔ media (download↔streaming cross-talk)
- observability → all:9100 (node-exporter scrape)
- all → infra-core:8088 (Infisical API)
- all → infra-core:53 (DNS)
- deny all other cross-group traffic

- [ ] Write ACL JSON and apply via `tailscale set --acl-file`.
- [ ] Document applied ACL in spine binding.
- [ ] Add drift gate to validate ACL matches binding.

## Subnet Allocation (NET-02)

Current allocations:

| Site | Subnet | Gateway | DHCP |
|------|--------|---------|------|
| Shop | 192.168.12.0/24 | 192.168.12.1 (T-Mobile gateway) | T-Mobile gateway |
| Home | 10.0.0.0/24 | 10.0.0.1 (router) | Router |
| Camera | 192.168.254.0/24 | NVR internal | NVR |

Rules for new sites:
- Avoid overlap with existing subnets.
- Use /24 minimum.
- Document in this file before provisioning.
- Register in `infra.placement.policy.yaml`.

Planned: UDR cutover at shop will change to 10.12.1.0/24 (requires re-IP of all shop hosts).

## DNS Strategy (NET-03)

Current state:
- Shop: Pi-hole on infra-core (port 53). DHCP DNS still points to docker-host (stale).
- Home: Pi-hole-home exists but DHCP DNS points to router, not pihole.

Target:
- Shop: UDR DHCP → Pi-hole (infra-core) as primary DNS.
- Home: Router DHCP → pihole-home as primary DNS.
- Internal naming: `<host>.tail` via Tailscale MagicDNS (already active).
- External naming: `*.ronny.works` via Cloudflare (already active).

Blocked on: UDR cutover (T-Mobile gateway locked, no DHCP control).

## Network Segmentation (NET-06)

Current state: Flat LAN at both sites. Camera network is isolated (NVR internal 192.168.254.0/24).
IoT devices (Zigbee/Z-Wave via HA) are on the same LAN as infrastructure.

Target (post-UDR):
- VLAN 10: Infrastructure (pve, VMs, switches)
- VLAN 20: IoT (smart home devices, sensors)
- VLAN 30: Cameras (already partially isolated)
- VLAN 40: Guest/untrusted
- Default: User devices (MacBook, phones)

Prerequisite: UDR deployment (VLAN-capable router). Dell N2024P switch supports VLANs.

## WAN Documentation (NET-04, INV-06)

| Site | ISP | Bandwidth (approx) | IP Type | Notes |
|------|-----|--------------------| --------|-------|
| Shop | T-Mobile 5G Home Internet | ~300 Mbps down / 10-20 Mbps up | CGNAT (no public IP) | All public access via CF tunnel |
| Home | TBD | TBD | TBD | Document after verification |

Inter-site connectivity: Tailscale overlay (DERP relay when direct fails).
No site-to-site VPN beyond Tailscale.

## VPN Redundancy (NET-05)

Single points of failure:
- Tailscale coordination server (Tailscale Inc SaaS)
- Cloudflare tunnel (single connector on infra-core)

Mitigations:
- Tailscale: Direct WireGuard connections persist even if coordination server is briefly down.
- Cloudflare: Consider running a second cloudflared connector on a different VM for HA.
- [ ] Evaluate Headscale (self-hosted Tailscale control plane) for coordination independence.
- [ ] Add second cloudflared connector on observability VM as hot standby.
