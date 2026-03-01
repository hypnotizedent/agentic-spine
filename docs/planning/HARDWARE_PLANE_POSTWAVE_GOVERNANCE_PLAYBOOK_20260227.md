---
status: superseded
owner: "@ronny"
created: 2026-02-27
superseded_at: 2026-03-01
scope: hardware-plane-postwave-governance-playbook
authority: LOOP-INFRA-HARDWARE-PLANE-AUDIT-20260227
---

> **SUPERSEDED 2026-03-01**: Target gaps 1047/1048/1049 already closed/fixed prior to execution.
> GAP-OP-1036 moved to LOOP-HOME-INFRA-RECOVERY-20260301 (accepted/blocked).
> No wave execution occurred; playbook is historical only.

# Hardware Plane Post-Wave Governance Playbook

## Purpose

Define governance handling for hardware-plane wave execution so work can be integrated with evidence while preserving read-only/destructive boundaries.

## Required Inputs (from execution lanes)

1. Wave completion receipts (run keys).
2. Changed-file list per wave.
3. Guard outputs (`verify.core.run`, `gaps.status`).
4. Evidence pointers under `mailroom/outbox/reports/hardware-plane-audit/2026-02-27/`.

## Gap Update Policy

- keep gaps `open` until operator acceptance
- no unsupported status values
- no freetext “tracked separately”; use structured successor references

### Target Gap Set

- `GAP-OP-1036`
- `GAP-OP-1047`
- `GAP-OP-1048`
- `GAP-OP-1049`

## Gap Notes Template

Use this exact notes block pattern in `ops/bindings/operational.gaps.yaml`:

```text
Implemented in orchestration wave (pending operator acceptance):
- wave: H{N}
- loop: LOOP-INFRA-HARDWARE-PLANE-AUDIT-20260227
- commit: <sha>
- verify_core: <run-key>
- gaps_status: <run-key>
- evidence_path: mailroom/outbox/reports/hardware-plane-audit/2026-02-27/<file>
- destructive_actions: none
```

## Closure Contract (Do Not Skip)

A hardware/storage gap may only transition to fixed/closed when all are true:

1. evidence is linked in notes with concrete file/run-key references,
2. successor contract is satisfied (or no-followup justification is explicit),
3. no destructive action occurred without attestation gate,
4. relevant gate checks pass or are explicitly waived with policy evidence.

## Proposal Packaging

After all waves are green, package one governance proposal containing:

1. updated `ops/bindings/operational.gaps.yaml` notes,
2. updated audit/governance documents,
3. wave execution receipt summary doc.

Suggested proposal title:
`hardware-plane-governance-wave-closeout-20260227`

## Execution Receipt Document

Recommended file:
`docs/planning/HARDWARE_PLANE_WAVE_EXECUTION_RECEIPT_20260227.md`

Required sections:

1. wave summary table (`wave`, `commit`, `gap`, `verify run keys`)
2. evidence file map
3. unresolved blockers and successor requirements
4. acceptance decision block (operator-only)

## Operator Acceptance Gate

Only operator approval can promote these gaps to fixed/closed.
No automatic closure from subagent waves is permitted.
