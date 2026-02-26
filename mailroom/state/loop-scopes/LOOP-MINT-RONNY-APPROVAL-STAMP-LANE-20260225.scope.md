---
loop_id: LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225
created: 2026-02-25
status: active
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

