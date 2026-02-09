---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-09
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

| Site | Subnet | Gateway | DHCP | DNS |
|------|--------|---------|------|-----|
| Shop | 192.168.1.0/24 | 192.168.1.1 (UDR6) | UDR6 (.100-.199) | Pi-hole (192.168.1.128) |
| Home | 10.0.0.0/24 | 10.0.0.1 (UDR7) | UDR7 | Router default |
| Camera | 192.168.254.0/24 | NVR internal | NVR | N/A |

Rules for new sites:
- Avoid overlap with existing subnets.
- Use /24 minimum.
- Document in this file before provisioning.
- Register in `infra.placement.policy.yaml`.

## DNS Strategy (NET-03) — IMPLEMENTED (shop)

Current state:
- **Shop: IMPLEMENTED.** UDR6 DHCP DNS → Pi-hole on infra-core (192.168.1.128:53). All DHCP clients use Pi-hole. Static VMs configured with `nameservers: [192.168.1.128]` in netplan.
- Home: Pi-hole-home exists but DHCP DNS points to router, not pihole.

Active:
- Shop: UDR6 DHCP → Pi-hole (infra-core) as primary DNS.
- Internal naming: `<host>.tail` via Tailscale MagicDNS (already active).
- External naming: `*.ronny.works` via Cloudflare (already active).

Remaining:
- Home: Router DHCP → pihole-home as primary DNS (not yet configured).

## Network Segmentation (NET-06)

Current state: Flat LAN at both sites. Camera network is isolated (NVR internal 192.168.254.0/24).
IoT devices (Zigbee/Z-Wave via HA) are on the same LAN as infrastructure.

**UDR6 deployed** — VLAN segmentation is now possible at shop. Dell N2024P supports VLANs.

Target (future phase, ~1 week soak after UDR6 stable):
- VLAN 1 (Default): Infrastructure (pve, VMs, switch) — 192.168.1.0/24
- VLAN 10: IoT (smart home devices, sensors) — 192.168.10.0/24
- VLAN 30: Cameras (replaces NVR internal 192.168.254.0/24) — 192.168.30.0/24
- VLAN 40: Guest/untrusted — 192.168.40.0/24

Requires: UDR VLAN config + N2024P VLAN trunk ports + firewall rules between VLANs.

## WAN Documentation (NET-04, INV-06)

| Site | ISP | Bandwidth (measured) | IP Type | Notes |
|------|-----|--------------------| --------|-------|
| Shop | T-Mobile 5G Home Internet | ~865 Mbps down / ~309 Mbps up | CGNAT (no public IP) | All public access via CF tunnel; double NAT behind UDR6 |
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
