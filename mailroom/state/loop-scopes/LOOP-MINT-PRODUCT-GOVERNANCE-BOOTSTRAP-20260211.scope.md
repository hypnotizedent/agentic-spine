---
status: closed
owner: "@ronny"
created: 2026-02-11
closed: 2026-02-11
scope: loop-scope
loop_id: LOOP-MINT-PRODUCT-GOVERNANCE-BOOTSTRAP-20260211
severity: medium
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

## Acceptance Criteria

1. Gate A — Module ownership contract: MINT_PRODUCT_GOVERNANCE.md section 2 complete with ownership table
2. Gate B — API versioning contract: MINT_PRODUCT_GOVERNANCE.md section 3 complete with versioning policy
3. Gate C — Secrets namespace split: dedicated `/spine/services/artwork/` and `/spine/services/quote-page/` in secrets.namespace.policy.yaml
4. GAP-OP-105/106/107 registered in operational.gaps.yaml
5. spine.verify PASS after all changes

## Phases

| Phase | Scope | Status | Commit/Proposal |
|-------|-------|--------|-----------------|
| P0 | Intake + baseline + apply existing proposal | DONE | CP-20260211T213000Z / 5b19d4d |
| P1 | Establish 3 mandatory governance gates | DONE | CP-20260211-164800 / 9efbed5 |
| P1.1 | D60 deprecation fix | DONE | aff52c3 |
| P2 | Register governance checks + acceptance criteria | DONE | (merged with P1) |
| P3 | Validation | DONE | spine.verify PASS D1-D69 |
| P4 | Closeout | DONE | (this commit) |

## Registered Gaps

- GAP-OP-105: Mint-os secrets namespace overloaded — **open** (runtime migration deferred)
- GAP-OP-106: No product-level module ownership model — **fixed** (MINT_PRODUCT_GOVERNANCE.md section 2)
- GAP-OP-107: No API contract versioning governance — **fixed** (MINT_PRODUCT_GOVERNANCE.md section 3)

## P3 Validation Evidence

**spine.verify**: PASS D1-D69
**gaps.status**: 105 total, 2 open (GAP-OP-037 baseline + GAP-OP-105 intentional), 0 orphans
**vm.governance.audit**: 10/10 VMs governed, 0 gaps
**ops status**: 3 loops (2 baseline + this), 2 gaps (both parented)

Receipt IDs:
- CAP-20260211-165202__spine.verify__R6pw175594
- CAP-20260211-165233__gaps.status__Rpim783586
- CAP-20260211-165236__vm.governance.audit__Rycmm83656

## Receipts

- CP-20260211T213000Z applied: 5b19d4d (P0)
- CP-20260211-164800 applied: 9efbed5 (P1)
- CAP-20260211-164538__spine.verify__Rv8b758762 (P0 baseline)
- CAP-20260211-165202__spine.verify__R6pw175594 (P3 validation)

## Deferred / Follow-ups

- Dedicated VM for mint-modules (decouple from docker-host)
- MCP tool enablement policy (5 blocked tools)
- Cross-module drift gate
- Product-level release process
- GAP-OP-105 runtime fix (Infisical namespace creation + key migration)
