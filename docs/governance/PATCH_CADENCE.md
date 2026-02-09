---
status: draft
owner: "@ronny"
last_verified: 2026-02-08
scope: patching-governance
---

# Patch Cadence Policy

Purpose: define update schedules and procedures for OS, applications, containers,
and infrastructure firmware.

## Schedule

| Category | Cadence | Window | Procedure |
|----------|---------|--------|-----------|
| **OS security patches** (apt) | Monthly, 1st Saturday | 02:00-06:00 EST | `apt update && apt upgrade` on all VMs, reboot if kernel updated |
| **Proxmox updates** | Quarterly | Planned maintenance window | `apt update && apt dist-upgrade` on pve/proxmox-home. Test on home first. |
| **Docker images** | Continuous (Watchtower) | Automatic | Watchtower on download-stack + streaming-stack pulls latest tags. Other stacks: manual `docker compose pull && docker compose up -d`. |
| **Tailscale** | Monthly with OS patches | Same window | `apt upgrade tailscale` or auto-update if enabled. |
| **Firmware (iDRAC, BIOS, HBA)** | As-needed (security advisories) | Planned maintenance | Download from Dell support, apply via iDRAC web UI. Document version in SHOP_SERVER_SSOT.md. |
| **Network equipment** | As-needed | Planned maintenance | Dell N2024P: web UI firmware upload. TP-Link EAP225: web UI. UDR: UniFi console. |
| **NAS (Synology DSM)** | As-needed (auto-notify) | Planned maintenance | DSM Control Panel > Update. Test backup jobs after update. |
| **Infisical CLI** | Monthly | With OS patches | `brew update && brew upgrade infisical`. Current: 0.43.48, available: 0.43.50. |

## Pre-Patch Checklist

1. Run `./bin/ops cap run backup.vzdump.status` — confirm all VMs have fresh backups.
2. Run `./bin/ops cap run spine.verify` — confirm all drift gates pass.
3. For Proxmox updates: snapshot the VM being patched (`qm snapshot <vmid> pre-patch`).

## Post-Patch Checklist

1. Run `./bin/ops cap run services.health.status` — confirm all services healthy.
2. Run `./bin/ops cap run nodes.status` — confirm all nodes reachable.
3. Run `./bin/ops cap run spine.verify` — confirm no drift gate regressions.
4. Update version numbers in relevant SSOTs (SHOP_SERVER_SSOT.md, MINILAB_SSOT.md, cli.tools.inventory.yaml).

## Proxmox Version Policy (PAT-02)

Current versions:
- pve (shop): PVE 9.1.4, kernel 6.14.8-2-pve
- proxmox-home: PVE 8.4.1, kernel 6.8.12 (major version behind)

Policy: Both sites should run the same major version. Minor version drift (9.1 vs 9.2)
is acceptable. Major version drift (8.x vs 9.x) is not — upgrade proxmox-home to PVE 9.x.

- [ ] Schedule proxmox-home upgrade to PVE 9.x during next home maintenance window.

## Container Vulnerability Scanning (PAT-04)

Current state: No scanning. Docker images pulled and run without CVE checks.

Target:
- [ ] Install Trivy on observability VM.
- [ ] Weekly scan of all running container images: `trivy image <image>`.
- [ ] Log results to Loki for trending.
- [ ] Block deployment of images with CRITICAL CVEs (manual gate for now).

## Watchtower Configuration

Deployed on: download-stack (VM 209), streaming-stack (VM 210).
Environment: `DOCKER_API_VERSION=1.45` (required for Docker CE 29.x).

Not deployed on: infra-core, observability, dev-tools, automation-stack, ai-consolidation.
Reason: infrastructure services need controlled updates, not auto-pull.

## Version Tracking

Tracked in SSOTs:
- Proxmox: SHOP_SERVER_SSOT.md, MINILAB_SSOT.md
- CLI tools: cli.tools.inventory.yaml
- HBA firmware: SHOP_SERVER_SSOT.md

Not yet tracked (gaps):
- iDRAC firmware version
- BIOS version
- Dell N2024P firmware
- TP-Link EAP225 firmware
- Synology DSM version
- UDR firmware
