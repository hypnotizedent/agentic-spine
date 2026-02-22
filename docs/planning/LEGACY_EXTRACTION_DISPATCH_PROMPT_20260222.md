# Legacy Extraction Dispatch — Session Prompt

> **Date:** 2026-02-22
> **Input:** `LEGACY_DELTA_AUDIT_20260222.md` (25 LEG items)
> **Constraint:** Read-only on legacy; write only to spine + mint-modules
> **Governance:** Follows existing 5-gate loop model, mailroom proposals, AOF standards

---

## The Parallelization Problem

The audit surfaced 25 LEG items. Doing them sequentially = 6+ months. But doing them in parallel without discipline = agent drift, conflicting writes, and governance violations.

**Solution: 3 parallel tracks, each with its own terminal role, each producing only Gate 1 (CONTRACT) artifacts. No agent touches code until contracts are approved.**

---

## Track Architecture

```
TRACK A: Module Extraction Contracts     ← extends existing MINT_MODULE_EXECUTION_QUEUE
TRACK B: Infrastructure Boundary Docs    ← extends MINT_FRESH_SLATE_INFRA_BOOTSTRAP_RUNBOOK
TRACK C: Data Ownership Map              ← new artifact, feeds all other tracks

All 3 tracks:
  - Write to: agentic-spine/docs/planning/ (proposals via mailroom)
  - Read from: ronny-ops (read-only), mint-modules (read-only)
  - Produce: CONTRACT-grade docs only (Gate 1 of 5)
  - Close with: receipt via ./bin/ops
```

**Why this doesn't dilute the spine:**
- No new loop types — these are CONTRACT phases of loops that already have naming slots in the execution queue
- No new capability patterns — agents use existing `verify.*`, `rag.*`, and `proposals.submit`
- Mailroom-gated writes — nothing lands without operator apply
- Receipt-generating — every deliverable has an audit trail

---

## Track A: Module Extraction Contracts

**Terminal role:** `DEPLOY-MINT-01` (already defined in AGENTS.md)

**What it produces:** Gate 1 CONTRACT docs for LEG items that map to extractable modules.

**Scope (from audit):**

| Loop ID | LEG items covered | Contract deliverable |
|---------|-------------------|---------------------|
| `LOOP-MINT-AUTH-PHASE0-CONTRACT` | LEG-001 | `MINT_AUTH_CONTRACT_V1.md` |
| `LOOP-MINT-PAYMENT-PHASE0-CONTRACT` | LEG-002, LEG-003 | `MINT_PAYMENT_CONTRACT_V1.md` |
| `LOOP-MINT-ORDER-LIFECYCLE-PHASE0-CONTRACT` | LEG-004 | `MINT_ORDER_LIFECYCLE_CONTRACT_V1.md` |
| `LOOP-MINT-CUSTOMER-PHASE0-CONTRACT` | LEG-005 | `MINT_CUSTOMER_CONTRACT_V1.md` |
| `LOOP-MINT-NOTIFICATION-PHASE0-CONTRACT` | LEG-006 | `MINT_NOTIFICATION_CONTRACT_V1.md` |
| `LOOP-MINT-TIMEKEEPING-PHASE0-CONTRACT` | LEG-010 | `MINT_TIMEKEEPING_CONTRACT_V1.md` |

**Contract template (matches existing execution queue Gate 1):**

```markdown
# MINT_{MODULE}_CONTRACT_V1

## Boundary
- API surface (routes extracted, OpenAPI if available)
- Table ownership (which tables transfer, which stay shared)
- Secrets namespace (Infisical project + keys)
- Event emissions (what downstream modules need to know)

## Dependencies
- Upstream: what this module calls
- Downstream: what calls this module
- Shared: tables/services used by both this and legacy

## Acceptance Criteria (Gate 1 only)
1. Contract doc reviewed by operator
2. No table ownership conflicts with other contracts
3. Secrets namespace registered (not provisioned yet)

## Evidence
- Legacy source paths
- Line counts / complexity notes
- Known tech debt
```

**How to parallelize within Track A:** Each contract is independent at Gate 1. An agent can produce `MINT_AUTH_CONTRACT_V1.md` without waiting for `MINT_PAYMENT_CONTRACT_V1.md`. **But** the operator must review all contracts together before any proceeds to Gate 2 (SCHEMA), because table ownership conflicts only surface when contracts are compared side-by-side.

---

## Track B: Infrastructure Boundary Docs

**Terminal role:** `SPINE-CONTROL-01` (already defined in AGENTS.md)

**What it produces:** Infrastructure boundary definitions for LEG items that are infra/runtime concerns.

**Scope:**

| Loop ID | LEG items covered | Deliverable |
|---------|-------------------|-------------|
| `LOOP-MINT-TUNNEL-MIGRATION-CONTRACT` | LEG-014 | `MINT_TUNNEL_MIGRATION_PLAN.md` |
| `LOOP-MINT-SECRETS-BOOTSTRAP-CONTRACT` | LEG-015 | `MINT_SECRETS_BOOTSTRAP_PLAN.md` |
| `LOOP-MINT-MONITORING-CONTRACT` | LEG-017 | `MINT_MONITORING_PLAN.md` |
| `LOOP-MINT-OPS-AGENTS-CONTRACT` | LEG-018 | `MINT_OPS_AGENTS_PLAN.md` |
| `LOOP-MINT-N8N-STRATEGY-CONTRACT` | LEG-013 | `MINT_N8N_REPLACEMENT_STRATEGY.md` |
| `LOOP-MINT-CICD-CONTRACT` | LEG-019 (supplier runtime) | `MINT_SUPPLIER_RUNTIME_PLAN.md` |

**These extend the existing runbook** (`MINT_FRESH_SLATE_INFRA_BOOTSTRAP_RUNBOOK.md`) rather than creating parallel governance. Each plan references the runbook's 6-phase model and specifies which phases it adds steps to.

---

## Track C: Data Ownership Map

**Terminal role:** `SPINE-AUDIT-01` (read-only, observation)

**What it produces:** The definitive table ownership map (LEG-016, LEG-024).

**This is the keystone artifact.** Tracks A and B both need it, but it can be produced in parallel because it's purely observational — it reads the legacy DB schema and mint-modules migrations, then classifies every table.

**Deliverable:** `MINT_TABLE_OWNERSHIP_MAP.md`

```markdown
# Table Ownership Map

## Classification
| table | current_owner | target_owner | write_frequency | migration_strategy |
|-------|--------------|-------------|-----------------|-------------------|
| orders | legacy | mint-order-lifecycle | HIGH | dual-write → cutover |
| shipping_labels | shared | mint-shipping | MEDIUM | ownership transfer |
| artwork_seeds | mint-artwork | mint-artwork | HIGH | already migrated |
| ... | ... | ... | ... | ... |

## Conflict Detection
[Tables claimed by >1 contract → must resolve before Gate 2]

## Migration Dependency Graph
[Topological sort of table migrations based on FK relationships]
```

---

## The Prompt

Use this prompt to kick off execution. It's designed for a Claude Code session on the spine terminal:

---

```
You are operating under the agentic-spine governance model.

## Session Context
- Read: AGENTS.md (session protocol)
- Read: docs/planning/LEGACY_DELTA_AUDIT_20260222.md (the audit)
- Read: docs/planning/MINT_MODULE_EXECUTION_QUEUE.md (existing queue, via mint-modules)
- Read: docs/planning/MINT_PRINTS_FLOW_REPLACEMENT_ROADMAP_20260222.md (roadmap)
- Read: docs/planning/LEGACY_EXTRACTION_DISPATCH_PROMPT_20260222.md (this file)

## Mission
Produce Gate 1 (CONTRACT) artifacts for the legacy extraction.
You are NOT writing code. You are writing boundary contracts.

## Execution Order (parallelizable within each step)

### Step 1: Table Ownership Map (Track C — do this FIRST)
Open: LOOP-MINT-TABLE-OWNERSHIP-AUDIT
- Read every migration file in ronny-ops/mint-os/apps/api/migrations/
- Read every migration file in mint-modules/*/migrations/ or */db/
- Query evidence: which tables exist, FK relationships, column types
- Classify: mint-owned, legacy-only, shared, deprecated
- Output: docs/planning/MINT_TABLE_OWNERSHIP_MAP.md
- Submit via: ./bin/ops cap run proposals.submit "Table ownership map from legacy audit"

### Step 2: Module Contracts (Track A — parallel, after Step 1 draft exists)
For EACH of these, open the named loop and produce a CONTRACT doc:

1. LOOP-MINT-AUTH-PHASE0-CONTRACT
   - Read: ronny-ops routes/auth.cjs, routes/admin-auth.cjs
   - Define: JWT boundary, PIN auth boundary, admin session boundary
   - Reference: table ownership map for dashboard_admins, sessions
   - Output: docs/planning/MINT_AUTH_CONTRACT_V1.md

2. LOOP-MINT-PAYMENT-PHASE0-CONTRACT
   - Read: ronny-ops lib/stripe.cjs, routes/stripe-webhooks.cjs, routes/order-payments.cjs, routes/v2-checkout.cjs
   - Define: Stripe client boundary, webhook receiver, payment CRUD, checkout flow
   - Reference: table ownership map for payment-related tables
   - Output: docs/planning/MINT_PAYMENT_CONTRACT_V1.md

3. LOOP-MINT-NOTIFICATION-PHASE0-CONTRACT
   - Read: ronny-ops lib/email.cjs, lib/twilio.cjs, routes/notifications.cjs
   - Cross-reference: communications-agent MCP tools (spine level)
   - Define: event→template→channel mapping, gap vs spine comms-agent
   - Output: docs/planning/MINT_NOTIFICATION_CONTRACT_V1.md

4. LOOP-MINT-ORDER-LIFECYCLE-PHASE0-CONTRACT
   - Read: ronny-ops routes/v2-jobs.cjs (4,347 lines — summarize, don't quote)
   - Define: what order-intake already covers vs. what's missing
   - Reference: table ownership map for orders, imprints, mockups
   - Output: docs/planning/MINT_ORDER_LIFECYCLE_CONTRACT_V1.md

### Step 3: Infrastructure Plans (Track B — parallel with Step 2)

1. LOOP-MINT-TUNNEL-MIGRATION-CONTRACT
   - Read: ronny-ops infrastructure/cloudflare/tunnel/ config
   - Map: every route → target service → target VM
   - Define: which routes move to mint-apps (VM 213)
   - Output: docs/planning/MINT_TUNNEL_MIGRATION_PLAN.md

2. LOOP-MINT-SECRETS-BOOTSTRAP-CONTRACT
   - Read: ronny-ops scripts/load-secrets.sh, .env files (names only, not values)
   - Define: Infisical project structure for mint-modules
   - Output: docs/planning/MINT_SECRETS_BOOTSTRAP_PLAN.md

### Step 4: Update Execution Queue
- Append new loops to MINT_MODULE_EXECUTION_QUEUE.md
- Maintain existing Rank 1-4 entries unchanged
- Add new entries as Rank 5+ with dependencies on existing ranks
- Submit via proposal

## Rules
- Legacy codebase is READ-ONLY. Do not edit any file in ronny-ops.
- All outputs go to agentic-spine/docs/planning/ as proposals.
- Every loop opened must produce a receipt on close.
- If a table ownership conflict is detected between contracts, STOP and flag it.
  Do not resolve it — that's an operator decision.
- Context budget: summarize files > 100 lines. Reference file:line, don't paste.
- If you're unsure about a classification, mark it UNKNOWN with evidence.
  Do not guess.
```

---

## What This Avoids

| Anti-pattern | How this prompt prevents it |
|---|---|
| Agent writes code before contract approval | Mission explicitly says "NOT writing code" |
| Agent modifies legacy repo | "Legacy codebase is READ-ONLY" |
| Parallel agents create conflicting table claims | Table ownership map is Step 1; conflicts flagged, not resolved |
| New governance artifacts outside spine | All outputs go to `agentic-spine/docs/planning/` |
| Work bypasses mailroom | All outputs submitted via `proposals.submit` |
| Agent invents new loop naming | Loop names follow existing `LOOP-MINT-*-PHASE0-CONTRACT` pattern |
| Agent doesn't generate receipts | "Every loop opened must produce a receipt on close" |
| Context bloat kills the session | "Summarize files > 100 lines. Reference file:line." |

---

## Session Topology (if running multi-agent)

If dispatching to multiple Claude Code terminals simultaneously:

| Terminal | Track | Loops | Writes to |
|---|---|---|---|
| T1 (SPINE-AUDIT-01) | C: Table Ownership | LOOP-MINT-TABLE-OWNERSHIP-AUDIT | `MINT_TABLE_OWNERSHIP_MAP.md` |
| T2 (DEPLOY-MINT-01) | A: Auth + Payment | LOOP-MINT-AUTH-*, LOOP-MINT-PAYMENT-* | `MINT_AUTH_CONTRACT_V1.md`, `MINT_PAYMENT_CONTRACT_V1.md` |
| T3 (DEPLOY-MINT-01) | A: Notification + Order | LOOP-MINT-NOTIFICATION-*, LOOP-MINT-ORDER-LIFECYCLE-* | `MINT_NOTIFICATION_CONTRACT_V1.md`, `MINT_ORDER_LIFECYCLE_CONTRACT_V1.md` |
| T4 (SPINE-CONTROL-01) | B: Infra (tunnel + secrets) | LOOP-MINT-TUNNEL-*, LOOP-MINT-SECRETS-* | `MINT_TUNNEL_MIGRATION_PLAN.md`, `MINT_SECRETS_BOOTSTRAP_PLAN.md` |

**Collision-free because:**
- Each terminal writes to a different output file
- No terminal modifies another terminal's scope
- All use proposal flow (mailroom merges)
- T1 finishes first; T2-T4 reference its output but don't modify it

---

## After This Session

Once all contracts are approved by operator:
1. Update `MINT_MODULE_EXECUTION_QUEUE.md` with new Rank 5+ entries
2. Each contract proceeds to Gate 2 (SCHEMA) — still no code, just migration plans
3. Gate 3 (PACKAGING) is where code starts — Dockerfiles, compose, health endpoints
4. Gates 4-5 (SMOKE, CUTOVER) are deployment
5. Total: 5 sessions per module, fully governed, no shortcuts
