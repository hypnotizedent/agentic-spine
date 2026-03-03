---
loop_id: LOOP-NETSEC-W1-DNS-AUTHORITY-STACK-20260303
created: 2026-03-03
status: closed
owner: "@ronny"
scope: agentic-spine
objective: Define Wave 1 DNS authority stack contracts covering Unbound recursive resolver, DoH fallback, local DNS overrides, Pi-hole drift gate, and DNS bypass prevention firewall rule.
---

# Loop Scope: NetSec W1 DNS Authority Stack

## Problem Statement

Pi-hole is deployed but forwards all queries to Cloudflare/Google — upstream providers see every resolved domain. No recursive resolver exists, no DoH privacy layer, no systematic local DNS registry, no drift gate enforces Pi-hole state, and no firewall rule prevents IoT devices from bypassing Pi-hole by hardcoding 8.8.8.8.

## Deliverables

1. Draft `ops/bindings/network.dns.authority.contract.yaml` covering:
   - Unbound recursive resolver configuration and DNSSEC validation
   - DoH fallback via cloudflared DNS proxy
   - Upstream resolver chain: Pi-hole → Unbound → root servers (primary), Pi-hole → cloudflared DoH (fallback)
2. Draft `ops/bindings/network.dns.local.registry.yaml` skeleton with `.mint.local` naming convention:
   - `<service>.<location>.mint.local` pattern
   - Pi-hole Local DNS population contract
3. Draft DNS bypass prevention firewall rule specification for UniFi:
   - Allow LAN → Pi-hole (UDP/TCP 53)
   - Block LAN → Any → Port 53 (prevents bypass)
4. Draft Pi-hole drift gate specification (upstream DNS correct, DNSSEC valid, blocklist policy).
5. Child gaps filed and linked for all missing artifacts.

## Acceptance Criteria

1. Unbound configuration is explicit with DNSSEC, caching, and privacy settings.
2. DoH fallback is scoped as degraded-mode only (primary path is Unbound).
3. Local DNS naming convention is deterministic and aligned with existing ssh.targets.yaml host IDs.
4. Firewall bypass prevention rule is testable (IoT VLAN cannot resolve via external DNS).
5. All missing artifacts are represented by child gaps.

## Constraints

1. Design-only; no runtime capability, plugin, or drift-gate implementation.
2. No changes to live Pi-hole or UDR configuration.
3. Unbound and cloudflared deployment specs are design artifacts only.

## Gaps

1. `GAP-OP-1449` — No Unbound recursive DNS resolver deployed.
2. `GAP-OP-1450` — No DNS-over-HTTPS (DoH) privacy proxy.
3. `GAP-OP-1451` — No .mint.local naming convention or local DNS registry.
4. `GAP-OP-1452` — No DNS bypass prevention firewall rule.
5. `GAP-OP-1453` — No Pi-hole drift gate.
