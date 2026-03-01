---
status: draft
owner: "@ronny"
created: 2026-02-27
scope: mint-shipping-finance-postwave-governance-playbook
authority: LOOP-MINT-SHIPPING-CARRIER-INTEGRATION-20260226
---

# Mint Shipping + Finance Post-Wave Governance Playbook

## Purpose

Define the governance handoff after subagent wave execution without prematurely
closing gaps. This playbook keeps contract work in capture lane until operator
acceptance.

## Required Inputs (from execution terminal)

1. Six wave commit hashes (`WS1a` to `WS6a`).
2. Guard/test outputs per wave.
3. Any migration dry-run/apply logs.
4. Changed-file manifests per wave.

## Gap Update Policy

- do not close gaps automatically
- do not set unsupported gap status values
- keep target gaps in `open` and append implementation evidence in `notes`

### Target Gap Annotation Set

- `GAP-OP-1022`
- `GAP-OP-1023`
- `GAP-OP-1026`
- `GAP-OP-1027`
- `GAP-OP-1028`
- `GAP-OP-1030`
- `GAP-OP-1031`
- `GAP-OP-1032`
- `GAP-OP-1044`

### Explicit Exclusions

- `GAP-OP-1037..1041` (supplier-finance COGS lane)
- `GAP-OP-1009..1016` (pricing normalization lane)

## Note Template (per implemented gap)

Use this text pattern in `ops/bindings/operational.gaps.yaml` notes field:

```text
Implemented in mint-modules (pending operator acceptance):
- wave: WS{N}a
- commit: <sha>
- tests: shipping=<pass/fail>, finance-adapter=<pass/fail>
- guards: shape=<pass/fail>, internal=<pass/fail>, content=<pass/fail>
- evidence_receipt: <run-key or path>
```

## Post-Wave Proposal Creation

Create one governance proposal after all waves are green:

```bash
cd ~/code/agentic-spine
./bin/ops cap run proposals.submit "shipping-finance-contract-execution" --loop-id LOOP-MINT-SHIPPING-CARRIER-INTEGRATION-20260226
```

Proposal should include:

1. `ops/bindings/operational.gaps.yaml` with note updates for implemented gaps.
2. Loop scope update(s) indicating execution receipts collected and pending operator acceptance.
3. Execution receipt doc in `docs/planning/` containing per-wave summary.

## Execution Receipt Structure

Recommended file:
`docs/planning/MINT_SHIPPING_FINANCE_EXECUTION_RECEIPT_YYYYMMDD.md`

Include sections:

1. Wave summary table (`wave`, `commit`, `gaps`, `verify`).
2. Guard/test outcomes with timestamps.
3. Migration changes and rollback verification.
4. Outstanding risks requiring operator acceptance.

## Acceptance Gate

Only operator can promote from "implemented, pending acceptance" to fixed/closed.
No automatic closure is permitted in the execution terminal.
