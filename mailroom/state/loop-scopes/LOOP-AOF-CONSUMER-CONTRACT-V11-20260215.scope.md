---
loop_id: LOOP-AOF-CONSUMER-CONTRACT-V11-20260215
created: 2026-02-15
status: closed
severity: medium
owner: "@ronny"
scope: agentic-spine
objective: Add machine-readable JSON output contracts for AOF operator capabilities and lock schema stability for automation/bridge consumers
---

# Loop Scope: AOF Consumer Contract v1.1

## Problem Statement

AOF operator capabilities are human-readable, but automation/bridge consumers
need stable machine output.
Current `aof.*` caps do not have formal JSON-mode contracts + schema
assertions for key stability.

## Deliverables

| Gap ID | Deliverable |
|---|---|
| GAP-OP-405 | `aof.status --json` contract |
| GAP-OP-406 | `aof.version --json` contract |
| GAP-OP-407 | `aof.policy.show --json` contract |
| GAP-OP-408 | `aof.tenant.show --json` contract |
| GAP-OP-409 | `aof.verify --json` contract |
| GAP-OP-410 | Output schemas documented in `docs/governance/OUTPUT_CONTRACTS.md` |
| GAP-OP-411 | Regression tests for parseability + stable keys across all 5 caps |

## Required Contract Shape

All JSON-mode outputs MUST emit a single JSON object on stdout with no banner lines:
- `capability`
- `schema_version`
- `generated_at`
- `status`
- `data`

## Acceptance Criteria

- [ ] Each target cap supports `--json`
- [ ] JSON mode emits valid JSON object only (no extra text)
- [ ] Common envelope fields present for all 5 caps
- [ ] `aof.verify --json` returns gate summary (`passed`, `failed`, `skipped`, `total`, `failed_gates`)
- [ ] `docs/governance/OUTPUT_CONTRACTS.md` includes schema + examples for all 5
- [ ] Tests assert stable required keys and JSON parseability
- [ ] `ops/plugins/aof/tests/*` pass
- [ ] `./bin/ops cap run aof.verify` passes after implementation

## Constraints

- Read-only capability behavior preserved
- Default human-readable output preserved
- No schema-breaking changes without new gap
- Do not touch active RAG loops (`GAP-OP-370`, `GAP-OP-385`)

## Phases

1. File gaps (`GAP-OP-405`..`GAP-OP-411`)
2. Implement JSON mode in 5 AOF operator scripts
3. Document schemas in `OUTPUT_CONTRACTS.md`
4. Add/extend tests for contract stability
5. Verify + close gaps + close loop
