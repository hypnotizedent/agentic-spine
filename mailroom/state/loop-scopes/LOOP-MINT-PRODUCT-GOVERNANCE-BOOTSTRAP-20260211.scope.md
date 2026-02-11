---
status: proposed
owner: "@ronny"
last_verified: 2026-02-11
scope: loop-scope
loop_id: LOOP-MINT-PRODUCT-GOVERNANCE-BOOTSTRAP-20260211
---

# Loop Scope: LOOP-MINT-PRODUCT-GOVERNANCE-BOOTSTRAP-20260211

## Goal

Establish canonical product governance primitives so that mint-os module
extraction can proceed predictably with no dual authority and no legacy
blackhole drift.

## Context

- mint-modules repo has 3 modules: artwork (ready), quote-page (conditional), order-intake (spec only)
- All modules deploy to docker-host (VM 200) — legacy host, no cloud-init
- Secrets are overloaded in mint-os-api Infisical project (55 keys)
- No module ownership model, no API versioning, no data boundary enforcement
- Legacy ronny-ops has 30 EXTRACT_NOW knowledge artifacts (no file copying)

## Success Criteria

1. `docs/governance/MINT_PRODUCT_GOVERNANCE.md` exists and is reviewed
2. Module ownership declared in SERVICE_REGISTRY for artwork + quote-page
3. Infisical namespaces created: `/spine/services/artwork/`, `/spine/services/quote-page/`
4. Data ownership boundaries documented (which module owns which tables)
5. API contract rules documented
6. spine.verify PASS after all changes

## Phases

### P0: Governance Framework
- [ ] Create MINT_PRODUCT_GOVERNANCE.md
- [ ] Add `owner` + `module` annotations to SERVICE_REGISTRY entries
- [ ] Create Infisical namespace folders
- [ ] Register GAP-OP-105 (secrets overload), GAP-OP-106 (no ownership model), GAP-OP-107 (no API versioning)

### P1: Artwork Sprint (parallel)
- [ ] Phase 1 presigned URL endpoints
- [ ] Verify pack green
- [ ] Deploy with governance gate checks

### P2: Quote-Page Hygiene (parallel with P1)
- [ ] Fix dist/ gitignore
- [ ] Add vitest + health test
- [ ] Add CI workflow

### P3: Order-Intake Decision
- [ ] Select architecture (A/B/C)
- [ ] Scaffold module

## Gap Registrations

- GAP-OP-105: Mint-os secrets namespace overloaded
- GAP-OP-106: No product-level module ownership model
- GAP-OP-107: No API contract versioning governance

## Receipts
- (link receipts here after work begins)

## Deferred / Follow-ups
- Dedicated VM for mint-modules (decouple from docker-host)
- MCP tool enablement policy (5 blocked tools)
- Cross-module drift gate
- Product-level release process
