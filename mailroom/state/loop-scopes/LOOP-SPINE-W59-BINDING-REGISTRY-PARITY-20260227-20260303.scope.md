---
loop_id: LOOP-SPINE-W59-BINDING-REGISTRY-PARITY-20260227-20260303
created: 2026-02-27
status: active
owner: "@ronny"
scope: spine-binding-parity
priority: high
objective: Add parity coverage for high-churn bindings and registry surfaces.
---

# Loop Scope: LOOP-SPINE-W59-BINDING-REGISTRY-PARITY-20260227-20260303

## Objective
Ensure high-frequency binding edits cannot drift without gate coverage.

## Included
- `ops/bindings/gate.domain.profiles.yaml`
- `ops/plugins/MANIFEST.yaml`
- `ops/bindings/services.health.yaml`
- `SERVICE_REGISTRY.yaml`
- `ops/bindings/ssh.targets.yaml`
- `ops/bindings/docker.compose.targets.yaml`

## Success Criteria
- Service health entries are resolvable against canonical registry.
- Plugin manifest entries resolve to real plugin capability surfaces.
- No decommissioned SSH target remains referenced by active target maps.

## Definition Of Done
- Parity lock gates drafted and wired.
- Verification evidence captured.
- Drift findings either fixed or explicitly gap-linked.
