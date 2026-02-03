---
status: authoritative
owner: "@ronny"
last_verified: 2026-01-25
verification_method: preflight-checks
scope: all-infrastructure
github_issue: "#615"
parent_issues: ["#440", "#609"]
---

# DEVICE IDENTITY SSOT

> **This is the SINGLE SOURCE OF TRUTH for device naming, identity, and verification.**
>
> Before referencing ANY host, IP, or service → CHECK THIS DOCUMENT.
> Before creating ANY new device/VM/service → FOLLOW THESE RULES.
>
> Last Verified: January 25, 2026

---

## Purpose

This document establishes:

1. **Naming Rules** - How hosts, VMs, and services MUST be named
2. **Device Registry** - Canonical list of all devices with roles, IPs, verification
3. **Verification Commands** - How to prove each device is healthy
4. **Stream Deck Integration** - Physical buttons mapped to infrastructure actions

**Related Documents:**
- `infrastructure/SERVICE_REGISTRY.md` - Detailed service-level info (ports, containers)
- `infrastructure/docs/locations/SHOP.md` - Shop physical infrastructure
- `infrastructure/docs/locations/HOME.md` - Home physical infrastructure

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

## Device Registry

### Tier 1: Critical Infrastructure (Must be reachable for ops to work)

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| MacBook Pro M4 | `macbook` | 100.85.186.7 | Workstation + RAG Hub | Mobile | `ping macbook` |
| Dell R730XD | `pve` | 100.96.211.33 | Proxmox Host (Shop) | Shop | `ssh pve uptime` |
| docker-host VM | `docker-host` | 100.92.156.118 | Mint OS + Production | Shop | `ssh docker-host docker ps` |
| Beelink Mini | `proxmox-home` | 100.103.99.62 | Proxmox Host (Home) | Home | `ssh proxmox-home uptime` |

### Tier 2: Production Services

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| automation-stack VM | `automation-stack` | 100.98.70.70 | n8n + Ollama | Shop | `curl -s http://automation-stack:5678/healthz` |
| media-stack VM | `media-stack` | 100.117.1.53 | Jellyfin + *arr | Shop | `ssh media-stack docker ps \| head -5` |
| immich-1 VM | `immich-1` | 100.114.101.50 | Photos (Shop) | Shop | `curl -s http://immich-1:2283/api/server-info/ping` |

### Tier 3: Home Services

| Device | Tailscale Hostname | Tailscale IP | Role | Location | Verification |
|--------|-------------------|--------------|------|----------|--------------|
| Home Assistant | `ha` | 100.67.120.1 | Home Automation | Home | `curl -s http://ha:8123/api/` |
| Vaultwarden | `vault` | 100.93.142.63 | Passwords | Home | `curl -s http://vault:8080/` |
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

# RAG Stack (MacBook only)
curl -s http://localhost:3002/api/ping
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

Stream Deck is configured for Home Assistant control only (`home-assistant/docs/devices/STREAM_DECK.md`). This section extends it to infrastructure operations.

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

These items need verification and should be updated as discovered:

| Item | Unknown | How to Verify | Priority |
|------|---------|---------------|----------|
| NVR IP | Currently isolated | Physical access to NVR | P2 |
| iDRAC IP | Was 192.168.254.11, may have changed | F2 at POST or DHCP scan | P3 |
| Dell N2024P Switch | Last-known mgmt IP: 10.1.1.242 (UNVERIFIED). Creds unknown. BYPASSED. | Console cable + password recovery | P2 (#618) |
| HP Laptops | Model numbers, specs | Physical inspection | P3 |

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
2. Update `infrastructure/SERVICE_REGISTRY.md` if service-level detail exists
3. Commit with `fix(identity): update {device} IP`

### Removing a Device

1. Move to "Decommissioned" section (don't delete immediately)
2. Document decommission date and reason
3. Remove from SERVICE_REGISTRY.md
4. After 30 days, remove from this doc entirely

---

## Decommissioned Devices

| Device | Former IP | Decommissioned | Reason |
|--------|-----------|----------------|--------|
| immich (home) | 100.83.160.109 | Pending | Migrating to shop immich-1 |

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
| `docs/runbooks/REBOOT_HEALTH_GATE.md` | Pre/post reboot validation | `scripts/infra/reboot_gate.sh` |
| `docs/runbooks/BACKUP_GOVERNANCE.md` | Backup what/where/how/verify | `scripts/infra/backup_verify.sh` |
| `infrastructure/docs/runbooks/COLD_START_RECOVERY.md` | Full recovery after power loss | - |

### Latest Audit

- `docs/audits/BACKUP_AUDIT_2026-01-25.md` - Current backup status + gaps

---

## Quick Reference Card

Print this or add to Stream Deck "cheat sheet" button:

```
CRITICAL HOSTS:
  macbook     100.85.186.7   (you are here)
  docker-host 100.92.156.118 (production)
  pve         100.96.211.33  (proxmox shop)
  proxmox-home 100.103.99.62 (proxmox home)

QUICK CHECKS:
  tailscale status           # All devices
  ssh docker-host docker ps  # Containers
  ssh pve qm list            # VMs

DASHBOARDS:
  https://admin.mintprints.co     # Mint OS
  https://grafana.ronny.works     # Monitoring
  https://n8n.ronny.works         # Automation
```
