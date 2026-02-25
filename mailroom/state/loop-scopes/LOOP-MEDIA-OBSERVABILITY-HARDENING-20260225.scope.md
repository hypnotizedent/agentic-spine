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

## Linked Gaps (10)

| Gap | Sev | Type | Blocker | Checkpoint |
|-----|-----|------|---------|------------|
| GAP-OP-895 | low | missing-entry | Manual HA UI (Music Assistant addon) | Next HA maintenance window |
| GAP-OP-896 | low | unclear-doc | 2-week soak gate (Tubifarry eval) | 2026-03-11 |
| GAP-OP-897 | medium | missing-entry | Implement media.vpn.health cap | Next media-agent session |
| GAP-OP-898 | medium | missing-entry | Implement media.slskd.status cap | Next media-agent session |
| GAP-OP-899 | medium | missing-entry | Implement media.soularr.status cap | Next media-agent session |
| GAP-OP-900 | medium | missing-entry | Implement media.qbittorrent.status cap | Next media-agent session |
| GAP-OP-901 | medium | missing-entry | Implement media.sonarr.metrics.today cap | Next media-agent session |
| GAP-OP-902 | high | missing-entry | Implement media.pipeline.trace cap (depends on 897-901) | After tier-1 caps shipped |
| GAP-OP-903 | medium | missing-entry | MCP tool parity (depends on 897-902 spine caps) | After tier-1 caps shipped |
| GAP-OP-904 | high | missing-entry | Manual Infisical provisioning of 8 secrets | Next secrets maintenance window |

## Implementation Priority

1. **Tier 1 — Spine caps** (897-901): Implement 5 telemetry capabilities — each is self-contained, can be built in parallel
2. **Tier 2 — Composite** (902): Pipeline trace depends on tier-1 caps
3. **Tier 3 — MCP tools** (903): Workbench MCP wrappers depend on tier-1+2 spine caps
4. **Manual** (895, 904): HA UI + Infisical provisioning — no code dependency
5. **Soak gate** (896): Decision at 2026-03-11 based on Soularr wanted-count reduction
