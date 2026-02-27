# W52 Ronny Dependency Burndown

Date anchor: 2026-02-27  
Objective: reduce single-operator dependency by converting manual W51 critical steps into governed trigger-to-receipt flows.

## Critical Manual Step Systemization Matrix

| Manual Step (W51) | Trigger | Capability | Gate | Receipt | Escalation Path |
|---|---|---|---|---|---|
| Triage OOM exits and decide containment action | OOM(137) observed in forensic/status output | `infra.docker_host.status` + `services.health.status` | D252 | capability receipt + W52 master receipt | SPINE-EXECUTION-01 -> SPINE-CONTROL-01 |
| Resolve false degraded probes for intentionally stopped services | degraded probe on known stopped service | `services.health.status` (state review) | D253 | verify pack receipt + W52 master receipt | DOMAIN-COMMS-01 or DEPLOY-MINT-01 -> SPINE-CONTROL-01 |
| Detect stale critical images (minio) before production drift | image age exceeds policy budget | `infra.docker_host.status` / image inventory surfaces | D254 | verify pack receipt + remediation plan receipt | DEPLOY-MINT-01 -> SPINE-EXECUTION-01 |
| Monitor MD1400 capacity and apply guard thresholds | storage headroom near warn/critical | `infra.storage.audit.snapshot` (current) -> future `infra.storage.md1400.capacity` | D255 | snapshot receipt + capacity baseline receipt | SPINE-EXECUTION-01 -> SPINE-CONTROL-01 |
| Prevent credential SPOF during operations/recovery | critical capability blocked by single credential holder | `secrets.*` governance surfaces + role runbooks | D256 | secrets/governance receipt + handoff SOP attestation | SPINE-CONTROL-01 -> SPINE-AUDIT-01 |

## Burndown Targets

| Metric | W51 Baseline | W52A Target | W52B/W53 Target |
|---|---|---|---|
| Critical containment actions with canonical gates | 0/5 | 5/5 report-mode | 5/5 enforce-mode promoted |
| Manual-only critical steps | 5 | <=2 | 0 |
| Single-owner credential critical paths | high | mapped and receipted | mitigated with fallback owners |

## Execution Policy

- W52A remains governance/control-plane only (report mode).
- No protected active lane mutations.
- Promotion to enforce requires explicit criteria satisfaction from contract controls D252-D256.
