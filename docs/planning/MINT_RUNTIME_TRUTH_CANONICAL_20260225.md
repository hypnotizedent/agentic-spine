---
status: authoritative
owner: "@ronny"
created: 2026-02-25
scope: mint-runtime-truth-canonical
authority: LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225
---

# Mint Runtime Truth Canonical (2026-02-25)

## Trusted Baseline

Only this flow is currently trusted as live truth:
1. Quote form submit
2. Ronny receives email
3. Files visible in MinIO

Everything else remains non-live until `APPROVED_BY_RONNY` with run-key evidence.

## Claim Status Taxonomy

Use only these values in Mint planning/runtime docs:
1. `APPROVED_BY_RONNY`
2. `BUILT_NOT_STAMPED`
3. `CONTRACT_ONLY`
4. `LEGACY_ONLY`
5. `NOT_BUILT`

## Live-Claim Rule

No module or workflow may be described as "live", "working", or "verified" unless:
1. a run key is cited, and
2. Ronny stamp evidence is present.

## Runtime Authority Boundary

1. Fresh-slate runtime truth: `mint-apps` + `mint-data`.
2. Legacy runtime: `docker-host` is `LEGACY_ONLY`, non-authoritative for module truth.
3. Legacy source reference: `/Users/ronnyworks/ronny-ops` is reference-only and never runtime truth.

## Required Cross-References

The following docs must reference this canonical runtime truth:
1. `mint-modules/docs/ARCHITECTURE/MINT_TRANSITION_STATE.md`
2. `mint-modules/docs/PLANNING/MINT_ORDER_AGENT_ROADMAP_SSOT.md`
3. `mint-modules/docs/PLANNING/MINT_MODULE_EXECUTION_QUEUE.md`
4. `agentic-spine/docs/planning/MINT_CLEANUP_EXECUTION_MAP_20260225.md`
