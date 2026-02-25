---
loop_id: LOOP-MUSIC-PIPELINE-UPGRADE-20260225
created: 2026-02-25
status: active
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

### Observability Backlog (filed 2026-02-25)

- `GAP-OP-898` (medium): slskd runtime telemetry — Soulseek connection status, peer count, active transfers.
- `GAP-OP-899` (medium): Soularr cycle telemetry — last cycle result, match rate, failure count.
- `GAP-OP-900` (medium): qBittorrent queue/throughput/stall telemetry — active torrents, speeds, stalled count.
- `GAP-OP-901` (medium): Sonarr daily metrics parity — media.sonarr.metrics.today mirroring Radarr/Lidarr pattern.
- `GAP-OP-902` (high): End-to-end media pipeline trace — huntarr → arr → download → import → streaming.
- `GAP-OP-903` (medium): MCP parity for 5 observability tools (get_vpn_status, get_slskd_status, get_soularr_status, get_qbittorrent_queue, get_pipeline_health).
