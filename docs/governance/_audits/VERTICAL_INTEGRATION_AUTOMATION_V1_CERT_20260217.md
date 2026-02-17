---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: vertical-integration-automation-v1-cert
parent_loop: LOOP-VERTICAL-INTEGRATION-AUTOMATION-V1-20260217
---

# Vertical Integration Automation V1 Certification (2026-02-17)

## Objective

Implement machine-enforced vertical integration admission/parity controls so pricing/suppliers module implementation changes cannot be applied without required companion exposure surfaces.

## Phase Outcome Summary

- Phase 0 preflight: PASS
- Phase 1 register loop + gap: PASS
- Phase 2 admission contract SSOT: PASS
- Phase 3 proposals.apply enforcement: PASS
- Phase 4 read-only parity capability: PASS
- Phase 5 validation/certification: FAIL (parity capability overall FAIL)

## Implemented Artifacts

- `ops/bindings/vertical.integration.admission.contract.yaml`
  - Required-change matrix for:
    - `mint-modules/pricing/**`
    - `mint-modules/suppliers/**`
  - Companion surface requirements:
    - deploy/runtime surface
    - MCP exposure surface
    - health/readiness surface
    - docs/contracts reference surface
  - Manifest requirements:
    - `loop_id` required
    - `changes` non-empty required
    - explicit `not-required` override + reason support
  - Block condition: `P0/P1` block `proposals.apply`

- `ops/plugins/proposals/bin/proposals-apply`
  - Added vertical integration admission evaluation against contract matrix.
  - Blocks apply on contract-generated `P0/P1` findings with actionable fix text.
  - No-op for proposals that do not touch matrix trigger paths.

- `ops/plugins/verify/bin/vertical-integration-parity-status`
  - Read-only parity status for pricing/suppliers across dimensions:
    - code surface
    - runtime container state
    - endpoint health
    - MCP exposure
    - docs/contracts references

- `ops/capabilities.yaml`
  - Registered `verify.vertical_integration.parity_status`.

- `ops/bindings/capability_map.yaml`
  - Added map entry for `verify.vertical_integration.parity_status` (D67 parity).

## Certification Runs

- `CAP-20260217-161430__verify.core.run__R5wh19717` (PASS)
- `CAP-20260217-161506__verify.domain.run__Rzdow21917` (PASS)
- `CAP-20260217-161516__proposals.status__Rbv5q28187` (PASS)
- `CAP-20260217-161517__gaps.status__Rvh8s28663` (PASS)
- `CAP-20260217-161517__verify.vertical_integration.parity_status__R2jtb9716` (overall FAIL)

## Cert Blockers

Parity capability result:

- pricing:
  - runtime container state: FAIL (expected containers not found)
  - MCP exposure: FAIL (required markers absent)
- suppliers:
  - runtime container state: FAIL (expected containers not found)
  - MCP exposure: FAIL (required markers absent)

Green criteria not met. `GAP-OP-640` remains open with blocker note.

## Gap/Loop Closeout

- `GAP-OP-640`: kept open (cert not green).
- `LOOP-VERTICAL-INTEGRATION-AUTOMATION-V1-20260217`: remains active pending parity blockers.

