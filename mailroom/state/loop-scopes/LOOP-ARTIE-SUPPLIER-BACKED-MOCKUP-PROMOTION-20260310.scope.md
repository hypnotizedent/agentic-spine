---
loop_id: LOOP-ARTIE-SUPPLIER-BACKED-MOCKUP-PROMOTION-20260310
created: 2026-03-10
status: active
owner: "@ronny"
scope: artie
priority: medium
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Build supplier-backed mockup promotion and exact resolved-blank proof flow without duplicating supplier truth
---

# Loop Scope: LOOP-ARTIE-SUPPLIER-BACKED-MOCKUP-PROMOTION-20260310

## Objective

Build supplier-backed mockup promotion and exact resolved-blank proof flow without duplicating supplier truth

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-ARTIE-SUPPLIER-BACKED-MOCKUP-PROMOTION-20260310`

## Context

**Problem**: Artie (digital-proofs) currently does fuzzy supplier search to choose blanks for proofing, which duplicates supplier truth that already exists in quote packet line items after normalization + sourcing.

**Architectural rule**: Suppliers decide what the blank is. Artie decides how to proof it. Quote packets decide when that proof is allowed and what it belongs to.

**Current gaps**:
1. Mockup registry (artie.mockup.assets.yaml) lacks supplier provenance — no way to track where curated assets came from
2. No promotion path from supplier images → approved registry assets
3. digital-proofs still does fuzzy supplier search even when line item already has exact supplier_code + supplier_sku

**Target architecture**:
- Quote packet line items carry resolved supplier blank identity (supplier_code, supplier_sku, style_code, brand, color)
- Mockup registry is **downstream of suppliers**, stores approved proof-safe assets with supplier provenance
- Artie consumes exact resolved blank from packet, asks registry for approved asset, falls back to supplier image if allowed

## Lanes

### Lane A: Mockup Registry Supplier Provenance (schema)
**Owner**: TBD (subagent)
**Scope**: Extend artie.mockup.assets.yaml schema with supplier provenance tracking
**Deliverables**:
- Add supplier provenance fields: `source_url`, `supplier_product_id`, `promoted_from_supplier`, `promoted_at`
- Add approval workflow fields: `approval_state` (approved/review/deprecated), `approved_by`, `override_reason`
- Update existing 5 assets with provenance (mark as curated, not supplier-promoted)
- Update fallback policy to clarify supplier image use vs registry-required states
- Update schema documentation

### Lane B: Supplier Asset Promotion Capability (runtime)
**Owner**: TBD (subagent)
**Scope**: Build capability to promote supplier images into mockup registry
**Deliverables**:
- New capability: `artie.mockup.asset.promote`
- Inputs: supplier_code, supplier_sku, view, approval_state (approved/review)
- Reads supplier product image from suppliers module API
- Creates registry entry with full provenance
- Validates no duplicate entries exist
- Supports batch promotion for style families
- Safety: mutating, approval: manual (for approved state)

### Lane C: Artie Exact Resolved-Blank Proof Flow (refactor)
**Owner**: TBD (subagent)
**Scope**: Refactor digital-proofs to consume exact resolved blank from quote packet
**Deliverables**:
- Split proof modes in intake.ts: `draft_preview` vs `resolved_blank_proof`
- `resolved_blank_proof` mode requires exact supplier_code + supplier_sku (no fuzzy search)
- Reads mockup registry first for approved asset
- Falls back to supplier primary_image_url only if fallback_policy allows
- Update supplier-asset.ts to support exact lookup (not just fuzzy search)
- Remove heuristic family detection when supplier truth is already present
- Update digital-proofs contract to document both modes

## Phases
1. **Lane setup**: Create 3 worktrees, define scope boundaries
2. **Parallel execution**: All 3 lanes execute concurrently
3. **Integration**: Verify cross-lane contracts (schema → capability → proof flow)
4. **Verification**: Run verify pack, test E2E proof with resolved blank

## Success Criteria
- artie.mockup.assets.yaml v2 with supplier provenance fields
- artie.mockup.asset.promote capability operational
- digital-proofs supports resolved_blank_proof mode (exact supplier lookup)
- No duplication of supplier truth between suppliers module and Artie
- Mockup registry is downstream of suppliers (authority-first rule preserved)
- E2E test: quote packet with resolved blank → Artie proof uses exact supplier asset

## Definition Of Done
- All 3 lanes committed and merged
- Schema changes backward-compatible with existing 5 assets
- New capability wired in capabilities.yaml + capability_map.yaml
- digital-proofs refactor preserves draft_preview for pre-resolution use cases
- Verify pack passes (mint domain if exists, or fast)
- Loop closed with 0 open gaps
