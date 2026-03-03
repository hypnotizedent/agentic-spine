# PLAN-NETWORK-SECURITY-OPS-WORKER-20260303

> Coordinator specification for `LOOP-NETWORK-SECURITY-OPS-WORKER-SPEC-20260303`.
> Mode: design-only (no runtime implementation in this plan).
> Date: 2026-03-03.
> Source material: `mint-network-security-plan.docx` (9-phase rollout) + in-session network domain analysis.

## W0 Topology Baseline (Captured)

| Surface | Baseline Snapshot |
|---|---|
| Home gateway | UDR7 (10.0.0.1), UniFi Dream Router 7 |
| Shop gateway | UDR6 (192.168.1.1), UniFi Dream Router 6 |
| Home hypervisor | proxmox-home / Beelink SER7 (10.0.0.179, TS: 100.103.99.62) |
| Shop hypervisor | pve / R730XD (192.168.1.200, TS: 100.96.211.33) |
| Pi-hole (home) | LXC 105 on proxmox-home (10.0.0.53, TS: 100.105.148.96) |
| Pi-hole (shop) | VM 204 infra-core (192.168.1.204) |
| DNS upstream | Pi-hole → Cloudflare/Google (plain UDP/53, no Unbound) |
| Home network | Flat 10.0.0.0/24 — no VLANs, 46+ devices on same L2 |
| Shop network | 192.168.1.0/24 — 14 LAN-first VMs + network infra |
| IDS/IPS | UniFi Threat Management enabled, default/untuned |
| CrowdSec | Not deployed |
| Honeypot | Not deployed |
| Stack discovery | No queryable knowledge base |
| Existing network capabilities | 30+ (inventory, audit, UniFi clients, Pi-hole sync, SSH) |
| Existing network gates | D188, D194, D163, D258, D259, D262, D281, D294, D314, D321 |
| Open network gaps | GAP-OP-1030 (VLAN), GAP-OP-1108 (switch ports) |

---

## 1. Outcome Definition

Produce a governed network security hardening system that layers DNS privacy, traffic isolation, threat detection, and technology awareness on top of the existing inventory/SSH/Tailscale surfaces.

### 1A. Program Vector (What This Is Becoming)

This domain is explicitly a defense-in-depth network security system:

1. DNS authority: recursive resolution eliminating upstream provider visibility, with bypass prevention.
2. Traffic isolation: VLAN segmentation separating management, servers, trusted, IoT, guest, and DMZ traffic.
3. Threat detection: tuned IDS/IPS with collaborative threat intelligence and attacker observation.
4. Technology awareness: self-healing knowledge base for evaluating future tools and products.

### Success Profile

1. Pi-hole is truly authoritative — no device can bypass it (firewall-enforced).
2. DNS resolves recursively via Unbound — no upstream provider sees query patterns.
3. IoT devices cannot reach management or server infrastructure (VLAN isolation).
4. Intrusion attempts are detected, shared (CrowdSec), and observable (Grafana).
5. Agents can query "what self-hosted tools exist for X?" against a maintained index.

### Explicit Non-Goals

1. No OPNsense/pfSense deployment in v1 (UDR handles routing/firewall).
2. No VLAN implementation in this planning phase (blocked on home visit).
3. No live DNS changes, firewall rule application, or service deployment.
4. No full network redesign — layered hardening on existing UDR architecture.

---

## 2. Operating Model

### A. DNS Authority Worker

- Deploys and configures Unbound recursive resolver on Pi-hole host.
- Configures cloudflared as DoH fallback proxy.
- Populates Pi-hole Local DNS with `.mint.local` entries.
- Creates UniFi firewall rule blocking DNS bypass.

### B. VLAN Segmentation Worker

- Creates 6 VLANs in UniFi with subnet assignments.
- Configures inter-VLAN firewall rules with RFC1918 block baseline.
- Enables mDNS reflection for required pairs.
- Maps switch ports to VLANs with PoE budget.

### C. Threat Detection Worker

- Tunes Suricata rule categories and builds suppress list.
- Deploys CrowdSec agent with Cloudflare bouncer.
- Deploys Cowrie honeypot on DMZ VLAN.
- Connects log pipeline to observability stack.

### D. Stack Discovery Worker

- Builds source registry and fetch pipeline.
- Implements normalize → embed → index workflow.
- Creates query capability for agent use.
- Schedules refresh automation.

---

## 3. Contract Pack (Proposed Artifacts)

### 3.1 DNS Authority Contracts

| Target File | Type | Purpose |
|---|---|---|
| `ops/bindings/network.dns.authority.contract.yaml` | new (proposed) | Unbound config, DoH fallback, upstream chain, DNSSEC |
| `ops/bindings/network.dns.local.registry.yaml` | new (proposed) | `.mint.local` naming convention and Pi-hole population |
| `ops/bindings/network.dns.bypass.prevention.contract.yaml` | new (proposed) | Firewall rule spec preventing DNS bypass |

### 3.2 VLAN and Firewall Contracts

| Target File | Type | Purpose |
|---|---|---|
| `ops/bindings/network.vlan.topology.contract.yaml` | new (proposed) | 6-VLAN design, subnets, device mapping |
| `ops/bindings/network.firewall.baseline.contract.yaml` | new (proposed) | Inter-VLAN rules, RFC1918 block, deny rules |
| `ops/bindings/network.mdns.governance.contract.yaml` | new (proposed) | mDNS reflection pairs, security notes |
| `ops/bindings/home.unifi.network.inventory.yaml` | update (proposed) | Switch port mapping addendum |

### 3.3 Threat Detection Contracts

| Target File | Type | Purpose |
|---|---|---|
| `ops/bindings/network.ids.tuning.contract.yaml` | new (proposed) | Suricata rules, suppress list, soak period |
| `ops/bindings/network.crowdsec.contract.yaml` | new (proposed) | Agent, collections, bouncer strategy |
| `ops/bindings/network.honeypot.contract.yaml` | new (proposed) | Cowrie isolation, log pipeline, CrowdSec feed |

### 3.4 Stack Discovery Contracts

| Target File | Type | Purpose |
|---|---|---|
| `ops/bindings/stack.discovery.sources.yaml` | new (proposed) | External resource catalog SSOT |
| `ops/bindings/stack.discovery.contract.yaml` | new (proposed) | Pipeline contract, freshness, query interface |

### 3.5 Registry + Routing Deltas (Planned, Not Applied)

| Target File | Change |
|---|---|
| `ops/bindings/agents.registry.yaml` | add `network-security-agent` (implementation_status: planned) |
| `ops/bindings/terminal.role.contract.yaml` | add `DOMAIN-NETSEC-01` planned role |
| `ops/bindings/domain.taxonomy.bridge.contract.yaml` | add `network-security` catalog/planned-runtime mapping |

---

## 4. Capability Surface (Planned)

All names below are proposed and not implemented.

### 4.1 DNS Authority

| Capability | Safety | Approval | Purpose |
|---|---|---|---|
| `network.dns.authority.status` | read-only | auto | Verify Unbound reachable, DNSSEC valid, Pi-hole upstream correct |
| `network.dns.local.populate` | mutating | manual | Sync `.mint.local` entries to Pi-hole Local DNS |
| `network.dns.bypass.test` | read-only | auto | Verify DNS bypass prevention firewall rule is active |

### 4.2 VLAN and Firewall

| Capability | Safety | Approval | Purpose |
|---|---|---|---|
| `network.vlan.status` | read-only | auto | Report VLAN configuration parity against contract |
| `network.firewall.audit` | read-only | auto | Validate inter-VLAN rules match baseline contract |
| `network.mdns.status` | read-only | auto | Report mDNS reflection state |

### 4.3 Threat Detection

| Capability | Safety | Approval | Purpose |
|---|---|---|---|
| `network.ids.status` | read-only | auto | Report Suricata rule state, suppress list, alert summary |
| `network.crowdsec.status` | read-only | auto | Report CrowdSec agent/bouncer health |
| `network.honeypot.status` | read-only | auto | Report Cowrie capture stats and isolation health |

### 4.4 Stack Discovery

| Capability | Safety | Approval | Purpose |
|---|---|---|---|
| `stack.discovery.refresh` | mutating | auto | Fetch, normalize, embed external sources |
| `stack.discovery.query` | read-only | auto | Semantic search against indexed knowledge base |
| `stack.discovery.sources.add` | mutating | manual | Add new source to registry |

---

## 5. Connector Matrix (Adjacent Domains)

### 5.1 Infrastructure (Primary)

| Connector | Existing Surface | Planned Network Security Usage |
|---|---|---|
| SSH targets | `ssh.targets.yaml` + `ssh-resolve.sh` | Host resolution for Unbound/Pi-hole configuration |
| Tailscale | tailscale ACL + snapshot | Cross-site DNS authority for Tailscale DNS coexistence (D314) |
| Cloudflare | `cloudflare.dns.*` capabilities | Cloudflare bouncer for CrowdSec edge blocking |
| Pi-hole | `network.pihole.blocklist.sync` | Upstream DNS change, blocklist rationalization |

### 5.2 Observability

| Connector | Existing Surface | Planned Usage |
|---|---|---|
| Prometheus/Grafana | VM 205 observability stack | IDS alert dashboards, CrowdSec metrics, Cowrie geo-IP |
| Loki | VM 205 log aggregation | Cowrie JSON logs, CrowdSec decision logs |
| Uptime Kuma | VM 205 health monitoring | Unbound health, Pi-hole health, CrowdSec agent health |

### 5.3 Home Automation

| Connector | Existing Surface | Planned Usage |
|---|---|---|
| Home Assistant | `ha.*` capabilities | mDNS reflection impacts IoT device discovery |
| Z2M/Matter | radio stack | IoT VLAN placement affects Zigbee/Matter bridge access |

---

## 6. Governance and Drift Gates (Proposed)

Proposed new gate IDs begin after current max `D332`. Exact IDs assigned at implementation time.

| Gate ID | Name | Purpose |
|---|---|---|
| `D340` | netsec-dns-authority-lock | Fail if Pi-hole upstream is not Unbound, DNSSEC invalid, or bypass prevention absent |
| `D341` | netsec-pihole-drift-lock | Enforce Pi-hole blocklist policy, upstream DNS, and DHCP DNS handout |
| `D342` | netsec-vlan-topology-lock | Enforce VLAN parity against topology contract |
| `D343` | netsec-firewall-baseline-lock | Enforce inter-VLAN rule presence and RFC1918 block order |
| `D344` | netsec-ids-tuning-lock | Enforce Suricata rule state matches tuning contract |
| `D345` | netsec-crowdsec-health-lock | Enforce CrowdSec agent + bouncer alive |
| `D346` | netsec-honeypot-isolation-lock | Enforce Cowrie DMZ isolation (no RFC1918 egress) |
| `D347` | netsec-stack-discovery-freshness-lock | Enforce knowledge base refresh < 36h, source success >= 80% |

---

## 7. Human Review and Risk Policy

### Risk Classes

1. `green`: DNS authority verified, VLANs isolated, IDS tuned, no alerts.
2. `yellow`: Partial configuration (e.g., Unbound deployed but bypass rule missing), CrowdSec degraded.
3. `red`: DNS bypass detected, VLAN isolation broken, honeypot reaching real infra.

### Mandatory Human Sign-Off Triggers

1. Any VLAN creation or modification on production UDR.
2. Any firewall rule change (inter-VLAN, DNS bypass).
3. IDS mode change from IDS-only to IPS (active blocking).
4. CrowdSec bouncer activation (auto-blocking at edge).
5. Honeypot exposure on any VLAN (must be DMZ only).

---

## 8. Security, Privacy, and Retention

### 8.1 Credential Policy

1. UniFi API credentials: Infisical path references only (UNIFI_HOME_USER, UNIFI_HOME_PASSWORD, UNIFI_HOME_API_KEY, UNIFI_SHOP_USER, UNIFI_SHOP_PASSWORD).
2. CrowdSec enrollment key: Infisical path reference.
3. Cloudflare bouncer API token: Infisical path reference.
4. No credentials stored in contracts or design artifacts.

### 8.2 Log Retention

| Log Source | Retention | Purpose |
|---|---|---|
| Pi-hole query logs | 30 days | DNS audit trail |
| Cowrie capture logs | 90 days | Attack pattern analysis |
| CrowdSec decision logs | 90 days | Threat intel evidence |
| Suricata alerts | 30 days | IDS/IPS event history |
| Stack discovery snapshots | 365 days | Historical tool catalog |

---

## 9. Execution Waves (Implementation Roadmap)

This plan is intentionally implementation-ready while remaining design-only.

### Wave 1: DNS Authority (Phases 1-3 of docx)

Outputs:
1. Unbound recursive resolver deployed on Pi-hole host (LXC 105).
2. cloudflared DoH proxy as fallback upstream.
3. Pi-hole Local DNS populated with `.mint.local` entries.
4. UniFi firewall rule: block DNS bypass.

Gate to exit:
- D340 + D341 enforce mode pass.

### Wave 2: VLAN Segmentation (Phases 4-6 of docx)

Outputs:
1. 6 VLANs created in UniFi (home UDR7 first, shop UDR6 later).
2. Inter-VLAN firewall rules with RFC1918 block baseline.
3. mDNS reflection for AirPlay/Cast pairs.
4. Switch port mapping documented.

Gate to exit:
- D342 + D343 pass and cross-VLAN ping test confirms isolation.

Blocker:
- Home site physical visit required for UDR7 changes.

### Wave 3: Threat Detection (Phases 7-9 of docx)

Outputs:
1. Suricata tuned with 48h IDS soak, then IPS.
2. CrowdSec agent + Cloudflare bouncer active.
3. Cowrie on DMZ VLAN with log pipeline to Grafana.

Gate to exit:
- D344 + D345 + D346 pass.

Dependency:
- Wave 2 complete (DMZ VLAN required for Cowrie).

### Wave 4: Stack Knowledge Base (Independent)

Outputs:
1. Source registry populated with initial catalogs.
2. Fetch → normalize → embed pipeline operational.
3. Query capability agent-invocable.
4. Scheduled refresh (daily cron or LaunchAgent).

Gate to exit:
- D347 pass (freshness + source health).

### Wave 5: Stabilization + Promotion

Outputs:
1. Verify route integration (`verify.pack.run network-security` planned).
2. Runtime role promotion from planned → active.
3. All design-only artifacts promoted to active contracts.

Gate to exit:
- 2 weeks stable operation with no red-class issues.

---

## 10. Activation Commands (Future Execution)

When promoting this design to implementation:

1. Promote loop:
```bash
# edit loop status planned -> active
```

2. Register implementation plan horizon:
```bash
./bin/ops cap run planning.plans.list -- --owner @ronny
```

3. Preflight:
```bash
./bin/ops cap run session.start
./bin/ops cap run verify.run -- fast
./bin/ops cap run ssh.target.status
./bin/ops cap run network.shop.audit.status
```

4. Post-domain verify (after domain changes):
```bash
./bin/ops cap run verify.run -- domain network
```

Worker kickoff reference:

- `mailroom/state/plans/PLAN-NETSEC-W1-WORKER-KICKOFF-BRIEF-20260303.md`

---

## 11. Operator Inputs Required Before Wave 1 Promotion

1. Confirm Unbound deployment target: Pi-hole LXC 105 (home) or separate container.
2. Confirm DoH fallback upstream: Cloudflare (1.1.1.1) or Quad9 (9.9.9.9).
3. Confirm `.mint.local` naming convention or alternative domain suffix.
4. Confirm VLAN subnet assignments (proposed: 10.0.{1,10,20,30,40,50}.0/24).
5. Confirm Pi-hole blocklist rationalization: OISD + default, or keep existing Reddit lists.
6. Confirm CrowdSec bouncer target: Cloudflare edge, local iptables, or both.
7. Confirm home visit timeline for VLAN deployment.

---

## 12. Go/No-Go Checklist for Implementation Start

- [ ] Loop status promoted to `active`.
- [ ] Plan reviewed and approved.
- [ ] DNS authority contract approved (Unbound + DoH + bypass rule).
- [ ] VLAN topology contract approved (subnets, isolation rules).
- [ ] Threat detection contract approved (IDS tuning, CrowdSec, Cowrie).
- [ ] Stack discovery contract approved (sources, pipeline, query).
- [ ] Home visit scheduled for VLAN deployment.
- [ ] Initial gate IDs reserved and staged.
- [x] Existing docx plan analyzed and integrated.
- [x] Existing network capabilities cataloged.
- [x] Open gaps (1030, 1108) identified and absorbed.

---

## 13. Natural Follow-On Loops (Planned)

1. `LOOP-NETSEC-DNS-AUTHORITY-IMPLEMENTATION-YYYYMMDD`
2. `LOOP-NETSEC-VLAN-DEPLOYMENT-HOME-YYYYMMDD`
3. `LOOP-NETSEC-VLAN-DEPLOYMENT-SHOP-YYYYMMDD`
4. `LOOP-NETSEC-THREAT-DETECTION-RUNTIME-YYYYMMDD`
5. `LOOP-NETSEC-STACK-DISCOVERY-RUNTIME-YYYYMMDD`
6. `LOOP-NETSEC-PIHOLE-BLOCKLIST-RATIONALIZATION-YYYYMMDD`

Each loop should file child gaps for uncovered governance surfaces before code mutation, per governance brief.
