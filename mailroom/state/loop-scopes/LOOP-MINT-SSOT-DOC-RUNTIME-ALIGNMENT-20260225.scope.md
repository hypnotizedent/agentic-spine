---
loop_id: LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225
created: 2026-02-25
status: closed
owner: "@ronny"
scope: mint
severity: high
objective: Align mint docs with current runtime truth and remove conflicting authoritative claims
---

# Loop Scope: LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225

## Problem Statement

Multiple SSOT and audit drafts now exist with conflicting runtime statements.
Without a single aligned narrative, operators and agents repeatedly re-open the
same decisions and misclassify legacy vs spine-native behavior.

## Deliverables

1. Create one authoritative Mint runtime truth statement with:
   trusted baseline, untrusted surfaces, and explicit defers.
2. Reconcile conflicting docs by adding cross-references and deprecation notes.
3. Add strict language rule: no "LIVE_VERIFIED" label without run key + Ronny
   stamp.
4. Publish "Current Contract vs Needed Contract" table for built-only lanes.

## Acceptance Criteria

1. One canonical doc is declared for operator runtime truth.
2. Existing roadmap/transition docs point to that canonical source.
3. Legacy references are clearly tagged non-runtime-truth.
4. No doc claims unsupported end-to-end live capability.

## Constraints

1. Documentation and governance alignment only.
2. No feature implementation.
3. Defer auth and all unbuilt module claims.

