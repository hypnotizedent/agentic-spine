# Spine Terminal Model Gap Register

**Date:** 2026-02-16
**Loop:** LOOP-SPINE-TERMINAL-MODEL-CLOSEOUT-20260216
**Executor:** SPINE-CONTROL-01 (Terminal C)

## Gap Mapping

| Gap ID | Type | Severity | Lane | Description |
|--------|------|----------|------|-------------|
| GAP-OP-564 | missing-entry | medium | D | No terminal.role.contract.yaml — terminal roles have no formal SSOT |
| GAP-OP-565 | missing-entry | medium | D | No terminal.contract.status capability — no programmatic contract check |
| GAP-OP-566 | missing-entry | low | E | Launcher lacks --terminal-name flag for startup traceability |
| GAP-OP-567 | unclear-doc | low | E | Runbooks/agent docs don't use canonical terminal names |
| GAP-OP-568 | agent-behavior | medium | F | 4 pending proposals untriaged in queue |
| GAP-OP-569 | unclear-doc | low | F | Audit artifacts directory has no retention/tracking policy |

## Lane Assignment

| Lane | Gaps | Write Scope |
|------|------|-------------|
| D (contract/runtime) | 564, 565 | ops/bindings/terminal.*, ops/plugins/terminal/**, ops/capabilities.yaml, ops/bindings/capability_map.yaml, ops/plugins/MANIFEST.yaml |
| E (entry/docs) | 566, 567 | workbench launcher, AGENTS.md, CLAUDE.md, runbook docs |
| F (queue/hygiene) | 568, 569 | proposal queue, audit artifact policy |

## Commit Trail

| Event | Commit |
|-------|--------|
| GAP-OP-564 registered | 6966256 |
| GAP-OP-565 registered | f98bfae |
| GAP-OP-566 registered | f2f213c |
| GAP-OP-567 registered | 8423e56 |
| GAP-OP-568 registered | 014cbb5 |
| GAP-OP-569 registered | 682c91b |
