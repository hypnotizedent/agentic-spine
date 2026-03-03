# PLAN-NETSEC-W1-ORDER-LOCK-20260303

> Design-only execution lock for Network Security Wave 1.
> Purpose: preserve ordered implementation intent for a future worker.
> Status: deferred planning artifact (no execution in this plan).
> Date: 2026-03-03.

## Intent Lock

This artifact locks Wave 1 sequence and dependencies so a future worker can build the engine without losing scope.

Execution order is fixed:

1. DNS authority stack first.
2. VLAN segmentation and firewall second.
3. Threat detection and observation third.
4. Stack knowledge base fourth (independent, can run parallel with 1).

No runtime plugin/capability/gate implementation is performed in this plan.

## Ordered Work Packets

### Packet 1 — DNS Authority Stack

- Loop: `LOOP-NETSEC-W1-DNS-AUTHORITY-STACK-20260303`
- Objective: deploy Unbound recursive resolver, cloudflared DoH fallback, `.mint.local` local DNS, and DNS bypass prevention firewall rule.
- Child gaps: _(filed with --id auto, linked to loop)_
- Primary outputs (design artifacts):
  - `ops/bindings/network.dns.authority.contract.yaml`
  - `ops/bindings/network.dns.local.registry.yaml`
  - `ops/bindings/network.dns.bypass.prevention.contract.yaml`
- DoD:
  - Pi-hole upstream is Unbound (127.0.0.1:5335).
  - DNSSEC validation confirmed via `dig sigfail.verteiltesysteme.net` SERVFAIL.
  - No device can resolve DNS via external servers (firewall-blocked).
  - `.mint.local` entries resolve for all SSH targets.

### Packet 2 — VLAN Segmentation and Firewall

- Loop: `LOOP-NETSEC-W1-VLAN-SEGMENTATION-FIREWALL-20260303`
- Depends on: Packet 1 complete (DNS bypass rule references VLAN-aware Pi-hole IPs).
- Objective: create 6 VLANs, inter-VLAN firewall rules, mDNS governance, switch port mapping.
- Absorbs: GAP-OP-1030 (flat home network), GAP-OP-1108 (switch normalization).
- Primary outputs:
  - `ops/bindings/network.vlan.topology.contract.yaml`
  - `ops/bindings/network.firewall.baseline.contract.yaml`
  - `ops/bindings/network.mdns.governance.contract.yaml`
  - Updated `ops/bindings/home.unifi.network.inventory.yaml`
- DoD:
  - 6 VLANs active on UDR7 with correct subnets.
  - IoT VLAN cannot ping Management or Servers VLAN.
  - Guest VLAN has internet-only access.
  - mDNS AirPlay/Cast works across Trusted↔IoT.

### Packet 3 — Threat Detection and Observation

- Loop: `LOOP-NETSEC-W1-THREAT-DETECTION-OBSERVATION-20260303`
- Depends on: Packet 2 complete (DMZ VLAN 50 required for Cowrie).
- Objective: tune IDS/IPS, deploy CrowdSec with bouncers, deploy Cowrie honeypot on DMZ.
- Primary outputs:
  - `ops/bindings/network.ids.tuning.contract.yaml`
  - `ops/bindings/network.crowdsec.contract.yaml`
  - `ops/bindings/network.honeypot.contract.yaml`
- DoD:
  - Suricata rules curated and suppress list active.
  - CrowdSec agent reporting to console, Cloudflare bouncer active.
  - Cowrie on DMZ VLAN, isolated from RFC1918.
  - Cowrie logs visible in Grafana with geo-IP.

### Packet 4 — Stack Knowledge Base

- Loop: `LOOP-NETSEC-W1-STACK-KNOWLEDGE-BASE-20260303`
- Depends on: None (independent, can run parallel with any packet).
- Objective: build self-healing, agent-queryable index of self-hosted tools and catalogs.
- Primary outputs:
  - `ops/bindings/stack.discovery.sources.yaml`
  - `ops/bindings/stack.discovery.contract.yaml`
- DoD:
  - 5+ sources indexed and queryable.
  - Refresh runs daily with logged evidence.
  - Agent can query "what tools exist for X?" and get ranked results.

## Worker Build Rules

1. No live network changes without operator approval at each wave boundary.
2. DNS authority changes must be tested with `dig` before committing to DHCP.
3. VLAN changes require home site physical access (UDR7 is offsite).
4. IDS mode changes (IDS → IPS) require 48-hour soak observation first.
5. All Wave 1 outputs are design-only until explicit implementation promotion.

## Execution Freeze Statement

This plan intentionally does not start implementation. It preserves sequence, dependencies, and acceptance criteria for a future worker execution wave.

## Activation Outline (Future Worker)

1. Promote Packet 1 loop to `active` and resolve linked gaps.
2. Promote Packet 2 loop only after Packet 1 closeout receipt (and home visit scheduled).
3. Promote Packet 3 loop only after Packet 2 closeout receipt.
4. Promote Packet 4 loop at any time (independent).
5. Run `./bin/ops cap run verify.run -- fast` after each packet closeout.
