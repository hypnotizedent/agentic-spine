# Boundary Cutover Plan: Spine-Core vs Ronny-Products
## Date: 2026-03-03 (prepared 2026-03-02)
## Authority: SPINE-CONTROL-01 boundary-cutover wave
## Loop: N/A (meta-governance — no execution loop required)

---

## W0 Baseline

| Metric | Value |
|--------|-------|
| Verify (fast) | 10/10 PASS |
| Loops | 2 open + 28 planned + 135 closed = 165 |
| Gaps | 1312 total, 55 open, 0 orphans |
| Proposals | 9 total (0 pending, 1 applied, 8 draft_hold, 0 superseded) |
| Run keys | verify.run Rvu2857382, proposals.status R7fyi58113, gaps.status Rmhxp60067, loops.status Rfzvr61709 |

---

## 1. Classification Matrix

### Deterministic Criteria

| Signal | Classification |
|--------|---------------|
| Files under ops/, docs/governance/, docs/canonical/, surfaces/verify/, mailroom/ | spine-core |
| Files under workbench/agents/*/tools/, standalone scripts, app configs, deployment plans for user-facing apps | standalone-product |
| Proposal with only loop scope + gap registration + capability routing | spine-core |
| Proposal with actual app code (Python, YAML app configs, n8n workflows, cron entries) | standalone-product |
| Contracts/research/architecture docs for a future product | spine-core (until implementation phase) |

### Proposal Classification

| Proposal ID | Classification | Target Repo | Rationale |
|---|---|---|---|
| CP-20260302-025514 (Provider Orchestration) | spine-core | agentic-spine | Governance registries (PROVIDER_REGISTRY.yaml, CLI_INTERFACE_REGISTRY.yaml, ROLE_PROVIDER_MAPS.yaml) in docs/governance/ |
| CP-20260302-031644 (VoucherVault Deployment) | hybrid-split-required | spine(loop/gap) + ronny-products/vouchervault(deploy) | Loop scope is spine governance; DEPLOYMENT_PLAN.md is product-specific infrastructure |
| CP-20260302-031900 (CC Benefits Tracker) | **standalone-product** | **ronny-products/cc-benefits-tracker** | Full app code: tracker.py, cards.yaml, n8n workflow, cron deployment. Zero governance artifacts. |
| CP-20260302-032318 (Inbox Shield Phase 0) | spine-core | agentic-spine | Planning-only (no_runtime_change=true). Architecture doc, contracts YAML, carrier research, model analysis. Phase 1+ implementation would target ronny-products/inbox-shield. |
| CP-20260302-033506 (Bridge Calendar RPC) | spine-core | agentic-spine | Capability routing: loop scope + gap registration + bridge Cap-RPC allowlist modification |
| CP-20260302-075509 (Surveillance Platform) | spine-core | agentic-spine | Governance docs only: SURVEILLANCE_PLATFORM_SSOT.md, SURVEILLANCE_ROLES.md |
| CP-20260302-075826 (Endpoint Fleet) | spine-core | agentic-spine | Governance framework: ENDPOINT_FLEET_SSOT.md, ENDPOINT_LIFECYCLE.md, ENDPOINT_AGENTIC_INTEGRATION.md |
| CP-VOUCHERVAULT-DEPLOYMENT-20260302 | **SUPERSEDED** | N/A | Tombstoned — duplicate of CP-20260302-031644 (see Tombstone Ledger) |

### Classification Summary

| Category | Count | Proposals |
|----------|-------|-----------|
| spine-core | 5 | provider-orch, inbox-shield-P0, bridge-calendar, surveillance, endpoint-fleet |
| standalone-product | 1 | cc-benefits-tracker |
| hybrid-split-required | 1 | vouchervault-deployment |
| superseded | 1 | CP-VOUCHERVAULT (old) |

---

## 2. Tombstone Ledger

| Tombstoned Proposal | Status | Superseded By | Reason | Disposition |
|---|---|---|---|---|
| CP-VOUCHERVAULT-DEPLOYMENT-20260302 | superseded | CP-20260302-031644__vouchervault-deployment-plan | Duplicate proposal for same loop (LOOP-VOUCHERVAULT-DEPLOYMENT-20260302). Non-standard naming, malformed intake (proposal.md-only format), incomplete changes array. The standard-named proposal has complete changes and staged DEPLOYMENT_PLAN.md. | carry-forward |

**No other tombstones required.** All remaining 7 draft_hold proposals are unique with no semantic overlap.

---

## 3. Repo Mapping Spec

### Target Repos

| Repo | Path | Purpose | Status |
|------|------|---------|--------|
| agentic-spine (spine-core) | /Users/ronnyworks/code/agentic-spine | Governance, orchestration, contracts, capabilities, drift gates, loop/gap/plan management | Existing |
| ronny-products (product root) | /Users/ronnyworks/code/ronny-products | Parent directory for standalone product repos | To create |
| cc-benefits-tracker | /Users/ronnyworks/code/ronny-products/cc-benefits-tracker | Credit card benefits reminder tool (Python + n8n) | To create |
| inbox-shield | /Users/ronnyworks/code/ronny-products/inbox-shield | AI-powered communication buffer (Phase 1+ implementation) | Future — Phase 0 stays in spine |
| vouchervault | /Users/ronnyworks/code/ronny-products/vouchervault | VoucherVault integration-only deployment config | To create when loop promoted |

### Product List (Definitive)

1. **cc-benefits-tracker** — Proactive credit card benefits expiration reminder. Python CLI + n8n workflow + cron. Standalone product with no spine governance dependencies beyond deployment target (VM 211 finance-stack).

2. **inbox-shield** — AI-powered communication buffer intercepting inbound calls/SMS/email. Currently in Phase 0 (research/contracts in spine). Phase 1+ implementation will target this repo. **NOT YET CREATED** — awaits Phase 0 approval.

3. **vouchervault** — VoucherVault self-hosted gift card management system. Integration-only deployment (no custom build path). Docker compose + OIDC SSO config. **No separate giftcard-tracker repo needed** — VoucherVault is adopted as-is.

### File-Level Ownership Boundary Rules

```
STAYS IN SPINE (agentic-spine):
  mailroom/state/loop-scopes/LOOP-*.scope.md     # All loop governance
  mailroom/state/plans/                            # All plan governance
  mailroom/outbox/proposals/                       # All proposal lifecycle
  ops/bindings/operational.gaps.yaml               # Unified gap registry
  ops/bindings/*.contract.yaml                     # All authority contracts
  ops/bindings/*.yaml (capabilities, gates)        # All capability/gate registries
  docs/governance/                                 # All governance docs
  docs/canonical/                                  # All canonical SSOTs
  surfaces/verify/                                 # All drift gates

MOVES TO PRODUCT REPO (ronny-products/<product>):
  Application source code (*.py, *.js, *.ts)
  App configuration (cards.yaml, config.yaml)
  Deployment plans (DEPLOYMENT_PLAN.md)
  n8n workflow definitions (*.json)
  Docker compose overrides for product-specific stacks
  Product README.md and user documentation
  Product-specific tests

HYBRID (spine reference + product implementation):
  Loop scope stays in spine (governance authority)
  Gap stays in spine (unified registry)
  Product code moves to product repo
  Proposal manifest stays in spine (lifecycle tracking)
  Deployment config moves to product repo
```

### Migration Queue Order

| Priority | Product | Readiness | Blocker |
|----------|---------|-----------|---------|
| 1 | cc-benefits-tracker | Ready now | Operator approval of loop promotion |
| 2 | vouchervault | Deferred (horizon=later) | Loop promotion to now + runnable |
| 3 | inbox-shield | Future (Phase 0 in progress) | Phase 0 research approval, then Phase 1 planning |

---

## 4. Morning Execution Packets

### Packet A: SPINE-CORE (Governance-Only Waves)

**Scope:** 5 spine-core proposals + tombstone cleanup

**Phase 1: Operator Review Queue**
- [ ] Review CP-20260302-033506 (Bridge Calendar RPC) — promote to pending after creating loop scope via `proposals.apply`
- [ ] Review CP-20260302-032318 (Inbox Shield Phase 0) — approve research artifacts, keep at draft_hold until Phase 0 DoD met
- [ ] Review CP-20260302-025514 (Provider Orchestration) — long-horizon (future), keep at draft_hold
- [ ] Review CP-20260302-075509 (Surveillance Platform) — blocked on LOOP-CAMERA-OUTAGE-20260209, keep at draft_hold
- [ ] Review CP-20260302-075826 (Endpoint Fleet) — planning docs only, keep at draft_hold

**Phase 2: Bridge Calendar Apply (if approved)**
```bash
./bin/ops cap run proposals.apply -- CP-20260302-033506__bridge-calendar-radicale-capabilities
```
- Go/No-Go: Operator confirms bridge restart is safe (check active sessions)
- Rollback: Remove created loop scope + revert bridge consumers YAML
- DoD: Loop scope exists, GAP-OP-1336 registered, bridge Cap-RPC allowlist updated

**Phase 3: Master Seam Closure Scheduling**
- Review PLAN-SPINE-MASTER-SEAM-CLOSURE-20260302.md
- Operator inputs needed:
  1. Approve loop promotion planned → active
  2. Ring assignment policy for 6 new execution gates
  3. Run-key backward-compatibility stance (strict vs dual-prefix)
- First executable wave: W0 Baseline Claim Validation

**Required Operator Inputs:**
- Bridge Calendar: safe to restart bridge? (check active sessions)
- Master Seam Closure: ring assignment + backward-compat policy
- Inbox Shield: approve Phase 0 research direction?

**Rollback Points:**
- Each proposal apply is atomic and reversible (git revert)
- No runtime changes in this packet

---

### Packet B: CC-BENEFITS-TRACKER (Standalone Product)

**Scope:** CP-20260302-031900 — full app implementation

**Pre-Requisites:**
- [ ] Operator approves loop promotion (LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302: planned → active)
- [ ] Create product repo: `mkdir -p /Users/ronnyworks/code/ronny-products/cc-benefits-tracker`
- [ ] Initialize git repo with README

**Phase 1: YAML Schema Design**
- Create `cards.yaml` with 7 credit card definitions and benefit structures
- Source: proposal files/cards.yaml (4.5KB, already staged in proposal)
- DoD: All 7 cards configured with correct benefit reset schedules

**Phase 2: Core Script Implementation**
- Create `tracker.py` with CLI interface, date math, redemption logging
- Source: proposal files/tracker.py (11.2KB, already staged)
- Commands: status, urgent, weekly, redeem, value
- DoD: CLI passes manual smoke test for each command

**Phase 3: n8n Notification Workflow**
- Create CC-BENEFITS-ALERT.json workflow
- Source: proposal files/CC-BENEFITS-ALERT.json (2.0KB, already staged)
- Configure Slack webhook: `https://n8n.ronny.works/webhook/cc-benefits`
- DoD: Test notification fires in Slack

**Phase 4: Deployment & Cron Setup**
- Deploy to VM 211 finance-stack (100.76.153.100)
- Add cron entries to `finance.stack.cron.yaml`:
  - Weekly summary: Sundays 9am
  - Urgent alerts: Daily 9am (benefits expiring within 7 days)
- DoD: Cron fires on schedule, Slack notifications arrive

**Go/No-Go Checks:**
- [ ] VM 211 finance-stack accessible
- [ ] n8n webhook endpoint reachable
- [ ] Slack channel for notifications exists

**Rollback Points:**
- Phase 1-3: Delete files from product repo
- Phase 4: Remove cron entries, no persistent state to clean

**Required Operator Inputs:**
- Confirm n8n webhook URL
- Confirm target Slack channel
- Approve cron schedule

**First Executable Wave DoD:**
- cards.yaml reviewed and approved
- tracker.py passes `--status` command for all 7 cards
- At least 1 test notification sent

---

### Packet C: INBOX-SHIELD (Planning Phase Only)

**Scope:** CP-20260302-032318 — Phase 0 research approval

**Current State:** Planning-only (no_runtime_change=true). Research artifacts already staged:
- INBOX_SHIELD_ARCHITECTURE_V1.md (system architecture)
- inbox-shield.contracts.yaml (14 capabilities, 4 contracts, 3 drift gates)
- TWILIO_CARRIER_RESEARCH.md (carrier forwarding + Twilio provisioning)
- MODEL_APPROACH_ANALYSIS.md (local vs API model comparison)

**Phase 1: Research Review**
- [ ] Operator reviews all 4 research artifacts
- [ ] Approve or request changes to architecture
- [ ] Confirm Twilio approach (number provisioning + carrier forwarding)
- [ ] Decide model approach (local fine-tuned vs API)

**Phase 2: Planning Approval**
- [ ] Mark research phase complete
- [ ] Promote loop from planned → approved for Phase 1 planning
- [ ] Create product repo: `mkdir -p /Users/ronnyworks/code/ronny-products/inbox-shield`
- [ ] Phase 1 implementation proposal would be a NEW proposal

**Go/No-Go:** Operator reviews research and approves direction
**Rollback:** No runtime changes — research artifacts only
**Required Operator Inputs:**
- iMessage interception strategy (known limitation: can't intercept server-side)
- Budget approval for Twilio number
- Model approach decision (local vs API)

**BLOCKED:** Phase 1+ implementation awaits research approval

---

### Packet D: VOUCHERVAULT-INTEGRATION (Deferred)

**Scope:** CP-20260302-031644 — integration-only deployment

**Current State:** horizon=later, execution_readiness=blocked, review_date=2026-04-01

**No custom giftcard-tracker repo needed.** VoucherVault is adopted as-is (open-source gift card management). This is integration-only work: Docker compose + OIDC SSO configuration.

**When Activated (after 2026-04-01 review):**

**Phase 1: Loop Promotion**
- [ ] Promote LOOP-VOUCHERVAULT-DEPLOYMENT-20260302 to horizon=now, execution_readiness=runnable
- [ ] Create product repo: `mkdir -p /Users/ronnyworks/code/ronny-products/vouchervault`

**Phase 2: Infrastructure Setup**
- [ ] Provision VM or container slot
- [ ] Deploy VoucherVault via Docker compose
- [ ] Configure OIDC SSO with Authentik

**Phase 3: Integration**
- [ ] Register in spine service registry
- [ ] Create health check capability
- [ ] Wire drift gate

**Go/No-Go:** Operator promotes loop from later to now
**Rollback:** Remove container, no persistent data at risk
**Required Operator Inputs:**
- VM allocation decision
- OIDC client configuration in Authentik

**BLOCKED until 2026-04-01 review date**

---

## 5. Linkage Integrity Post-Classification

### Validation Results

| Check | Result |
|-------|--------|
| Orphan gaps | 0 |
| Proposal→Loop linkage | 8/8 valid (7 draft_hold + 1 superseded, all loops exist) |
| Plan→Gap linkage | 24/24 valid (all gaps exist and are open) |
| Loop status contradictions | 0 (fixed in overnight sweep) |
| Proposal status contradictions | 0 |

### Boundary-Cutover Linkage Rules

**Loops stay in spine.** All loop scope files remain in `mailroom/state/loop-scopes/`. Product repos do NOT maintain loop scopes. Loop lifecycle is spine governance.

**Gaps stay in spine.** The unified gap registry (`operational.gaps.yaml`) remains in agentic-spine. Product repos reference gaps by ID but do not maintain their own registries.

**Proposals stay in spine.** All proposal manifests remain in `mailroom/outbox/proposals/`. Product repos are execution targets, not governance surfaces.

**Product code moves to product repos.** Application source, configs, deployment plans, and workflows move to `ronny-products/<product>/`.

**Cross-repo reference pattern:**
```yaml
# In spine proposal manifest:
changes:
  - action: create
    path: "ronny-products/cc-benefits-tracker/tracker.py"   # cross-repo target
    repo: ronny-products                                      # explicit repo field
```

### Gaps Requiring No Reparenting

All 55 open gaps have valid parent_loop references to existing, non-closed loops. No reparenting needed for this boundary cutover.

---

## 6. Post-Normalization Delta

| Metric | Before (W0) | After (W2) | Delta |
|--------|-------------|------------|-------|
| Verify | 10/10 PASS | (verify in W5) | — |
| Proposals total | 9 | 9 | 0 |
| Draft hold | 8 | 7 | -1 |
| Superseded | 0 | 1 | +1 |
| Open gaps | 55 | 55 | 0 |
| Orphan gaps | 0 | 0 | 0 |

---

## Files Changed in This Wave

1. `mailroom/outbox/proposals/CP-VOUCHERVAULT-DEPLOYMENT-20260302/manifest.yaml` — status: draft_hold → superseded
2. `mailroom/state/plans/PLAN-RONNY-PRODUCTS-BOUNDARY-CUTOVER-20260303.md` — this file (new)
