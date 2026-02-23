---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: workbench-aof-normalization-synthesis
parent_loop: LOOP-WORKBENCH-AOF-NORMALIZATION-IMPLEMENT-20260217
---

# Workbench AOF Normalization Synthesis (2026-02-17)

## Sources Consolidated

- L1 baseline surfaces audit
- L2 runtime/deployment audit (3 lane outputs)
- L3 secrets/contracts audit (3 lane outputs)

Source inbox:
`/Users/ronnyworks/code/agentic-spine/docs/governance/_audits/WORKBENCH_AOF_NORMALIZATION_INBOX_20260216/`

## Deduplicated Findings

### P0

1. Compose ownership conflict: duplicate `minio` service defined in both storage and mint-os compose surfaces.
2. Missing compose logging standard: no stack applies canonical log rotation block.
3. Secrets project drift in active docs: `/finance-stack/prod/*` references remain in active finance docs.

### P1

1. Resource-limit coverage drift: limits present only on a subset of services.
2. Key naming drift in active surfaces: `FIREFLY_ACCESS_TOKEN`/`FIREFLY_TOKEN` and `HA_TOKEN` variants.
3. Metadata field drift in active inventory/docs: `last_snapshot`/`snapshot_date`, `loop_id`/`active_loop`, `vmid`.

### P2

1. Compose header and network declaration inconsistencies.
2. Legacy-doc reference drift (`mint-os-vault`, legacy examples) requiring warn-only treatment.
3. Transitional alias patterns in media/home MCP configs requiring explicit contract treatment.

## Baseline Counters (at synthesis time)

- Compose files with deprecated `version` key: 2
- Compose files with duplicate `minio` ownership: 2 references
- Active finance docs with `/finance-stack/prod/` paths: 5
- Active docs using `loop_id` field: 9
- Active docs using `active_loop` field: 1
- Inventory file using `last_snapshot`/`snapshot_date`: 1

## Canonicalization Scope Lock

In-scope:
- `/Users/ronnyworks/code/workbench/infra/compose/**`
- `/Users/ronnyworks/code/workbench/infra/contracts/**`
- `/Users/ronnyworks/code/workbench/scripts/**`
- `/Users/ronnyworks/code/workbench/infra/data/**`
- `/Users/ronnyworks/code/workbench/docs/brain-lessons/**`
- `/Users/ronnyworks/code/workbench/agents/**/docs/**`

Out-of-scope (this pass):
- Full rewrite of `/Users/ronnyworks/code/workbench/docs/legacy/**`
- Secret value rotation in Infisical
- New drift-gate creation in spine

## Execution Contract

- Enforce proactively through `proposals-apply` preflight, not new gates.
- Block on P0/P1 from workbench checker.
- Warn-only for legacy surfaces unless explicitly escalated post-cutoff.
