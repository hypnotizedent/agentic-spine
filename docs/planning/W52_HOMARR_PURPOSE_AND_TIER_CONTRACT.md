# W52 Homarr Purpose And Tier Contract

Status: proposed  
Owner: @ronny  
Last updated: 2026-02-27  
Scope: streaming-stack Homarr service classification

## Purpose Lock
Homarr is a dashboard/navigation surface for media operators.

Homarr is not playback authority.
Playback authority services are:
- Jellyfin
- Jellyseerr
- Navidrome

## Tier Contract
- Service: `homarr`
- Tier: `dashboard`
- Class: `control-plane`
- Criticality: `non_playback_critical`
- Playback authority: `false`

## Severity Contract
- Homarr degraded (`running` + container `unhealthy`) => WARN
- Playback authority degraded => FAIL

## Binding Alignment
Applied in:
- `ops/bindings/media.services.yaml`
- `docs/governance/SERVICE_REGISTRY.yaml`
