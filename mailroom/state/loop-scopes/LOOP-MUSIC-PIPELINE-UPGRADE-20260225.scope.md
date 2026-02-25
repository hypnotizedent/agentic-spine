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
