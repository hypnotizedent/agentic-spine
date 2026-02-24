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

## Governed Tools

_No governed tools registered. Media operations are read-only via API._

## Invocation

On-demand via Claude Code session. No watchers, no cron, no schedulers (WORKBENCH_CONTRACT compliance). Spine may invoke via mailroom prompt if needed.

## Drift Gates

| Gate | Name | Scope |
|------|------|-------|
| D106-D110 | Media infra hygiene | Port collision, NFS mounts, health, compose parity, HA overlap |
| D191-D192 | Content ledger/snapshot | Observed-to-ledger parity, snapshot freshness |
| D220 | Recyclarr language enforcement | Language CFs (Not English, Not Original) in all *arr sections |

## Quality Profile Governance (P5 — 2026-02-24)

Language and quality enforcement is managed via Recyclarr custom formats in `workbench/agents/media/config/recyclarr.yml`. Key rules:

- **Language enforcement:** Every *arr service (Radarr, Sonarr) MUST have "Language: Not English" and "Language: Not Original" CFs scored at -10000.
- **BR-DISK rejection:** Raw disc rips scored at -10000 in all profiles.
- **TRaSH IDs are per-service:** Radarr and Sonarr use DIFFERENT trash_ids for the same CF names. Never copy IDs between services.
- **Drift gate D220** prevents regression — if a new *arr service is added without language CFs, the gate fails.
- **Sync flow:** Edit `recyclarr.yml` -> run `recyclarr.sync` -> verify with `verify.pack.run media`.

| Service | Profile | Language: Not English | Language: Not Original | BR-DISK |
|---------|---------|----------------------|------------------------|---------|
| Radarr | HD Bluray + WEB | `0dc8aec3...` (-10000) | `d6e9318c...` (-10000) | `9c1630` (-10000) |
| Sonarr | WEB-1080p | `69aa1e15...` (-10000) | `ae575f95...` (-10000) | `85c61753...` (-10000) |

## Playbooks

| Playbook | Scope |
|----------|-------|
| `wrong-language.md` | Diagnose/fix non-English grabs (movies + TV) |
| `missing-subtitles.md` | Bazarr provider and sync issues |
| `tdarr-safety.md` | Transcode automation safety (PARKED) |
| `library-hygiene.md` | Stale metadata cleanup |

## Endpoints

| VM | Tailscale IP | Role |
|----|-------------|------|
| 209 (download-stack) | 100.107.36.76 | Acquisition: Radarr, Sonarr, Lidarr, Prowlarr, SABnzbd |
| 210 (streaming-stack) | 100.123.207.64 | Playback: Jellyfin, Navidrome, Jellyseerr, Bazarr |
