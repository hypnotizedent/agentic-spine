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
- Phase 5 validation/certification: PASS (re-cert green after runtime/MCP parity alignment)

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
  - Runtime source alignment added:
    - `mint_deploy_status` mode (default)
    - `ssh_compose_ps` mode (target + compose_path from contract)

- `ops/capabilities.yaml`
  - Registered `verify.vertical_integration.parity_status`.

- `ops/bindings/capability_map.yaml`
  - Added map entry for `verify.vertical_integration.parity_status` (D67 parity).

- `.mcp.json`
  - Added MCP registrations:
    - `mint-pricing`
    - `mint-suppliers`

- `ops/bindings/mcp.runtime.contract.yaml`
  - Added optional codex MCP exposure markers for:
    - `mint-pricing`
    - `mint-suppliers`

## Certification Runs

- Initial fail set:
  - `CAP-20260217-161430__verify.core.run__R5wh19717` (PASS)
  - `CAP-20260217-161506__verify.domain.run__Rzdow21917` (PASS)
  - `CAP-20260217-161516__proposals.status__Rbv5q28187` (PASS)
  - `CAP-20260217-161517__gaps.status__Rvh8s28663` (PASS)
  - `CAP-20260217-161517__verify.vertical_integration.parity_status__R2jtb9716` (overall FAIL)
- Re-cert green set:
  - `CAP-20260217-162619__verify.core.run__Rq5ey38961` (PASS)
  - `CAP-20260217-162656__verify.domain.run__Re2kn51234` (PASS)
  - `CAP-20260217-162706__verify.vertical_integration.parity_status__Rbcc757531` (overall PASS)
  - `CAP-20260217-162712__proposals.status__R75ht57752` (PASS)
  - `CAP-20260217-162713__gaps.status__R5auj38960` (PASS)

## Re-cert Result

Parity capability result (`CAP-20260217-162706__verify.vertical_integration.parity_status__Rbcc757531`):

- pricing: PASS across all dimensions
- suppliers: PASS across all dimensions
- overall: PASS

## Gap/Loop Closeout

- `GAP-OP-640`: eligible for closeout (green cert achieved).
- `LOOP-VERTICAL-INTEGRATION-AUTOMATION-V1-20260217`: remains active until gap close mutation is applied and recorded.
