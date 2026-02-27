# W52 Homarr Health Semantics Diff

Status: proposed  
Owner: @ronny  
Last updated: 2026-02-27

## Before
- Container health probe: local `wget` on `/` in streaming-stack compose.
- Endpoint policy: external `services.health.yaml` expected `307` for Homarr.
- Drift gate D108 behavior: hard-coded `HTTP 200` expectation from media service health paths.

Result: Homarr could be marked container-unhealthy while endpoint checks still passed expected redirect policy.

## After
- Compose healthcheck updated to accept `200` or `307` for Homarr root path.
- D108 updated to read canonical `ops/bindings/services.health.yaml` expected code per endpoint.
- `services.health.yaml` policy text now explicitly allows redirect expectations as healthy semantics.
- D245 enforces tier-aware severity with endpoint-aware mismatch handling:
  - playback-authority degradation => `FAIL`
  - dashboard/non-playback-critical `container unhealthy + endpoint OK` => `WARN`

## Impact
- Homarr no longer fails parity due to 307-vs-200 semantics mismatch.
- D108 remains strict for real endpoint drift (e.g., Bazarr missing/unreachable).
- Dashboard-tier healthcheck noise is downgraded without masking playback outages.
