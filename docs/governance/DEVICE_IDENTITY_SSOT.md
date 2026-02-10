---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-10
verification_method: spine-capabilities
scope: all-infrastructure
github_issue: "#615"
parent_issues: ["#440", "#609", "#32", "#625"]
---

# DEVICE IDENTITY SSOT

> **This is the SINGLE SOURCE OF TRUTH for device naming, identity, and verification.**
>
> Before referencing hostnames, device roles, or Tailscale/LAN IPs → CHECK THIS DOCUMENT.
> For service endpoints/ports/health routes → CHECK `docs/governance/SERVICE_REGISTRY.yaml`.
> Before creating ANY new device/VM/service → FOLLOW THESE RULES.
>
> Last Verified: February 9, 2026

---

## Purpose

This document establishes:

1. **Naming Rules** - How hosts, VMs, and services MUST be named
2. **Device Registry** - Canonical list of all devices with roles, IPs, verification
3. **Verification Commands** - How to prove each device is healthy
4. **Stream Deck Integration** - Physical buttons mapped to infrastructure actions

**Related Documents:**
- `docs/governance/SERVICE_REGISTRY.yaml` - Service-level endpoints and health checks
- `docs/governance/WORKBENCH_TOOLING_INDEX.md` - External infra tooling (read-only)

---

## Naming Rules

### Tailscale Hostnames (AUTHORITATIVE)

| Pattern | Example | Use Case |
|---------|---------|----------|
| `{function}` | `macbook` | Single-purpose devices |
| `{function}-{location}` | `proxmox-home`, `immich-1` | When same function exists in multiple locations |
| `{stack}-{role}` | `docker-host`, `media-stack` | VMs with clear stack ownership |

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
| Tailscale IP | 100.85.186.7 |
| Role | Workstation, Spine CLI (RAG paused) |
| Network | Mobile (any network via Tailscale) |
| Verification | `tailscale ip -4` → 100.85.186.7 |

### Home Minilab

| Property | Value |
|----------|-------|
| Location | Home residence |
| Subnet | 10.0.0.0/24 |
| Gateway | 10.0.0.1 (Ubiquiti UDR) |
| Proxmox Host | `proxmox-home` (Beelink Mini) |
| LXCs | pihole-home, download-home |
| NAS | Synology 918+ (`nas`) |
| Home Assistant | `ha` (VM on proxmox-home) |
| Vaultwarden (rollback) | `vault` (VM on proxmox-home, VMID 102) — rollback source only (primary runs on `infra-core`) |

**Verification:**
```bash
ssh proxmox-home "qm list && pct list"
ping -c1 nas pihole-home ha vault
```

### Shop Rack (R730XD + N2024P + UDR6)

| Property | Value |
|----------|-------|
| Location | Shop building |
| Subnet | 192.168.1.0/24 |
| Gateway | 192.168.1.1 (UniFi UDR6) |
| Router | `udr-shop` — 192.168.1.1 (UniFi Dream Router 6) |
| Switch mgmt IP | 192.168.1.2 (Dell N2024P) |
| iDRAC | `idrac-shop` — 192.168.1.250 (LAN-only) |
| Proxmox Host | `pve` (Dell R730XD) |
| Production VMs | docker-host, infra-core, observability, dev-tools, ai-consolidation, automation-stack (core); download-stack, streaming-stack (media split); media-stack (decommissioning), immich-1 (deferred) |
| NVR | `nvr-shop` — 192.168.1.216 (LAN-only) |
| WiFi AP | `ap-shop` — 192.168.1.185 (LAN-only) |

**Verification:**
```bash
ssh pve "qm list"
# For switch/iDRAC: physical access or console cable required
```

**LAN-only endpoints (Shop):**
- `udr-shop` — 192.168.1.1
- `switch-shop` — 192.168.1.2
- `idrac-shop` — 192.168.1.250
- `nvr-shop` — 192.168.1.216
- `ap-shop` — 192.168.1.185

---

## Foundational Host SSOTs

This SSOT is intentionally small: **names + identity + high-level network**.
Deep, mutable infra detail lives in the per-location SSOT docs:

- [MACBOOK_SSOT.md](MACBOOK_SSOT.md) - Workstation baseline (hardware + local services)
- [MINILAB_SSOT.md](MINILAB_SSOT.md) - Home minilab baseline (Beelink + NAS + home VMs/LXCs)
- [SHOP_SERVER_SSOT.md](SHOP_SERVER_SSOT.md) - Shop rack baseline (R730XD + switch + NVR + UPS)

## Canonical Network Summary

### Tailscale Host Table (Canonical)

| Host | Tailscale IP | Location | Role |
|------|-------------|----------|------|
| macbook | 100.85.186.7 | Mobile | Workstation + Spine CLI (RAG deferred) |
| pve | 100.96.211.33 | Shop | Proxmox VE (shop hypervisor) |
| docker-host | 100.92.156.118 | Shop | Production docker (Mint OS) |
| infra-core | 100.92.91.128 | Shop | Core infra (Cloudflared, Pi-hole, Infisical, Vaultwarden, Authentik) |
| observability | 100.120.163.70 | Shop | Observability (Prometheus, Grafana, Loki) |
| dev-tools | 100.90.167.39 | Shop | Dev tools (Gitea, runner, postgres) |
| ai-consolidation | 100.71.17.29 | Shop | AI services (Qdrant, AnythingLLM) (VM 207) |
| automation-stack | 100.98.70.70 | Shop | Automation (n8n) |
| download-stack | 100.107.36.76 | Shop | Downloads + *arr (split from media-stack) |
| streaming-stack | 100.123.207.64 | Shop | Streaming (Jellyfin, Navidrome, Jellyseerr, Bazarr, Homarr, Spotisub) (split from media-stack) |
| proxmox-home | 100.103.99.62 | Home | Proxmox VE (home host) |
| nas | 100.102.199.111 | Home | Synology NAS |
| vault | 100.93.142.63 | Home | Vaultwarden rollback source (VM 102) |
| ha | 100.67.120.1 | Home | Home Assistant |
| pihole-home | 100.105.148.96 | Home | Pi-hole |
| download-home | 100.125.138.110 | Home | Downloads (*arr) (deferred) |

### LAN Endpoints (No Tailscale)

| Location | Canonical Name | LAN IP | Purpose |
|----------|----------------|--------|---------|
| Home | `udr-home` | 10.0.0.1 | Gateway / UniFi controller |
| Shop | `udr-shop` | 192.168.1.1 | Gateway / UniFi controller (UDR6) |
| Shop | `switch-shop` | 192.168.1.2 | L2 switch (Dell N2024P) |
| Shop | `idrac-shop` | 192.168.1.250 | Out-of-band management (iDRAC) |
| Shop | `nvr-shop` | 192.168.1.216 | Camera recorder (NVR) |
| Shop | `ap-shop` | 192.168.1.185 | WiFi access point |

Notes (Shop LAN-only endpoints):
- Reachability (ping) was verified from inside the shop LAN via `pve` on 2026-02-09 (`network.lan.device.status`: `RCAP-20260209-143218__network.lan.device.status__Rp8c773204`).
- If any LAN-only endpoint becomes unreachable, assume physical/VLAN/DHCP drift first (not Tailscale); fall back to console access where applicable.

### Shop VM LAN IPs (Static or reserved — used for local routing; NFS uses LAN IPs)

| VM | Canonical Name | LAN IP | VMID | Notes |
|----|----------------|--------|------|-------|
| pve (hypervisor) | `pve` | 192.168.1.184 | — | Proxmox host; NFS server |
| docker-host (Mint OS) | `docker-host` | 192.168.1.200 | 200 | Static IP (netplan). Mint OS production workloads. |
| media-stack | `media-stack` | 192.168.1.201 | 201 | Legacy VM (decommissioning; split to 209/210). |
| automation-stack | `automation-stack` | 192.168.1.202 | 202 | Automation (n8n, Ollama, Open WebUI). |
| immich (shop) | `immich` | 192.168.1.203 | 203 | Shop photos (Tailscale: `immich-1`). |
| infra-core | `infra-core` | 192.168.1.204 | 204 | Static IP; Pi-hole DNS |
| observability | `observability` | 192.168.1.205 | 205 | Static IP |
| dev-tools | `dev-tools` | 192.168.1.206 | 206 | Static IP |
| ai-consolidation | `ai-consolidation` | 192.168.1.207 | 207 | DHCP noted in SHOP_SERVER_SSOT; confirm reservation on UDR. |
| download-stack | `download-stack` | 192.168.1.209 | 209 | NFS mounts use this IP |
| streaming-stack | `streaming-stack` | 192.168.1.210 | 210 | NFS mounts use this IP |

### Subnet Table

| Subnet | Location | Gateway | DHCP Range | Notes |
|--------|----------|---------|------------|-------|
| 192.168.1.0/24 | Shop | 192.168.1.1 (UDR6) | .100-.199 | Production infrastructure; DNS → Pi-hole (.204) |
| 10.0.0.0/24 | Home | 10.0.0.1 (UDR7) | .100-.199 | Home lab |
| 100.x.x.x/32 | Tailscale | MagicDNS | N/A | Mesh overlay network |

### Quick Checks

```bash
# All Tailscale devices
tailscale status

# Tier 1 health (critical infrastructure)
for host in pve docker-host proxmox-home; do
  echo "=== $host ===" && ssh -o ConnectTimeout=5 $host uptime 2>/dev/null || echo "UNREACHABLE"
done

# Service endpoints
curl -s https://mintprints-api.ronny.works/health
curl -s https://secrets.ronny.works/api/status
curl -s http://automation-stack:5678/healthz
```

### Dashboards

| Dashboard | URL | Purpose |
|-----------|-----|---------|
| Mint OS Admin | https://admin.mintprints.co | Business operations |
| Grafana | https://grafana.ronny.works | Monitoring |
| n8n | https://n8n.ronny.works | Automation workflows |
| Proxmox (Shop) | https://pve:8006 | VM management |
| Proxmox (Home) | https://proxmox-home:8006 | LXC management |
| Home Assistant | http://ha:8123 | Home automation |
| Infisical | https://secrets.ronny.works | Secrets management |

---

## Device Registry

### Tier 1: Critical Infrastructure (Must be reachable for ops to work)

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| MacBook Pro M4 | `macbook` | 100.85.186.7 | Workstation + Spine CLI (RAG deferred) | Mobile | `ping macbook` |
| Dell R730XD | `pve` | 100.96.211.33 | Proxmox Host (Shop) | Shop | `ssh pve uptime` |
| docker-host VM | `docker-host` | 100.92.156.118 | Mint OS + Production | Shop | `ssh docker-host docker ps` |
| infra-core VM | `infra-core` | 100.92.91.128 | Core Infra (VM 204) | Shop | `ssh infra-core docker ps` |
| observability VM | `observability` | 100.120.163.70 | Observability (VM 205) | Shop | `ssh observability docker ps` |
| Beelink Mini | `proxmox-home` | 100.103.99.62 | Proxmox Host (Home) | Home | `ssh proxmox-home uptime` |

### Tier 2: Production Services (Core)

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| automation-stack VM | `automation-stack` | 100.98.70.70 | n8n + Ollama | Shop | `curl -s http://automation-stack:5678/healthz` |
| dev-tools VM | `dev-tools` | 100.90.167.39 | Gitea + runner | Shop | `curl -s http://100.90.167.39:3000/api/healthz` |
| ai-consolidation VM | `ai-consolidation` | 100.71.17.29 | Qdrant + AnythingLLM (VM 207) | Shop | `curl -s http://100.71.17.29:3002/api/ping` |

### Tier 2: Production Services (Media)

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| download-stack VM | `download-stack` | 100.107.36.76 | Downloads + *arr (VM 209) | Shop | `ssh download-stack docker ps` |
| streaming-stack VM | `streaming-stack` | 100.123.207.64 | Jellyfin + Navidrome (VM 210) | Shop | `ssh streaming-stack docker ps` |

### Deferred (Out of Scope for Foundational Core)

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| media-stack VM | `media-stack` | 100.117.1.53 | Legacy media (decommissioning) | Shop | `ssh media-stack docker ps \| head -5` |
| immich-1 VM | `immich-1` | 100.114.101.50 | Photos (Shop) | Shop | `curl -s http://immich-1:2283/api/server-info/ping` |

### Tier 3: Home Services

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| Home Assistant | `ha` | 100.67.120.1 | Home Automation | Home | `curl -s http://ha:8123/api/` |
| Vaultwarden (rollback) | `vault` | 100.93.142.63 | Passwords | Home | `curl -s http://vault:8080/` |
| Synology NAS | `nas` | 100.102.199.111 | Storage | Home | `ping nas` |
| download-home LXC | `download-home` | 100.125.138.110 | *arr (home) | Home | `ssh download-home uptime` |
| pihole-home LXC | `pihole-home` | 100.105.148.96 | DNS | Home | `ping pihole-home` |

### Tier 4: Endpoints (Non-critical)

| Device | Tailscale Hostname | Tailscale IP | Role | Notes |
|--------|-------------------|--------------|------|-------|
| iPhone | `iphone` | 100.73.199.85 | Mobile | Personal |
| Firestick | `firestick` | 100.68.235.100 | Streaming | Often offline |
| windows-mint | `windows-mint` | 100.65.199.32 | Shop Windows | Exit node |
| windows-parents | `windows-parents` | 100.102.167.111 | Support PC | Remote support |

---

## Verification Commands

### Quick Health Check (All Tier 1)

```bash
# Run from macbook - verifies core infrastructure
for host in pve docker-host proxmox-home; do
  echo "=== $host ==="
  ssh -o ConnectTimeout=5 $host uptime 2>/dev/null || echo "UNREACHABLE"
done
```

**Expected Output (Healthy):**
```
=== pve ===
 14:32:01 up 5 days,  2:15,  0 users,  load average: 0.15, 0.20, 0.18
=== docker-host ===
 14:32:02 up 5 days,  2:14,  0 users,  load average: 0.45, 0.38, 0.35
=== proxmox-home ===
 14:32:03 up 12 days,  4:22,  0 users,  load average: 0.08, 0.12, 0.10
```

### Service-Level Checks

```bash
# Mint OS API
curl -s https://mintprints-api.ronny.works/health
# Expected: {"status":"ok"} or similar JSON

# Infisical (Secrets)
curl -s https://secrets.ronny.works/api/status
# Expected: HTTP 200

# n8n
curl -s http://automation-stack:5678/healthz
# Expected: {"status":"ok"}

# Optional: local RAG stack (currently deferred)
# curl -s http://localhost:3002/api/ping
# Expected: {"online":true}
```

### VM Status Check (Proxmox)

```bash
# Shop VMs
ssh pve "qm list"
# Expected: VMs 200-203 running

# Home VMs
ssh proxmox-home "qm list"
# Expected: VMs 100-102 running
```

---

## Stream Deck as Workflow Entrypoint

### Current State

Stream Deck is configured for Home Assistant control only (see the Home Assistant repo docs). This section extends it to infrastructure operations.

### MVP Button Layout (Infrastructure)

| Key | Label | Action | Verification |
|-----|-------|--------|--------------|
| 0 | HEALTH | Run `scripts/verify-identity.sh` | Shows pass/fail on deck |
| 1 | DOCKER | `ssh docker-host docker ps` | Container count |
| 2 | PVE | `ssh pve qm list` | VM status |
| 3 | N8N | Open `https://n8n.ronny.works` | Browser |
| 4 | GRAFANA | Open `https://grafana.ronny.works` | Browser |

### Integration Points

| Tool | Config Location | How Stream Deck Connects |
|------|-----------------|-------------------------|
| Python Controller | `home-assistant/scripts/streamdeck/` | Direct HA API calls |
| Raycast | `~/.config/raycast/` | URL schemes |
| Hammerspoon | `~/.hammerspoon/` | hotkey → script |

### Adding Infrastructure Buttons

1. Edit `home-assistant/scripts/streamdeck/config.json`
2. Add button with `type: "url"` pointing to service dashboards
3. Or add `type: "text"` to paste SSH commands
4. Restart: `launchctl kickstart -k gui/$(id -u)/com.ronny.streamdeck.ha`

---

## Known Unknowns

This SSOT does **not** track loop status (it drifts too easily).

Use the loop ledger instead:
- `./bin/ops loops list --open`
- `mailroom/state/open_loops.jsonl`

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
| `immich` (home) | 100.83.160.109 | Pending | Migrating to shop `immich-1` |

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
| External recovery runbook | Cold start recovery (workbench tooling; see WORKBENCH_TOOLING_INDEX.md) | - |

### Latest Audit

- `docs/audits/BACKUP_AUDIT_2026-01-25.md` - Current backup status + gaps

---

## Evidence / Receipts

### 2026-02-05 Physical Truth Baseline (#32)

| Capability | Receipt | Status |
|------------|---------|--------|
| nodes.status | `receipts/sessions/RCAP-20260205-155125__nodes.status__Rzvvh72648/receipt.md` | FAIL (media-stack deferred) |
| services.health.status | `receipts/sessions/RCAP-20260205-155156__services.health.status__R5omv73468/receipt.md` | 5/5 OK |

**Verification Commands Run:**
- `tailscale ip -4` → 100.85.186.7 (macbook)
- `tailscale status` → Full device list verified

**Closed Loop:**
- LOOP-N2024P-DIAG-20260205 (Dell N2024P post-reset diagnostics complete)

**IP Conflict Resolution:**
- SERVICE_REGISTRY.yaml macbook IP corrected: 100.115.158.91 → 100.85.186.7

---

## Quick Reference Card

> **Note:** Detailed host tables, subnet info, and dashboards are now in the
> [Canonical Network Summary](#canonical-network-summary) section above.

**Print-friendly summary:**

```
CRITICAL HOSTS (Tier 1):
  macbook      100.85.186.7    Workstation + RAG
  docker-host  100.92.156.118  Mint OS production
  infra-core   100.92.91.128   Core infra (VM 204)
  pve          100.96.211.33   Proxmox (shop)
  proxmox-home 100.103.99.62   Proxmox (home)

SUBNETS:
  192.168.1.0/24   Shop (UDR6, R730XD, VMs)
  10.0.0.0/24      Home (UDR7, Beelink, NAS)
  100.x.x.x        Tailscale mesh

QUICK CHECKS:
  tailscale status             # All devices
  ssh docker-host docker ps    # Containers
  ssh pve qm list              # Shop VMs
  ssh proxmox-home pct list    # Home LXCs

DASHBOARDS:
  https://admin.mintprints.co  # Mint OS
  https://grafana.ronny.works  # Monitoring
  https://n8n.ronny.works      # Automation
  https://secrets.ronny.works  # Infisical
```
