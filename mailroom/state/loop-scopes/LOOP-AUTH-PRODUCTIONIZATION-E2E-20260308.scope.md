---
loop_id: LOOP-AUTH-PRODUCTIONIZATION-E2E-20260308
created: 2026-03-08
status: active
owner: "@ronny"
scope: auth
priority: medium
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Productionize auth module: replace in-memory storage with PostgreSQL persistence, add governed secrets/deploy, resolve schema mismatches, re-prove customer portal + artwork flow with persistent auth, remove all proof-only drift
---

# Loop Scope: LOOP-AUTH-PRODUCTIONIZATION-E2E-20260308

## Objective

Productionize auth module: replace in-memory storage with PostgreSQL persistence, add governed secrets/deploy, resolve schema mismatches, re-prove customer portal + artwork flow with persistent auth, remove all proof-only drift

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-AUTH-PRODUCTIONIZATION-E2E-20260308`

## Phases

### Lane A: Auth Persistence Architecture + Implementation
- Replace in-memory store.ts with PostgreSQL backend
- Define persistent schema (customers, admins, employees)
- Implement persistence layer with clean API contract
- Add migrations/bootstrap
- Add tests for persistence-backed flows

### Lane B: Secrets/Runtime Wiring/Deploy
- Define canonical auth secret namespace in Spine
- Add required secrets/runtime env mappings
- Update deploy surfaces for mint-apps
- Deploy auth to live runtime via canonical promotion
- Verify health and runtime proof

### Lane C: Artwork/Portal Schema + Contract Alignment
- Resolve entity_id UUID/TEXT mismatch
- Ensure customer artwork v1 contract integrity
- Align customer portal auth model with live auth service
- Fix query/typing/schema mismatches

### Lane D: Live End-to-End Proof
- Create/login real test customer through persistent auth
- Verify JWT issuance and portal authentication
- Prove customer-scoped artwork list
- Prove authorized download succeeds
- Prove cross-customer download returns 403
- Prove restart persistence (auth state survives)

### Lane E: Cleanup/Tombstone Proof-Only Drift
- Remove proof-only auth runtime artifacts
- Remove sensitive proof receipts
- Demote/remove docs implying proof-only auth is canonical
- Update portal/artwork/auth docs for single source of truth

## Success Criteria
- Auth service uses PostgreSQL persistence (no in-memory storage)
- Auth deployed to mint-apps via canonical governed path
- Customer portal + artwork flow proven live with persistent auth
- Auth state survives container restart
- Customer-scoped artwork list working
- Authorized download working with presigned URLs
- Cross-customer download blocked with 403
- entity_id schema mismatch resolved
- No proof-only runtime artifacts remain
- No sensitive proof receipts in docs
- mint.deploy.status, mint.modules.health, mint.runtime.proof all healthy

## Definition Of Done
- All 5 lanes (A-E) complete with receipts
- Persistent auth data survives restart (proven)
- Live auth issues valid customer JWTs
- Customer portal login/signup works against persistent auth
- Artwork list is customer-scoped
- Own download works, cross-customer download is 403
- No stale proof-only docs/runtime remain active
- Final closure receipt written
- Status: AUTH_PRODUCTIONIZATION_COMPLETE
