---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
scope: aof-support-slo
---

# AOF Support SLO

> Service-level objectives for AOF operational support.

## Scope

These SLOs apply to the AOF spine runtime, not domain-specific workloads.

## Response Times

| Severity | Description | Response Target | Resolution Target |
|----------|-------------|-----------------|-------------------|
| Critical | spine.verify fails, all gates blocked | 4 hours | 24 hours |
| High | Individual gate failure, capability broken | 12 hours | 48 hours |
| Medium | Stale SSOT, documentation drift | 48 hours | 1 week |
| Low | Enhancement request, cosmetic issue | 1 week | Best effort |

## Availability

- **Spine verify**: Available whenever the repo is accessible (no external dependencies except git)
- **Capabilities**: Availability depends on infrastructure targets (VMs, APIs, secrets provider)
- **Drift gates**: All gates are offline-capable (run against local repo state)

## Incident Workflow

1. File a gap: `./bin/ops cap run gaps.file --id GAP-OP-NNN --type runtime-bug --severity high --description "..." --discovered-by "..." --doc "..."`
2. Claim the gap: `./bin/ops cap run gaps.claim GAP-OP-NNN --action "fix description"`
3. Fix and close: `./bin/ops cap run gaps.close GAP-OP-NNN --status fixed --fixed-in "commit-or-loop-ref"`

## Escalation

- Primary: @ronny (operator/owner)
- All incidents tracked in `ops/bindings/operational.gaps.yaml`
- No external ticketing system — gaps registry is the SSOT

## Review Cadence

- SLO targets reviewed quarterly
- Gap closure rates reviewed per session closeout (D61)
