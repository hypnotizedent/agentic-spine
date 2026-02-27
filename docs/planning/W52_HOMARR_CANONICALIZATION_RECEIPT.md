# W52 Homarr Canonicalization Receipt

Status: draft  
Owner: @ronny  
Generated: 2026-02-27

## Scope
Canonicalize Homarr as dashboard-tier/non-playback-critical and align health semantics between compose and endpoint policy.

## Files Updated
- `ops/bindings/media.services.yaml`
- `docs/governance/SERVICE_REGISTRY.yaml`
- `ops/bindings/services.health.yaml`
- `ops/staged/streaming-stack/docker-compose.yml`
- `surfaces/verify/d108-media-health-endpoint-parity-lock.sh`
- `surfaces/verify/d245-media-tier-aware-health-severity-lock.sh` (new)
- `ops/bindings/gate.registry.yaml` (D245)
- `ops/bindings/gate.execution.topology.yaml` (D245 assignment)
- `ops/bindings/gate.domain.profiles.yaml` (media includes D245)
- `ops/bindings/gate.agent.profiles.yaml` (media-agent includes D245)

## Evidence Commands
- `./bin/ops cap run media.service.status --vm streaming-stack --json`
- `./bin/ops cap run media.health.check --vm streaming-stack --json`
- `./bin/ops cap run media.status`

## Relevant Run Keys
- `CAP-20260227-035406__media.status__R7y1g21230`
- `CAP-20260227-035914__media.service.status__R5n6j24979`
- `CAP-20260227-035920__media.health.check__R960e26352`
- `CAP-20260227-040117__media.service.status__R8i2j41590` (external audit reference)
- `CAP-20260227-040117__media.health.check__R4s1741599` (external audit reference)
- `CAP-20260227-041237__media.service.status__Rprgk13405`
- `CAP-20260227-041237__media.health.check__R006m13404`
- `CAP-20260227-041244__verify.pack.run__Rijqa14572`
- `CAP-20260227-041353__gate.topology.validate__Rafx719926`
- `CAP-20260227-041404__media.status__Rycgg20902`

## Follow-up Validation Notes
- `D245` now passes with warning for Homarr contract mismatch (`container unhealthy`, endpoint `OK`).
- Media verify pack run confirms `D245 PASS`; remaining failures are separate lanes (`D108`, `D191`, `D192`).
- `gate.topology.validate` currently fails on unrelated topology drift (`D252` active but unassigned).

## Parallel Finding
Bazarr `container-not-found` was observed earlier as a separate blocker lane/gap; current checks show Bazarr healthy, and this lane remains intentionally separate from Homarr dashboard-tier policy.
