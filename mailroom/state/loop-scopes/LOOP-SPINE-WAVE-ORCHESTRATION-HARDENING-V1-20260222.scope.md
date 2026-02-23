---
loop_id: LOOP-SPINE-WAVE-ORCHESTRATION-HARDENING-V1-20260222
status: closed
owner: "@ronny"
created: 2026-02-22
domain: orchestration
terminal: SPINE-CONTROL-01
---

# LOOP-SPINE-WAVE-ORCHESTRATION-HARDENING-V1-20260222

## Objective

Eliminate manual copy/paste between terminals by making wave orchestration fully artifact-driven.

## Scope

- Workers emit strict `EXEC_RECEIPT.json` artifacts (JSON Schema validated)
- `ops wave collect` auto-ingests receipts, updates wave state, patches roadmap/loop-gap status
- `ops board --live` shows real-time wave progress from artifacts
- `ops wave close` gates on valid receipts + checks complete

## Deliverables

1. JSON Schema: `ops/bindings/orchestration.exec_receipt.schema.json`
2. Validator: `ops wave receipt-validate <path>`
3. Hardened collect: receipt scan + validation + state update + `--sync-roadmap`
4. Live board: `ops board --live` with periodic refresh
5. Close gate: strict receipt + dispatch gating with `--force` escape hatch
6. Capability: `orchestration.wave.receipt.validate`
7. Runbook: `docs/governance/WAVE_ORCHESTRATION_V1_RUNBOOK.md`

## Constraints

- agentic-spine only (no mint-modules/workbench edits)
- Backward compatible where possible
- JSON receipt path is canonical going forward
