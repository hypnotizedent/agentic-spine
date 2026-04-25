---
status: authoritative
owner: "@operator"
last_verified: 2026-03-22
verification_method: spine-capabilities
scope: all-infrastructure
github_issue: "#615"
parent_issues: ["#440", "#609", "#32", "#625"]
---

# DEVICE IDENTITY SSOT

> **This is the authoritative high-level naming and network summary for kept devices.**
>
> For current operator-owned machine identity and eligibility → CHECK `ops/bindings/operator.hardware.inventory.yaml`.
> For current SSH/access-path truth → CHECK `ops/bindings/ssh.targets.yaml`.
> Do not use this document alone to infer live device roles or current node realization.
> For service endpoints/ports/health routes → CHECK `docs/governance/SERVICE_REGISTRY.yaml`.
> Before creating ANY new device/VM/service → FOLLOW THESE RULES.
>
> Last Verified: March 22, 2026

---

## Purpose

This document establishes:

1. **Naming Rules** - How hosts, VMs, and services MUST be named
2. **High-Level Device and Network Summary** - Canonical naming and current high-level network placement
3. **Verification Commands** - How to prove each device is healthy
4. **Retired Surface Notes** - Which historical operator surfaces are no longer governed authority

**Related Documents:**
- `ops/bindings/operator.hardware.inventory.yaml` - Current operator-owned machine identity and eligibility truth
- `ops/bindings/ssh.targets.yaml` - Current SSH/access-path truth
- `docs/governance/SERVICE_REGISTRY.yaml` - Service-level endpoints and health checks
- `docs/governance/SPINE.md` - Daily authority chain and operator workflow

---

## Naming Rules

### Tailscale Hostnames (AUTHORITATIVE)

| Pattern | Example | Use Case |
|---------|---------|----------|
| `{function}` | `macbook` | Single-purpose devices |
| `{function}-{location}` | `proxmox-home`, `immich-1` | When same function exists in multiple locations |
| `{stack}-{role}` | `finance-stack`, `download-stack` | VMs with clear stack ownership |

**Rules:**
- Lowercase only, hyphens for separators
- Max 20 characters (Tailscale limit)
- No underscores (breaks some DNS resolvers)
- Functional names (what it DOES), not arbitrary names

### Proxmox VMID Ranges

| Range | Location | Purpose |
|-------|----------|---------|
| 100-199 | proxmox-home | Home VMs/LXCs |
| 200-299 | pve (shop) | Shop VMs |

### Container Naming

| Pattern | Example | Use Case |
|---------|---------|----------|
| `{stack}-{service}` | `mint-os-postgres` | Stack-owned service |
| `{service}` | `minio` | Standalone infrastructure |

---

## Sites / Physical Locations

### MacBook (Mobile Workstation)

| Property | Value |
|----------|-------|
| Tailscale hostname | `macbook` |
| Tailscale IP | 100.x.x.x |
| Role | Workstation, Spine CLI (RAG paused) |
| Network | Mobile (any network via Tailscale) |
| Verification | `tailscale ip -4` → 100.x.x.x |

### Home Minilab

| Property | Value |
|----------|-------|
| Location | Home residence |
| Subnet | 10.0.x.x/24 |
| Gateway | 10.0.x.x (Ubiquiti UDR) |
| Proxmox Host | `proxmox-home` (Beelink Mini) |
| Active media VM | `media-home` (VM 106) — 10.0.x.x / 100.x.x.x |
| LXCs | `pihole-home` active, `download-home` soft-decommissioned |
| NAS | Synology 918+ (`nas`) |
| Home Assistant | `ha` (VM on proxmox-home) |
| Vaultwarden (legacy) | `vault` decommissioned 2026-02-16 (superseded by `infra-core`) |

**Verification:**
```bash
ssh proxmox-home "qm list && pct list"
ping -c1 nas pihole-home ha
ssh media-home docker ps
```

### Shop Rack (R730XD + N2024P + router-primary)

| Property | Value |
|----------|-------|
| Location | Shop building |
| Subnet | 192.168.x.x/24 |
| Gateway | 192.168.x.x (UniFi router-primary) |
| Router | `udr-shop` — 192.168.x.x (UniFi Dream Router 6) |
| Switch mgmt IP | 192.168.x.x (Dell N2024P) |
| iDRAC | `idrac-shop` — 192.168.x.x (LAN-only) |
| Proxmox Host | `pve` (Dell R730XD) |
| Production VMs | infra-core, observability, dev-tools, ai-consolidation, automation-stack (core); finance-stack, mint-data, mint-apps (Mint); download-stack, streaming-stack (residual media fallback after media-home cutover); immich-1 (deferred) |
| Legacy tombstone VM | `docker-host` historical identity only; not canonical runtime and not expected to stay as a live guest |
| NVR | `nvr-shop` — 192.168.x.x (LAN-only) |
| WiFi AP | `ap-shop` — 192.168.x.x (LAN-only) |

**Verification:**
```bash
ssh pve "qm list"
# For switch/iDRAC: physical access or console cable required
```

**LAN-only endpoints (Shop):**
- `udr-shop` — 192.168.x.x
- `switch-shop` — 192.168.x.x
- `idrac-shop` — 192.168.x.x
- `nvr-shop` — 192.168.x.x
- `ap-shop` — 192.168.x.x

---

## Foundational Host SSOTs

This SSOT is intentionally small: **names + identity + high-level network**.
Deep, mutable infra detail lives in the surviving live summaries:

- `ops/bindings/operator.hardware.inventory.yaml` - Operator-owned machine identity and candidacy
- `ops/bindings/ssh.targets.yaml` - Access-path truth and current SSH routing
- [MINILAB_SSOT.md](MINILAB_SSOT.md) - Home minilab baseline
- [STACK_REGISTRY.yaml](STACK_REGISTRY.yaml) - Stack-to-host inventory
- [SERVICE_REGISTRY.yaml](SERVICE_REGISTRY.yaml) - Service endpoints and health routes

## Canonical Network Summary

### Tailscale Host Table (Canonical)

| Host | Tailscale IP | Location | Role |
|------|-------------|----------|------|
| macbook | 100.x.x.x | Mobile | Workstation + Spine CLI (RAG deferred) |
| pve | 100.x.x.x | Shop | Proxmox VE (shop hypervisor) |
| docker-host | 100.x.x.x | Shop | Tombstone restore identity only for legacy Mint OS history (non-canonical) |
| infra-core | 100.x.x.x | Shop | Core infra (Cloudflared, Pi-hole, Infisical, Vaultwarden, Authentik) |
| observability | 100.x.x.x | Shop | Observability (Prometheus, Grafana, Loki) |
| dev-tools | 100.x.x.x | Shop | Dev tools (Gitea, runner, postgres) |
| ai-consolidation | 100.x.x.x | Shop | AI services (Qdrant, AnythingLLM) (VM 207) |
| automation-stack | 100.x.x.x | Shop | Automation (n8n) |
| download-stack | 100.x.x.x | Shop | Residual downloads + *arr fallback after media-home cutover |
| streaming-stack | 100.x.x.x | Shop | Residual streaming fallback (Jellyfin, Navidrome, Jellyseerr, Bazarr, Homarr, Spotisub) after media-home cutover |
| immich-1 | 100.x.x.x | Shop | Photos (VM 203) |
| finance-stack | 100.x.x.x | Shop | Finance (Firefly III, Paperless, Ghostfolio) (VM 211) |
| mint-data | 100.x.x.x | Shop | Mint data plane (PostgreSQL, MinIO, Redis) (VM 212) |
| mint-apps | 100.x.x.x | Shop | Mint app plane (artwork, quote-page, order-intake) (VM 213) |
| proxmox-home | 100.x.x.x | Home | Proxmox VE (home host) |
| media-home | 100.x.x.x | Home | Canonical home media plane (VM 106) |
| nas | 100.x.x.x | Home | Synology NAS |
| ha | 100.x.x.x | Home | Home Assistant |
| pihole-home | 100.x.x.x | Home | Pi-hole (home DNS) |

### LAN Endpoints (No Tailscale)

| Location | Canonical Name | LAN IP | Purpose |
|----------|----------------|--------|---------|
| Home | `udr-home` | 10.0.x.x | Gateway / UniFi controller |
| Shop | `udr-shop` | 192.168.x.x | Gateway / UniFi controller (router-primary) |
| Shop | `switch-shop` | 192.168.x.x | L2 switch (Dell N2024P) |
| Shop | `idrac-shop` | 192.168.x.x | Out-of-band management (iDRAC) |
| Shop | `nvr-shop` | 192.168.x.x | Camera recorder (NVR) |
| Shop | `ap-shop` | 192.168.x.x | WiFi access point |

Notes (Shop LAN-only endpoints):
- Reachability (ping) was verified from inside the shop LAN via `pve` on 2026-02-09 (`network.lan.device.status`: `RCAP-20260209-143218__network.lan.device.status__Rp8c773204`).
- If any LAN-only endpoint becomes unreachable, assume physical/VLAN/DHCP drift first (not Tailscale); fall back to console access where applicable.

### Shop VM LAN IPs (Static or reserved — used for local routing; NFS uses LAN IPs)

| VM | Canonical Name | LAN IP | VMID | MAC | Notes |
|----|----------------|--------|------|-----|-------|
| pve (hypervisor) | `pve` | 192.168.x.x | — | 44:a8:42:22:2c:a6 | Proxmox host; NFS server |
| docker-host (tombstone) | `docker-host` | 192.168.x.x | 200 | bc:24:11:bb:d0:b6 | Historical identity only. Do not reuse as production hostname/routes if restored; use isolated sandbox identity instead. |
| automation-stack | `automation-stack` | 192.168.x.x | 202 | bc:24:11:31:bc:5a | Automation (n8n, Ollama, Open WebUI). DHCP lease at .110 (no VMID parity). |
| immich (shop) | `immich` | 192.168.x.x | 203 | bc:24:11:b8:e7:40 | Shop photos (Tailscale: `immich-1`). |
| infra-core | `infra-core` | 192.168.x.x | 204 | bc:24:11:19:84:3c | Static IP; Pi-hole DNS |
| observability | `observability` | 192.168.x.x | 205 | bc:24:11:5a:79:ed | Static IP |
| dev-tools | `dev-tools` | 192.168.x.x | 206 | bc:24:11:d9:d6:bc | Static IP |
| ai-consolidation | `ai-consolidation` | 192.168.x.x | 207 | bc:24:11:42:0e:b4 | DHCP lease at .8 (no VMID parity). AI workloads (Qdrant, AnythingLLM). |
| download-stack | `download-stack` | 192.168.x.x | 209 | bc:24:11:44:d0:7b | Residual media fallback; NFS mounts use this IP |
| streaming-stack | `streaming-stack` | 192.168.x.x | 210 | bc:24:11:09:5d:76 | Residual media fallback; NFS mounts use this IP |
| finance-stack | `finance-stack` | 192.168.x.x | 211 | bc:24:11:6f:74:82 | Finance (Firefly III, Paperless, Ghostfolio) |
| mint-data | `mint-data` | 192.168.x.x | 212 | bc:24:11:2b:85:2b | Fresh-slate data plane (PostgreSQL + MinIO + Redis) |
| mint-apps | `mint-apps` | 192.168.x.x | 213 | bc:24:11:39:7a:46 | Fresh-slate app plane (artwork, quote-page, order-intake) |
| communications-stack | `communications-stack` | 192.168.x.x | 214 | bc:24:11:24:82:05 | Stalwart mail server (static .26). Tailscale: 100.x.x.x. |
| surveillance-stack | `surveillance-stack` | 192.168.x.x | 215 | — | Frigate/go2rtc surveillance platform. Tailscale: 100.x.x.x. Live compose authority: `/srv/config/surveillance`; `/opt/stacks/surveillance` is a thin entrypoint symlink. |
| archive-smb | `archive-smb` | 192.168.x.x | 220 | — | Archive SMB file-plane LXC on shop LAN. SSH auth drift observed 2026-03-18; use `pve` control path until repaired. |

### Subnet Table

| Subnet | Location | Gateway | DHCP Range | Notes |
|--------|----------|---------|------------|-------|
| 192.168.x.x/24 | Shop | 192.168.x.x (router-primary) | .100-.199 | Production infrastructure; DNS → Pi-hole (.204) |
| 10.0.x.x/24 | Home | 10.0.x.x (router-primary) | .100-.199 | Home lab |
| 100.x.x.x/32 | Tailscale | MagicDNS | N/A | Mesh overlay network |

### Quick Checks

```bash
# All Tailscale devices
tailscale status

# Tier 1 health (critical infrastructure)
for host in pve infra-core proxmox-home; do
  echo "=== $host ===" && ssh -o ConnectTimeout=5 $host uptime 2>/dev/null || echo "UNREACHABLE"
done

# Service endpoints
./bin/ops cap run mint.public.ingress.proof
# Expected: canonical Mint public ingress receipt with fresh-slate targets

curl -s https://secrets.example.com/api/status
curl -s https://n8n.example.com/healthz
```

### Dashboards

| Dashboard | URL | Purpose |
|-----------|-----|---------|
| Grafana | https://grafana.example.com | Monitoring |
| n8n | https://n8n.example.com | Automation workflows |
| Proxmox (Shop) | https://pve:8006 | VM management |
| Proxmox (Home) | https://proxmox-home:8006 | LXC management |
| Home Assistant | http://ha:8123 | Home automation |
| Infisical | https://secrets.example.com | Secrets management |

---

## Device Registry

### Tier 1: Critical Infrastructure (Must be reachable for ops to work)

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| MacBook Pro M4 | `macbook` | 100.x.x.x | Workstation + Spine CLI (RAG deferred) | Mobile | `ping macbook` |
| Dell R730XD | `pve` | 100.x.x.x | Proxmox Host (Shop) | Shop | `ssh pve uptime` |
| infra-core VM | `infra-core` | 100.x.x.x | Core Infra (VM 204) | Shop | `ssh infra-core docker ps` |
| observability VM | `observability` | 100.x.x.x | Observability (VM 205) | Shop | `ssh observability docker ps` |
| Beelink Mini | `proxmox-home` | 100.x.x.x | Proxmox Host (Home) | Home | `ssh proxmox-home uptime` |

### Tier 2: Production Services (Core)

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| automation-stack VM | `automation-stack` | 100.x.x.x | n8n + Ollama | Shop | `curl -s https://n8n.example.com/healthz` |
| dev-tools VM | `dev-tools` | 100.x.x.x | Gitea + runner | Shop | `curl -s https://git.example.com/api/healthz` |
| ai-consolidation VM | `ai-consolidation` | 100.x.x.x | Qdrant + AnythingLLM (VM 207) | Shop | `curl -s http://100.x.x.x:3002/api/ping` |

### Tier 2: Production Services (Media)

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| media-home VM | `media-home` | 100.x.x.x | Canonical home media plane (VM 106) | Home | `ssh media-home docker ps` |
| download-stack VM | `download-stack` | 100.x.x.x | Residual downloads + *arr fallback (VM 209) | Shop | `ssh download-stack docker ps` |
| streaming-stack VM | `streaming-stack` | 100.x.x.x | Residual streaming fallback (VM 210) | Shop | `ssh streaming-stack docker ps` |

### Tier 2: Production Services (Finance + Mint)

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| finance-stack VM | `finance-stack` | 100.x.x.x | Finance (Firefly III, Paperless, Ghostfolio) (VM 211) | Shop | `ssh finance-stack docker ps` |
| mint-data VM | `mint-data` | 100.x.x.x | Mint data plane (PostgreSQL, MinIO, Redis) (VM 212) | Shop | `ssh mint-data docker ps` |
| mint-apps VM | `mint-apps` | 100.x.x.x | Mint app plane (artwork, quote-page, order-intake) (VM 213) | Shop | `ssh mint-apps docker ps` |

### Deferred (Out of Scope for Foundational Core)

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| immich-1 VM | `immich-1` | 100.x.x.x | Photos (Shop) | Shop | `curl -s http://immich-1:2283/api/server/ping` |

### Legacy Hold (Non-Canonical)

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| docker-host VM | `docker-host` | 100.x.x.x | Legacy Mint OS hold only; not authoritative for fresh-slate Mint | Shop | `vm-200-docker-host-primary` cold restore capsule only; no live SSH/runtime expected |

### Tier 3: Home Services

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| Home Assistant | `ha` | 100.x.x.x | Home Automation | Home | `curl -s http://ha:8123/api/` |
| Synology NAS | `nas` | 100.x.x.x | Storage | Home | `ping nas` |
| Pi-hole home | `pihole-home` | 100.x.x.x | Home DNS filtering | Home | `curl -s http://pihole-home/admin/` |

### Tier 4: Endpoints (Non-critical)

| Device | Tailscale Hostname | Tailscale IP | Role | Notes |
|--------|-------------------|--------------|------|-------|
| iPhone | `iphone` | 100.x.x.x | Mobile | Personal |
| Firestick | `firestick` | 100.x.x.x | Streaming | Often offline |
| windows-mint | `windows-mint` | 100.x.x.x | Windows PC (192.168.12.x, site unconfirmed) | Candidate only — no remote admin plane, no exit node |
| windows-parents | `windows-parents` | 100.x.x.x | Support PC | Remote support |

---

## Verification Commands

### Quick Health Check (All Tier 1)

```bash
# Run from macbook - verifies core infrastructure
for host in pve infra-core proxmox-home; do
  echo "=== $host ==="
  ssh -o ConnectTimeout=5 $host uptime 2>/dev/null || echo "UNREACHABLE"
done
```

**Expected Output (Healthy):**
```
=== pve ===
 14:32:01 up 5 days,  2:15,  0 users,  load average: 0.15, 0.20, 0.18
=== infra-core ===
 14:32:02 up 5 days,  2:14,  0 users,  load average: 0.45, 0.38, 0.35
=== proxmox-home ===
 14:32:03 up 12 days,  4:22,  0 users,  load average: 0.08, 0.12, 0.10
```

### Service-Level Checks

```bash
# Canonical Mint public ingress
./bin/ops cap run mint.public.ingress.proof
# Expected: PASS receipt proving fresh-slate Mint public ingress

# Infisical (Secrets)
curl -s https://secrets.example.com/api/status
# Expected: HTTP 200

# n8n
curl -s http://automation-stack:5678/healthz
# Expected: {"status":"ok"}

# Automation-stack latency budget (repeated sampling + n8n quick timing)
./bin/ops cap run automation.stack.latency.status --json
# Expected: status=pass|warn|incident with p95/p99 and failed sample counts

# Optional: local RAG stack (currently deferred)
# curl -s http://localhost:3002/api/ping
# Expected: {"online":true}
```

### Automation-Stack Latency Thresholds (Self-Driving Cadence)

Source of truth: `ops/bindings/automation.stack.latency.slo.yaml`

| Metric | Warn | Incident | Notes |
|--------|------|----------|-------|
| Aggregate p95 latency | 900ms | 1500ms | Repeated samples across automation-stack service endpoints |
| Aggregate p99 latency | 1300ms | 2200ms | Captures jitter spikes that single probes miss |
| `n8n.infra.health.quick` duration | 2000ms | 5000ms | Control-loop readiness signal |
| Failed samples | 1+ | 3+ | Any failed endpoint sample counts against budget |

This budget is consumed by `stability.control.snapshot` via `automation.stack.latency.status`, and appears in the daily briefing stability section.

### VM Status Check (Proxmox)

```bash
# Shop VMs
ssh pve "qm list"
# Expected: VMs 200, 202-213 running (201 decommissioned)

# Home VMs
ssh proxmox-home "qm list"
# Expected: VM 100 running; VM 101 stopped; VM 102 decommissioned (stopped)
```

---

## Stream Deck as Workflow Entrypoint

Legacy Stream Deck automation was retired on March 11, 2026. Spine no longer treats
`com.ronny.streamdeck.ha` or any workbench Stream Deck runtime as governed active
authority. If Stream Deck returns, reintroduce it as a fresh governed surface rather
than reviving the retired runtime.

---

## Known Unknowns

This SSOT does **not** track loop status (it drifts too easily).

Use the canonical work tracker instead:
- `./bin/ops status`
- `$SPINE_STATE/loop-scopes/*.scope.md` for raw scope drill-down only

---

## Change Control

### Adding a New Device

1. Choose name following Naming Rules above
2. Add to appropriate Tier in Device Registry
3. Add verification command
4. Run verification and paste output to validate
5. Commit with `fix(identity): add {device} to SSOT`

### Updating an IP

1. Update this document FIRST
2. Update `docs/governance/SERVICE_REGISTRY.yaml` if service-level mapping changes
3. Commit with `fix(identity): update {device} IP`

### Removing a Device

1. Move to "Decommissioned" section (don't delete immediately)
2. Document decommission date and reason
3. Remove from `docs/governance/SERVICE_REGISTRY.yaml`
4. After 30 days, remove from this doc entirely

---

## Decommissioned Devices

| Device | Former IP | Decommissioned | Reason |
|--------|-----------|----------------|--------|
| `immich-home` | 100.x.x.x | 2026-02-20 | VM 101 destroyed; shop `immich-1` (VM 203) is sole instance |
| `media-stack` | 100.x.x.x | 2026-02-10 | VM 201 destroyed; split to download-stack (209) + streaming-stack (210) |
| `download-home` | 100.x.x.x | 2026-02-20 | LXC 103 destroyed; shop download-stack (VM 209) is canonical |
| `vault` | 100.x.x.x | 2026-02-16 | VM 102 decommissioned; superseded by vaultwarden on infra-core. |

---

## Related Issues

- **#615** - This document (Device identity SSOT + Stream Deck entrypoint)
- **#440** - Master workflow session (parent)
- **#609** - Post-PVE reliability improvements (identity supports infra work)
- **#613** - Switch NO-CARRIER diagnosis (CLOSED - VM reachability resolved)
- **#618** - Dell N2024P console debug + recovery (physical task, open)
- **#614** - Orchestration layer plan (depends on identity)
- **#610** - Reboot Health Gate (pre/post validation)

---

## Runbooks

| Runbook | Purpose | Script |
|---------|---------|--------|
| `docs/governance/REBOOT_HEALTH_GATE.md` | Pre/post reboot validation | `scripts/infra/reboot_gate.sh` |
| `docs/governance/BACKUP_GOVERNANCE.md` | Backup what/where/how/verify | `scripts/infra/backup_verify.sh` |
| `docs/governance/NETWORK_RUNBOOK.md` | Network change procedures | - |
| External recovery runbook | Cold start recovery lives in workbench docs; query `~/code/workbench` directly | - |

### Latest Audit

- `docs/reference/audits/BACKUP_AUDIT_2026-01-25.md` - Current backup status + gaps

---

## Evidence / Receipts

### 2026-02-05 Physical Truth Baseline (#32)

| Capability | Receipt | Status |
|------------|---------|--------|
| nodes.status | `~/code/.evidence/spine/sessions/RCAP-20260205-155125__nodes.status__Rzvvh72648/receipt.md` | FAIL (historical, pre-decommission split not complete) |
| services.health.status | `~/code/.evidence/spine/sessions/RCAP-20260205-155156__services.health.status__R5omv73468/receipt.md` | 5/5 OK |

**Verification Commands Run:**
- `tailscale ip -4` → 100.x.x.x (macbook)
- `tailscale status` → Full device list verified

**Closed Loop:**
- LOOP-N2024P-DIAG-20260205 (Dell N2024P post-reset diagnostics complete)

**IP Conflict Resolution:**
- SERVICE_REGISTRY.yaml macbook IP corrected: 100.x.x.x → 100.x.x.x

---

## Quick Reference Card

> **Note:** Detailed host tables, subnet info, and dashboards are now in the
> [Canonical Network Summary](#canonical-network-summary) section above.

**Print-friendly summary:**

```
CRITICAL HOSTS (Tier 1):
  macbook      100.x.x.x    Workstation + RAG
  infra-core   100.x.x.x   Core infra (VM 204)
  pve          100.x.x.x   Proxmox (shop)
  proxmox-home 100.x.x.x   Proxmox (home)

SUBNETS:
  192.168.x.x/24   Shop (router-primary, R730XD, VMs)
  10.0.x.x/24      Home (router-primary, Beelink, NAS)
  100.x.x.x        Tailscale mesh

QUICK CHECKS:
  tailscale status             # All devices
  ssh infra-core docker ps     # Core infra containers
  ssh pve qm list              # Shop VMs
  ssh proxmox-home pct list    # Home LXCs

DASHBOARDS:
  https://grafana.example.com  # Monitoring
  https://n8n.example.com      # Automation
  https://secrets.example.com  # Infisical
```
