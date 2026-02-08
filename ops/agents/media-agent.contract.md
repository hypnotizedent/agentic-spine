# media-agent Contract

> **Status:** registered
> **Domain:** media
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Loop:** LOOP-MEDIA-AGENT-WORKBENCH-20260208

---

## Identity

- **Agent ID:** media-agent
- **Domain:** media (download-stack + streaming-stack)
- **Implementation:** `~/code/workbench/agents/media/` (pending — see loop)
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | Services | VMs |
|---------|----------|-----|
| Language/quality profiles | Radarr, Sonarr, Lidarr | VM 209 |
| Custom format config | Recyclarr | VM 209 |
| Subtitle language prefs | Bazarr | VM 210 |
| Library metadata | Jellyfin | VM 210 |
| Troubleshooting (wrong language, missing subs) | All *arr + Jellyfin | VM 209, 210 |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Compose deployment | `ops/staged/{download,streaming}-stack/` |
| Health probes (up/down) | `ops/bindings/services.health.yaml` |
| Domain routing | `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml` |
| Secrets | Infisical `/spine/vm-infra/media-stack/` |
| NFS mounts | Spine-governed fstab on VMs |
| SSH targets | `ops/bindings/ssh.targets.yaml` |

## Invocation

On-demand via Claude Code session. No watchers, no cron, no schedulers (WORKBENCH_CONTRACT compliance). Spine may invoke via mailroom prompt if needed.

## Endpoints

| VM | Tailscale IP | Role |
|----|-------------|------|
| 209 (download-stack) | 100.107.36.76 | Acquisition: Radarr, Sonarr, Lidarr, Prowlarr, SABnzbd |
| 210 (streaming-stack) | 100.123.207.64 | Playback: Jellyfin, Navidrome, Jellyseerr, Bazarr |
