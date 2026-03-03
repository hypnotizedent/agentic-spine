---
loop_id: LOOP-NETSEC-W1-VLAN-SEGMENTATION-FIREWALL-20260303
created: 2026-03-03
status: closed
owner: "@ronny"
scope: agentic-spine
objective: Define Wave 1 VLAN segmentation topology, inter-VLAN firewall rule baseline, mDNS reflection governance, and switch port mapping contract — absorbing GAP-OP-1030 and GAP-OP-1108.
---

# Loop Scope: NetSec W1 VLAN Segmentation and Firewall

## Problem Statement

Home network (10.0.0.0/24) is flat — infrastructure, IoT cameras, and personal devices share the same L2 segment (GAP-OP-1030). Switch port assignments, PoE budgets, and VLAN trunking are undocumented (GAP-OP-1108). No inter-VLAN firewall rule baseline exists. mDNS does not cross VLAN boundaries, breaking AirPlay/Chromecast/HomeKit discovery.

## Deliverables

1. Draft `ops/bindings/network.vlan.topology.contract.yaml` covering:
   - 6-VLAN design: Management (1), Servers (10), Trusted (20), IoT (30), Guest (40), DMZ (50)
   - Subnet assignments, Pi-hole IP per VLAN, DHCP scope
   - Device-to-VLAN mapping policy
2. Draft `ops/bindings/network.firewall.baseline.contract.yaml` covering:
   - Inter-VLAN rule order (stateful → DNS allow → management → RFC1918 block → WAN allow)
   - Per-VLAN deny rules (IoT→Management, Guest→RFC1918, DMZ→RFC1918)
   - DNS bypass prevention integration (from DNS Authority packet)
3. Draft `ops/bindings/network.mdns.governance.contract.yaml` covering:
   - mDNS reflection pairs (Trusted↔IoT for AirPlay/Cast)
   - Security note on partial isolation defeat
   - Escalation path to Avahi Docker if built-in insufficient
4. Draft switch port mapping addendum for `home.unifi.network.inventory.yaml`:
   - Port-to-VLAN assignments, PoE budget, trunking config
5. Child gaps filed and linked for all missing artifacts.

## Acceptance Criteria

1. VLAN topology is explicit with subnets, purpose, and Pi-hole binding per VLAN.
2. Firewall rules follow top-down evaluation with RFC1918 block before WAN allow.
3. mDNS reflection is intentional and documented (not blanket enable).
4. GAP-OP-1030 and GAP-OP-1108 are absorbed into this loop's scope.
5. All missing artifacts are represented by child gaps.

## Constraints

1. Design-only; no VLAN creation, firewall rule application, or switch reconfiguration.
2. Home site VLAN implementation is blocked on physical visit (LOOP-HOME-CANONICAL-REALIGNMENT-20260302).
3. No changes to existing ssh.targets.yaml IP addresses in this loop.

## Existing Gaps Absorbed

1. `GAP-OP-1030` — No VLAN segmentation on home network (open).
2. `GAP-OP-1108` — Switches and network devices not normalized (open).

## Gaps

1. `GAP-OP-1030` — No VLAN segmentation on home network (existing, absorbed).
2. `GAP-OP-1108` — Switches and network devices not normalized (existing, absorbed).
3. `GAP-OP-1454` — No VLAN topology contract.
4. `GAP-OP-1455` — No inter-VLAN firewall rule baseline contract.
5. `GAP-OP-1456` — No mDNS governance contract.
