# Legacy Extraction Dispatch — Session Prompt (V2)

> **Date:** 2026-02-22
> **Supersedes:** LEGACY_EXTRACTION_DISPATCH_PROMPT_20260222.md (V1 had stale state assumptions)
> **Input docs:** Listed in Required Reads below

---

## Boot Sequence

```bash
cd ~/code/agentic-spine
./bin/ops status
./bin/ops cap list
./bin/ops cap run stability.control.snapshot
./bin/ops cap run verify.core.run
```

## Required Reads (do ALL before any work)

**Spine planning (~/code/agentic-spine/docs/planning/):**
1. `MINT_PRINTS_FLOW_REPLACEMENT_ROADMAP_20260222.md` — Decision lock + 6-phase sequence
2. `MINT_ROADMAP_20260222.md` — Control-writer consolidated state + canonical status table
3. `LEGACY_DELTA_AUDIT_20260222.md` — 25 LEG items from legacy audit
4. `MINT_FRESH_SLATE_INFRA_BOOTSTRAP_RUNBOOK.md` — VM provisioning (already executed for VMs 212/213)

**Mint-modules (~/code/mint-modules/):**
5. `docs/PLANNING/MINT_MODULE_EXECUTION_QUEUE.md` — Existing ranked queue: pricing→shipping→suppliers→integration
6. `docs/PLANNING/MINT_FRESH_SLATE_MASTER_PLAN.md` — V1 scope lock + phase order
7. `docs/ARCHITECTURE/V1_SCOPE_AND_ROUTE_CANON.md` — DNB list + V1 boundary
8. `docs/ARCHITECTURE/DATABASE_OWNERSHIP.md` — Current table ownership

**Legacy (~/ronny-ops/ — READ-ONLY, never edit):**
9. Read files as needed per contract scope. Reference file:line, never paste >100 lines.

---

## Current State (Corrected — Do Not Assume Otherwise)

| Fact | State | Evidence |
|------|-------|---------|
| Fresh-slate VMs | Healthy: mint-data (212) 3/3, mint-apps (213) 7/7 | CAP-20260221 stability snapshot |
| V1 modules | artwork (Phase 1.5, real code), quote-page (bootstrapped), order-intake (library + e2e) | mint-modules READMEs |
| Rank 1-3 modules | pricing, shipping, suppliers = SCAFFOLDED ONLY (empty Express boilerplate, no implementation) | Module index.ts files are hello-world |
| Route cutover | 2/14 done (pricing.mintprints.co, shipping.mintprints.co) — routes point to empty shells | Tunnel ingress cap |
| Legacy hold | Declared Feb 22 → May 23 (90 days), prerequisites NOT all met | MINT_ROADMAP canonical status table |
| Execution queue | Exists and is authoritative, 5-gate model, Ranks 1-4 + finance parallel track | MINT_MODULE_EXECUTION_QUEUE.md |
| V1 scope | Quote-form only (artwork + quote-page + order-intake). All else is DNB. | V1_SCOPE_AND_ROUTE_CANON.md |
| Auth/Payment/Notification | Zero fresh-slate replacement exists. UNVERIFIED by pre-ship receipt. | Pre-ship verify receipt from 20260221 |

---

## Mission

You are producing Gate 1 (CONTRACT) artifacts that extend the existing execution queue. You are NOT writing code, NOT modifying infrastructure, NOT changing the V1 scope.

The execution queue already has Ranks 1-4 (pricing, shipping, suppliers, integration gate) + finance parallel track. Your job is to add the LEG items from the legacy audit as Ranks 5+ and infrastructure plans, following the exact same 5-gate template.

---

## Phase 0: Pre-Ship Fixes (Roadmap Cleanup)

The pre-ship verify receipt found 5 issues in MINT_ROADMAP_20260222.md. Fix these first:

1. **0/14 vs 2/14 ambiguity** — The "scope" section says 0/14 as a starting-point description, but current state is 2/14. Add a clarifying note or reword to prevent misreading.

2. **D148 blocker** — Listed as P0 blocker but latest verify shows D148 PASS. Update or remove with evidence key: `CAP-20260221-232336__verify.core.run__Rkqa054468`

3. **Evidence key refresh** — Update canonical status table evidence_run_key columns with latest:
   - stability: `CAP-20260221-232156__stability.control.snapshot__R8sk420819`
   - core verify: `CAP-20260221-232336__verify.core.run__Rkqa054468`
   - pack verify: `CAP-20260221-232512__verify.pack.run__Ryc5d87703`
   - tunnel: `CAP-20260221-233000__cloudflare.tunnel.ingress.status__Rlx4x23082`
   - gaps: `CAP-20260221-233137__gaps.status__Rg0ae25574`

4. **Auth/Payment/Notification evidence** — Run these and tag results into the roadmap:
   ```bash
   ./bin/ops cap run rag.anythingllm.ask "What fresh-slate auth service currently replaces legacy JWT/PIN/admin session paths for Mint, and where is it deployed?"
   ./bin/ops cap run rag.anythingllm.ask "What fresh-slate Stripe checkout/webhook/payment-table replacement exists for Mint, including stack and route?"
   ./bin/ops cap run n8n.workflows.get 3TPTDi1xzs0PXuqX
   ```

5. **Loop progress syntax** — Fix any references to bare `loops.progress`; correct syntax is `./bin/ops cap run loops.progress --loop <LOOP_ID>`

Submit as one proposal:
```bash
./bin/ops cap run proposals.submit "Roadmap pre-ship fixes from verify receipt 20260221"
```

---

## Phase 1: Table Ownership Audit

**Loop:** `LOOP-MINT-TABLE-OWNERSHIP-AUDIT`

This is the keystone artifact that feeds every downstream contract.

**Read:**
- `~/ronny-ops/mint-os/apps/api/migrations/` — all SQL files
- `~/code/mint-modules/artwork/db/` or `*/migrations/` — all mint migration files
- `~/code/mint-modules/docs/ARCHITECTURE/DATABASE_OWNERSHIP.md` — existing ownership doc

**Important:** The existing DATABASE_OWNERSHIP.md already declares some ownership. Do NOT contradict it. Extend it with legacy tables not yet classified.

**For each legacy table, classify:**
- `mint-owned` — already in mint-modules DB, migration exists
- `legacy-only` — only legacy uses it, migration needed before cutover
- `shared` — both legacy and mint read; only one writes
- `deprecated` — Printavo artifacts, unused tables
- `UNKNOWN` — cannot determine from file evidence alone

**For shared tables:** Note which module reads vs writes and whether the current DATABASE_OWNERSHIP.md already covers it.

**Output:** `docs/planning/MINT_TABLE_OWNERSHIP_MAP.md`

**Structure:**
```markdown
## Extends: mint-modules/docs/ARCHITECTURE/DATABASE_OWNERSHIP.md

## New Classifications (tables not in existing ownership doc)
| table | classification | current_writer | target_owner | FK_dependencies | evidence |

## Conflict Check
[Any table claimed by >1 planned module — STOP and flag, do not resolve]

## Migration Dependency Order
[Topological sort based on FK chains — which tables must migrate first]
```

Submit: `./bin/ops cap run proposals.submit "Table ownership map extending DATABASE_OWNERSHIP.md"`

---

## Phase 2: Module Extraction Contracts (Track A)

These extend the execution queue as Rank 5+. Each follows the SAME 5-gate template from MINT_MODULE_EXECUTION_QUEUE.md.

**Critical rule:** Check what's already in the queue before writing. Do not duplicate Ranks 1-4 (pricing, shipping, suppliers, integration gate) or the finance parallel track. Only add genuinely new items.

### Contract 5: LOOP-MINT-AUTH-PHASE0-CONTRACT

**Read from legacy:**
- `~/ronny-ops/mint-os/apps/api/routes/auth.cjs` — Customer JWT
- `~/ronny-ops/mint-os/apps/api/routes/admin-auth.cjs` — Admin sessions
- `~/ronny-ops/mint-os/apps/api/lib/` — any auth/session helpers
- Production portal PIN auth (find in `apps/production/`)

**Cross-reference:**
- MINT_ROADMAP canonical status table item `DOMAIN-AUTH-EXTRACTION` (status: blocked)
- Roadmap decision: "Port legacy JWT model into fresh-slate"

**Contract must answer:**
1. Is this 1 module or 2? (customer auth vs admin auth vs PIN auth)
2. Table ownership: `dashboard_admins`, `dashboard_admin_sessions` — who owns post-extraction?
3. Secrets: What keys move to what Infisical namespace?
4. API surface: What endpoints does fresh-slate auth expose?
5. What does V1 (quote-form) need from auth? (Maybe nothing — quote-page is public)
6. What does Rank 2 shipping need? (PIN auth replacement is listed as shipping prerequisite)

**Output:** `docs/planning/MINT_AUTH_CONTRACT_V1.md`

### Contract 6: LOOP-MINT-PAYMENT-PHASE0-CONTRACT

**Read from legacy:**
- `~/ronny-ops/mint-os/apps/api/lib/stripe.cjs` — Stripe client
- `~/ronny-ops/mint-os/apps/api/routes/stripe-webhooks.cjs` — Webhook handler
- `~/ronny-ops/mint-os/apps/api/routes/order-payments.cjs` — Payment CRUD
- `~/ronny-ops/mint-os/apps/api/routes/v2-checkout.cjs` — Checkout flow

**Cross-reference:**
- MINT_ROADMAP canonical status table item `DOMAIN-PAYMENT-EXTRACTION` (status: blocked)
- Roadmap decision: "Full Stripe/payment extraction into fresh-slate"

**Contract must answer:**
1. Webhook receiver: What events does legacy handle? What's the idempotency model?
2. Checkout: What's the deposit model (50%? configurable?)
3. Tables: Payment-related tables from ownership map — who owns?
4. Dependency on auth: Does checkout require customer auth? Admin auth?
5. Dependency on order-lifecycle: Can payments exist without order-lifecycle module?

**Output:** `docs/planning/MINT_PAYMENT_CONTRACT_V1.md`

### Contract 7: LOOP-MINT-NOTIFICATION-PHASE0-CONTRACT

**Read from legacy:**
- `~/ronny-ops/mint-os/apps/api/lib/email.cjs` — Resend client
- `~/ronny-ops/mint-os/apps/api/lib/twilio.cjs` — Twilio client
- `~/ronny-ops/mint-os/apps/api/routes/notifications.cjs` — Coordinator

**Run (get current spine comms-agent state):**
```bash
./bin/ops cap run communications.provider.status
```

**Cross-reference:**
- MINT_ROADMAP P0 blocker: "Provider readiness (Resend/Twilio env not live-ready)"
- MINT_ROADMAP P0 blocker: "Notification routing (P08, P10 still no-op)"
- Roadmap Phase B exit: "Quote submission produces seed + notification"

**Contract must answer:**
1. What events trigger notifications today? (Map: event → template → channel)
2. What does the spine communications-agent already cover vs. what's missing?
3. Is the gap: wiring (connect existing agent to events) or implementation (build new)?
4. What does Phase B need? (Just quote-created email? Or full lifecycle?)
5. Templates: Where do they live? Are they code or DB?

**Output:** `docs/planning/MINT_NOTIFICATION_CONTRACT_V1.md`

### Contract 8: LOOP-MINT-ORDER-LIFECYCLE-PHASE0-CONTRACT

**Read from legacy:**
- `~/ronny-ops/mint-os/apps/api/routes/v2-jobs.cjs` — 4,347 lines. SUMMARIZE. Do not paste. Extract: endpoint list, status transitions, table writes, external calls.

**Cross-reference:**
- `~/code/mint-modules/order-intake/` — what it already covers (contract validation only)
- Roadmap Phase C: "Extract order/payment/auth"
- DNB1 in V1_SCOPE_AND_ROUTE_CANON.md — "Legacy API Rewrite" prerequisites not met

**Contract must answer:**
1. What does order-intake already handle vs. what's the lifecycle gap?
2. How many of the 4,347 lines are active business logic vs. dead code vs. middleware?
3. Status transitions: What's the state machine? (Quote → Order → Production → Shipped → Closed)
4. External calls: What does v2-jobs call? (Stripe? Email? File system?)
5. Can this be phased? (Phase 1: CRUD + status. Phase 2: Line items + tax. Phase 3: Integrations.)

**Output:** `docs/planning/MINT_ORDER_LIFECYCLE_CONTRACT_V1.md`

---

## Phase 3: Infrastructure Plans (Track B)

### LOOP-MINT-TUNNEL-MIGRATION-CONTRACT

**Run:**
```bash
./bin/ops cap run cloudflare.tunnel.ingress.status
```

**Read:** `~/ronny-ops/infrastructure/cloudflare/tunnel/` config files

**Current state:** 2/14 routes cut over. 12 remaining.

**Produce:** Route-by-route migration plan with:
- Current target (legacy VM 200 service)
- New target (mint-apps VM 213 service + port)
- Prerequisites (which module must be at which gate before route can move)
- Suggested cutover order (group by dependency, not alphabetical)

**Output:** `docs/planning/MINT_TUNNEL_MIGRATION_PLAN.md`

### LOOP-MINT-SECRETS-BOOTSTRAP-CONTRACT

**Run:**
```bash
./bin/ops cap run secrets.projects.status
```

**Read (names only, NEVER values):**
- `~/ronny-ops/scripts/load-secrets.sh`
- `~/ronny-ops/scripts/sync-secrets-to-env.sh`
- List `.env` filenames across legacy

**Cross-reference:**
- ADR-003 (secrets project model): one project per module + shared infra
- `mint-modules/docs/DEPLOYMENT/MINT_MODULES_ENV_MATRIX.md` — existing env requirements
- Existing Infisical projects from secrets.projects.status output

**Produce:** Gap analysis: what Infisical projects exist vs. what's needed for each Rank 5+ module

**Output:** `docs/planning/MINT_SECRETS_BOOTSTRAP_PLAN.md`

---

## Phase 4: Update Execution Queue

After all contracts and plans exist:

1. Read current `~/code/mint-modules/docs/PLANNING/MINT_MODULE_EXECUTION_QUEUE.md`
2. **Do NOT modify Ranks 1-4 or the finance parallel track**
3. Append new entries as Rank 5+ following the exact same format:
   - Rank 5: Auth (blocks everything downstream)
   - Rank 6: Payment (depends on auth, blocks order-lifecycle)
   - Rank 7: Order Lifecycle (depends on auth + payment)
   - Rank 8: Notification Wiring (parallel, integrates with spine comms-agent)
   - Infrastructure items as parallel tracks (like finance)
4. Each entry references its contract doc and table ownership claims
5. Note: Rank 5+ cannot start Gate 2 until Ranks 1-3 complete their own Gate 1 contracts

Submit:
```bash
./bin/ops cap run proposals.submit "Execution queue Rank 5+ additions from legacy delta audit"
```

---

## Hard Rules

- `~/ronny-ops` is READ-ONLY. No edits, no commits, no file creation.
- All outputs go to `~/code/agentic-spine/docs/planning/` via `proposals.submit`.
- Every loop opened MUST close with a receipt via `./bin/ops`.
- If two contracts claim the same table, STOP. Flag the conflict in both contracts. Do not resolve — operator decides.
- Do not contradict existing DATABASE_OWNERSHIP.md, V1_SCOPE_AND_ROUTE_CANON.md, or MINT_MODULE_EXECUTION_QUEUE.md Ranks 1-4.
- Do not build anything in the DNB list (DNB1, DNB2, DNB3).
- Context budget: Summarize any file over 100 lines. Use file:line references, not full pastes.
- If uncertain about any classification, mark UNKNOWN with the exact evidence path you checked. Do not guess.
- Do not invent new governance patterns, loop naming conventions, or gate models. Use what exists.
