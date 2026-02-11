---
status: closed
owner: "@ronny"
last_verified: 2026-02-11
scope: loop-scope
loop_id: LOOP-HOME-MEDIA-STACK-DOCUMENTATION-20260209
severity: medium
---

# Loop Scope: LOOP-HOME-MEDIA-STACK-DOCUMENTATION-20260209

## Goal

Document the home download-home LXC (LXC 103) media stack. Services (radarr, sonarr, lidarr, prowlarr, sabnzbd, tdarr) are NOT documented anywhere in spine. Need service discovery, storage documentation, and SERVICE_REGISTRY.yaml entries.

## Resolution: CLOSED (superseded)

**Closed 2026-02-11.** This loop is superseded by two findings:

1. **Scope decision:** `LOOP-HOME-SERVICE-REGISTRY-SCOPE-DECISION-20260210` (2026-02-10) explicitly excluded home-site services from SERVICE_REGISTRY.yaml and STACK_REGISTRY.yaml. Home services are secondary/personal, Tailscale-only, no SLA — tracked in `ssh.targets.yaml` for connectivity checks only.

2. **Empty LXC:** Inspection of LXC 103 rootfs via proxmox-home host (2026-02-11) found no Docker data, no compose files, no deployed services. The container is stopped with a bare rootfs (32GB, `/opt/` and `/home/` empty). Only notable config: `/dev/net/tun` bind mount (VPN) and `/mnt/host-staging` host bind mount.

If LXC 103 is restarted and services are deployed in the future, a new loop should be opened.

## Evidence

- LXC config: `/etc/pve/lxc/103.conf` on proxmox-home (2 cores, 2GB RAM, rootfs local-lvm:vm-103-disk-0)
- SERVICE_REGISTRY.yaml scope policy lines 11-15 (out-of-scope declaration)
- Host rootfs inspection: `/var/lib/lxc/103/rootfs/` — empty `/opt/`, `/home/`, no Docker data
