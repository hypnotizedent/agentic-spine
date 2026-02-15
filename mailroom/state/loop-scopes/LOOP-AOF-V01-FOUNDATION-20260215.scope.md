---
loop_id: LOOP-AOF-V01-FOUNDATION-20260215
created: 2026-02-15
status: active
owner: "@ronny"
scope: agentic-spine
objective: Establish AOF v0.1 product foundation — 5 artifacts, 1 drift gate (D91), 2 tenant capabilities
---

# Loop Scope: AOF v0.1 Foundation

## Problem Statement

The Agentic Operations Framework (AOF) lacks productization artifacts: no product contract,
no tenant profile schema, no policy presets, no deployment playbook, no support SLO.
Without these, AOF cannot be packaged, deployed, or supported as a product.

## Deliverables

1. **Product contract** — `docs/product/AOF_PRODUCT_CONTRACT.md`
2. **Tenant profile schema** — `ops/bindings/tenant.profile.schema.yaml`
3. **Policy presets** — `ops/bindings/policy.presets.yaml`
4. **Deployment playbook** — `docs/product/AOF_DEPLOYMENT_PLAYBOOK.md`
5. **Support SLO** — `docs/product/AOF_SUPPORT_SLO.md`
6. **D91 hardening gate** — `surfaces/verify/d91-aof-product-foundation-lock.sh`
7. **tenant.profile.validate capability** — read-only schema validation
8. **tenant.provision.dry-run capability** — deterministic provisioning plan

## Child Gaps

| Gap ID | Description | Doc |
|--------|-------------|-----|
| GAP-OP-324 | AOF product contract missing | docs/product/AOF_PRODUCT_CONTRACT.md |
| GAP-OP-325 | Tenant profile schema missing | ops/bindings/tenant.profile.schema.yaml |
| GAP-OP-326 | Policy presets missing | ops/bindings/policy.presets.yaml |
| GAP-OP-327 | Deployment playbook missing | docs/product/AOF_DEPLOYMENT_PLAYBOOK.md |
| GAP-OP-328 | Support SLO missing | docs/product/AOF_SUPPORT_SLO.md |

## Phases

- Phase 0: Baseline + ID allocation (read-only)
- Phase 1: Open loop + file/claim 5 child gaps
- Phase 2: Implement artifacts (Lane D: docs, Lane E: bindings, Lane F: capabilities)
- Phase 3: D91 hardening gate + tests
- Phase 4: Index/registry wiring
- Phase 5: Verify, close gaps, close loop

## Constraints

- Do not touch GAP-OP-308 / LOOP-RAG-REINDEX-EXECUTION-20260215
- Governed workflow only (gaps.file/claim/close, receipts, verify)
