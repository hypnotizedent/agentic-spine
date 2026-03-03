---
loop_id: LOOP-NETSEC-W1-THREAT-DETECTION-OBSERVATION-20260303
created: 2026-03-03
status: closed
owner: "@ronny"
scope: agentic-spine
objective: Define Wave 1 threat detection and observation contracts covering IDS/IPS tuning (Suricata), CrowdSec collaborative threat intelligence, and Cowrie honeypot on DMZ VLAN.
---

# Loop Scope: NetSec W1 Threat Detection and Observation

## Problem Statement

UniFi Threat Management (Suricata) is enabled at default settings — high noise, no tuned rule sets, no suppress list. No collaborative threat intelligence layer exists (CrowdSec). No attacker observation capability exists (honeypot). Without these, the network relies entirely on perimeter controls (Cloudflare tunnels + Tailscale) with zero internal threat visibility.

## Deliverables

1. Draft `ops/bindings/network.ids.tuning.contract.yaml` covering:
   - Suricata rule categories: enable (MALWARE, SCAN, DROP, EXPLOIT, DNS Tunneling) vs disable (P2P, Ad Networks)
   - 48-hour IDS-only soak period before IPS enforcement
   - False positive suppress list (ISP NTP, Tailscale control plane, UniFi cloud, DoH)
   - Sensitivity tuning baseline (Medium start)
2. Draft `ops/bindings/network.crowdsec.contract.yaml` covering:
   - Agent deployment target (docker-host or dedicated VM)
   - Collections: nginx, linux, ssh-bf, cowrie
   - Bouncer strategy: Cloudflare bouncer (edge blocking) + firewall bouncer (local iptables)
   - Dashboard integration: CrowdSec console or Grafana
3. Draft `ops/bindings/network.honeypot.contract.yaml` covering:
   - Cowrie SSH/Telnet emulation on DMZ VLAN (VLAN 50) IP
   - Docker deployment with bind to DMZ IP only
   - Mandatory firewall isolation: DMZ → all RFC1918 blocked
   - Log pipeline: Cowrie JSON → Promtail → Loki → Grafana (geo-IP dashboard)
   - CrowdSec integration: cowrie.json as acquis source
4. Draft threat detection drift gate specification (CrowdSec agent alive, Suricata rules active).
5. Child gaps filed and linked for all missing artifacts.

## Acceptance Criteria

1. IDS rule set is curated with explicit enable/disable rationale per category.
2. CrowdSec architecture is concrete: agent location, bouncer type, collection set.
3. Cowrie is isolated on DMZ VLAN with explicit firewall dependency on VLAN Segmentation packet.
4. Log pipeline connects threat data to existing observability stack (Loki/Grafana on VM 205).
5. All missing artifacts are represented by child gaps.

## Constraints

1. Design-only; no CrowdSec install, Suricata reconfiguration, or Cowrie deployment.
2. Cowrie deployment depends on VLAN Segmentation packet (DMZ VLAN 50 must exist first).
3. No changes to existing Cloudflare tunnel or Tailscale ACL configurations.

## Dependencies

1. `LOOP-NETSEC-W1-VLAN-SEGMENTATION-FIREWALL-20260303` — DMZ VLAN required for Cowrie.

## Gaps

1. `GAP-OP-1457` — No IDS/IPS tuning contract.
2. `GAP-OP-1458` — No CrowdSec deployment or contract.
3. `GAP-OP-1459` — No honeypot capability.
