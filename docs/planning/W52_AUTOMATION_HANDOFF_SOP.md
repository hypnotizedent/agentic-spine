# W52 Automation Handoff SOP

Date anchor: 2026-02-27  
Scope: handoff protocol for W51 critical containment/manual actions under W52 governance controls.

## SOP Table

| Workflow | Trigger | Capability | Gate | Receipt | Escalation Path |
|---|---|---|---|---|---|
| OOM containment classification | Any container exit code `137` in status evidence | `infra.docker_host.status` + `services.health.status` | D252 | capability run receipt + loop receipt | SPINE-EXECUTION-01 -> SPINE-CONTROL-01 |
| Health probe state normalization | Probe degraded while service is expected stopped | `services.health.status` | D253 | verify.pack receipt (mint/comms) | DOMAIN runtime owner -> SPINE-CONTROL-01 |
| Image freshness budget evaluation | Critical service image age exceeds threshold | image inventory evidence surfaces | D254 | gate/report receipt + remediation receipt | DEPLOY-MINT-01 -> SPINE-EXECUTION-01 |
| MD1400 headroom monitoring | Capacity unknown or below warn threshold | `infra.storage.audit.snapshot` (interim), future `infra.storage.md1400.capacity` | D255 | storage snapshot/capacity receipt | SPINE-EXECUTION-01 -> SPINE-CONTROL-01 |
| Credential SPOF fallback validation | Capability execution depends on single operator credential ownership | `secrets.exec` / secrets governance checks | D256 | secrets/governance receipt + SOP attestation | SPINE-CONTROL-01 -> SPINE-AUDIT-01 |

## Handoff Steps

1. Run trigger capability and collect run key.
2. Evaluate corresponding D252-D256 gate in report mode.
3. Attach run key(s) and gate result in the active loop receipt.
4. If gate reports HIGH findings, open/link gap (or reuse linked open gap).
5. Escalate using table path without mutating protected lanes.

## Protected Lanes and Safety

- Do not mutate: `LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226`, `GAP-OP-973`, active EWS import lane, active MD1400 rsync lane.
- No secret values in SOP outputs; key names and governance references only.
- W52A is report-first and control-plane only.
