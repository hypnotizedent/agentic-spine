---
loop_id: LOOP-MEDIA-OBSERVABILITY-HARDENING-20260225
created: 2026-02-25
status: active
owner: "@ronny"
scope: media
priority: medium
objective: Implement deferred media observability capabilities (VPN health, slskd/soularr/qBittorrent telemetry, sonarr metrics, pipeline trace, MCP tools), provision remaining Infisical secrets, integrate Music Assistant HA addon, evaluate Tubifarry after soak window
---

# Loop Scope: LOOP-MEDIA-OBSERVABILITY-HARDENING-20260225

## Objective

Implement deferred media observability capabilities (VPN health, slskd/soularr/qBittorrent telemetry, sonarr metrics, pipeline trace, MCP tools), provision remaining Infisical secrets, integrate Music Assistant HA addon, evaluate Tubifarry after soak window.

## Provenance

Continuation loop absorbing deferred gaps from:
- LOOP-MUSIC-PIPELINE-UPGRADE-20260225 (closed — core pipeline deployed)
- LOOP-PRIVADO-VPN-CANONICAL-SETUP-20260225 (closed — VPN canonical, D223 active)
- LOOP-MEDIA-SECRETS-CANONICAL-TRACE-20260225 (closed — D224 active, runway normalized)

## Linked Gaps (10) — 8/10 closed

| Gap | Sev | Status | Description | Fixed In |
|-----|-----|--------|-------------|----------|
| GAP-OP-895 | low | **OPEN** | Music Assistant HA addon not integrated | Checkpoint: next HA maintenance window |
| GAP-OP-896 | low | **OPEN** | Tubifarry plugin evaluation | Checkpoint: 2026-03-11 soak gate |
| GAP-OP-897 | medium | fixed | media.vpn.health capability | commit 1b8e5cf |
| GAP-OP-898 | medium | fixed | media.slskd.status capability | commit 1b8e5cf |
| GAP-OP-899 | medium | fixed | media.soularr.status capability | commit 1b8e5cf |
| GAP-OP-900 | medium | fixed | media.qbittorrent.status capability | commit 1b8e5cf |
| GAP-OP-901 | medium | fixed | media.sonarr.metrics.today capability | commit 1b8e5cf |
| GAP-OP-902 | high | fixed | media.pipeline.trace composite capability | commit 1b8e5cf |
| GAP-OP-903 | medium | fixed | MCP tool parity (5 tools) | workbench commit 0f03d13 |
| GAP-OP-904 | high | fixed | Infisical secrets provisioned (8/8) | secrets runway verified |

## Remaining Checkpoints

1. **GAP-OP-895** (Music Assistant HA): Manual addon installation via HA UI. No code dependency. Trigger: next HA maintenance window.
2. **GAP-OP-896** (Tubifarry evaluation): Decision gate at 2026-03-11. If Soularr reduces wanted to <200, skip. If >500 remain, evaluate Tubifarry.

## Execution Summary (2026-02-25)

- Phase 0: Loop + gaps registered, baseline captured
- Phase 1: 8/8 Infisical secrets provisioned (download-stack + streaming-stack)
- Phase 2: 5 tier-1 telemetry caps implemented and verified
- Phase 3: media.pipeline.trace composite + 5 MCP tools shipped
- Phase 4: MCP parity verified (workbench commit 0f03d13)
- Phase 5: GAP-OP-895/896 assessed — both blocked on non-code prerequisites
- Phase 6: verify.core.run 15/15, verify.pack.run secrets 11/11, verify.pack.run media 10/10
