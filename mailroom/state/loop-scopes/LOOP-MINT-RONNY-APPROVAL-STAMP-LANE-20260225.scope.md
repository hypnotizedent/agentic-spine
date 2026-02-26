---
loop_id: LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225
created: 2026-02-25
status: closed
owner: "@ronny"
scope: mint
severity: critical
objective: Establish Ronny-only approval stamps for built mint modules and prevent unapproved "works/live" claims
---

# Loop Scope: LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225

## Problem Statement

Audit outputs contain mixed "live/pass" claims while operator policy says only one
flow is trusted today (quote form submission -> Ronny email -> MinIO files).
Without a stamp lane, unverified behavior is repeatedly treated as live truth.

## Deliverables

1. Build a Ronny stamp matrix for currently built surfaces/modules only.
2. Define per-surface test scripts and expected outcomes for operator execution.
3. Mark each surface as one of: `APPROVED_BY_RONNY`, `BUILT_NOT_STAMPED`,
   `NOT_BUILT` (explicit defer).
4. Publish one short "claim policy" note: no "works/live" language without stamp.

## Acceptance Criteria

1. Matrix includes built components only:
   `artwork/files-api`, `quote-page`, `order-intake`, `pricing`, `suppliers`,
   `shipping`, `finance-adapter`, `payment`, `shopify-module`, `digital-proofs`.
2. Each built component has:
   test steps, run key(s), and stamp status.
3. Only the currently proven baseline is stamped live until Ronny executes new
   tests.
4. No item in loop output uses "works/live" without `APPROVED_BY_RONNY`.

## Constraints

1. Defer auth work.
2. Defer unbuilt capabilities.
3. No implementation changes; evidence and gating only.
4. No legacy docker-host behavior may be used as proof of spine-native live state.

## Execution Closeout (2026-02-26)

Canonical artifact:
- `/Users/ronnyworks/code/agentic-spine/docs/planning/MINT_RONNY_STAMP_MATRIX_20260225.md`

Evidence pack referenced by matrix:
- `CAP-20260226-023620__mint.modules.health__Rj6b460582`
- `CAP-20260226-023620__mint.deploy.status__Rsfpf60583`
- `CAP-20260226-023620__mint.runtime.proof__Rhfbl60584`
- `CAP-20260226-023620__mint.live.baseline.status__R12yz60585`

Validation closeout:
- `CAP-20260226-023752__verify.pack.run__Rligl92135` (mint pack pass 22/22)
- `CAP-20260226-023752__gaps.status__R95ki92137`

Acceptance result:
1. Built-component matrix published for all required surfaces: met.
2. Test script + run-key evidence fields populated: met.
3. Only quote baseline remains `APPROVED_BY_RONNY`: met.
4. Unstamped components blocked from live/works claims via strict policy text: met.
