---
loop_id: LOOP-MUSIC-PIPELINE-UPGRADE-20260225
created: 2026-02-25
status: closed
owner: "@ronny"
scope: music
priority: high
objective: Activate full Soulseek pipeline behind Privado VPN tunnel, tune Soularr, add daily music reporting, reduce wanted albums to zero
---

# Loop Scope: LOOP-MUSIC-PIPELINE-UPGRADE-20260225

## Objective

Activate full Soulseek pipeline behind Privado VPN tunnel, tune Soularr, add daily music reporting, reduce wanted albums to zero

## Status Snapshot (2026-02-25)

- Deployment is live on VM 209: `gluetun`, `slskd`, `soularr`, `huntarr`.
- Verify lane green: media pack passes with D106, D107, D108, D109, D110, D191, D192, D220 (and D223 after VPN canonical wiring).
- Lidarr remote path mapping is configured (`slskd` remote `/downloads/`, local `/media/downloads/slskd/`).
- Baseline metric checkpoint recorded via `media.music.metrics.today`.

## Open Work in This Loop

- `GAP-OP-895` (low): Music Assistant HA integration (manual HA UI step).
- `GAP-OP-896` (low): Tubifarry evaluation soak gate.
  - Decision checkpoint due: **2026-03-11**.

### Observability Backlog (filed 2026-02-25 — re-parented to LOOP-MEDIA-OBSERVABILITY-HARDENING-20260225)

- `GAP-OP-898` (medium): slskd runtime telemetry
- `GAP-OP-899` (medium): Soularr cycle telemetry
- `GAP-OP-900` (medium): qBittorrent queue telemetry
- `GAP-OP-901` (medium): Sonarr daily metrics parity
- `GAP-OP-902` (high): End-to-end media pipeline trace
- `GAP-OP-903` (medium): MCP parity for 5 observability tools
- `GAP-OP-904` (high): 8 unprovisioned Infisical secrets

## Closure

**Closed**: 2026-02-25 via WAVE-20260225-PRIVADO-SECRETS-MUSIC-CLOSEOUT
**Outcome**: Core pipeline deployed and operational (gluetun+slskd+soularr+huntarr on VM 209). 8/8 infrastructure gaps fixed. 9 deferred observability/provisioning gaps re-parented to continuation loop LOOP-MEDIA-OBSERVABILITY-HARDENING-20260225. Baseline: 1685 wanted albums, 22.9% completion.
