---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-18
scope: aof-evidence-retention-export
---

# AOF Evidence Retention and Export

> Defines retention periods, export formats, and purge rules for AOF evidence.

## Retention Classes

| Class | Path Pattern | Retention | Purge Eligible | Approval Required |
|-------|-------------|-----------|----------------|-------------------|
| Session Receipts | `receipts/sessions/RCAP-*` | 30 days | Yes | manual_approval |
| Ledger Entries | `receipts/ledger/*.yaml` | 365 days | No | N/A |
| Loop Scopes | `mailroom/state/loop-scopes/*.scope.md` | 90 days | Yes | manual_approval |
| Gap Registry | `ops/bindings/operational.gaps.yaml` | 365 days | No | N/A |
| Proposals | `mailroom/outbox/proposals/*` | 30 days | Yes | auto |

## Export Format

- Default: `tar.gz` archive with metadata
- Ledger/registry: `yaml` (structured export)
- Signed attestations: planned (not yet implemented)

## Purge Rules

- No evidence is purged without explicit approval
- High-sensitivity evidence (ledger, gap registry) is never purge-eligible
- Purge operations require capability execution with receipt generation

## Enforcement

- **Binding**: `ops/bindings/evidence.retention.policy.yaml`
- **Gate**: D96 (evidence-retention-policy-lock)
- **Capability**: `evidence.export.plan` (dry-run only, no mutations)
