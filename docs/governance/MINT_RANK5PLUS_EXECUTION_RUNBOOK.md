---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-22
scope: mint-rank5plus-execution
related_contracts:
  - ops/bindings/mint.rank5plus.cutover.contract.yaml
---

# Mint Rank5+ Execution Runbook

Canonical execution runbook for Mint Rank 5+ module cutover orchestration.

## Prerequisites

Before starting this runbook:

1. Run session startup: `./bin/ops cap run session.start`
2. Verify no active stabilization mode: `./bin/ops cap run stabilization.mode.status`
3. Confirm Tailscale connectivity: `tailscale status | grep mint`

## Execution Phases

### Phase 1: Foundation (Gate-0 → Gate-1)

**Loops:** `LOOP-MINT-TABLE-OWNERSHIP-AUDIT-20260222`, `LOOP-MINT-SECRETS-BOOTSTRAP-CONTRACT-20260222`

**Step Order:**

1. **Verify loop status**
   ```bash
   ./bin/ops cap run loops.progress --loop LOOP-MINT-TABLE-OWNERSHIP-AUDIT-20260222
   ./bin/ops cap run loops.progress --loop LOOP-MINT-SECRETS-BOOTSTRAP-CONTRACT-20260222
   ```

2. **Check linked gaps exist**
   ```bash
   ./bin/ops cap run gaps.status
   ```
   - Stop condition: Each loop must have ≥1 open linked gap

3. **Review table ownership decisions**
   ```bash
   cat docs/planning/MINT_TABLE_OWNERSHIP_MAP.md
   ```
   - Stop condition: `customers`, `orders`, `payments` owner_writer decisions documented

4. **Verify secrets namespace coverage**
   ```bash
   ./bin/ops cap run secrets.projects.status
   ./bin/ops cap run secrets.status
   ```
   - Stop condition: `/spine/services/{auth,payment,order-lifecycle,notification}` namespaces exist

5. **Checkpoint: Foundation ready**
   ```bash
   ./bin/ops cap run verify.pack.run mint
   ```
   - Proceed to Phase 2 only if PASS

**Rollback:** Revert any namespace additions via Infisical UI; no code changes in this phase.

---

### Phase 2: Core Services (Gate-1 → Gate-2)

**Loops:** `LOOP-MINT-AUTH-PHASE0-CONTRACT-20260222`, `LOOP-MINT-PAYMENT-PHASE0-CONTRACT-20260222`

**Depends on:** Phase 1 complete

**Step Order:**

1. **Verify foundation phase passed**
   ```bash
   ./bin/ops cap run loops.progress --loop LOOP-MINT-TABLE-OWNERSHIP-AUDIT-20260222
   ./bin/ops cap run loops.progress --loop LOOP-MINT-SECRETS-BOOTSTRAP-CONTRACT-20260222
   ```
   - Stop condition: Both loops show progress > 0%

2. **File/claim auth gaps**
   ```bash
   ./bin/ops cap run gaps.file --type missing-entry --parent-loop LOOP-MINT-AUTH-PHASE0-CONTRACT-20260222 \
     --description "Auth module boundary contract requires signing: customer JWT, admin sessions, PIN auth boundaries"
   ./bin/ops cap run gaps.claim --id GAP-OP-XXX --action "Auth Phase0 execution"
   ```

3. **File/claim payment gaps**
   ```bash
   ./bin/ops cap run gaps.file --type missing-entry --parent-loop LOOP-MINT-PAYMENT-PHASE0-CONTRACT-20260222 \
     --description "Payment activation gate: Stripe webhook verification, Postgres adapter migration, deploy manifest inclusion"
   ./bin/ops cap run gaps.claim --id GAP-OP-XXX --action "Payment Phase0 execution"
   ```

4. **Verify auth module readiness**
   ```bash
   ssh mint-apps "docker compose -f /opt/stacks/mint-apps/auth/docker-compose.yml ps"
   ```
   - Stop condition: Auth container healthy

5. **Verify payment module readiness**
   ```bash
   ssh mint-apps "docker compose -f /opt/stacks/mint-apps/payment/docker-compose.yml ps"
   curl -s http://100.79.183.14:PAYMENT_PORT/health
   ```
   - Stop condition: Payment container healthy, health endpoint returns 200

6. **Checkpoint: Core services ready**
   ```bash
   ./bin/ops cap run verify.pack.run mint
   ```
   - Proceed to Phase 3 only if PASS

**Rollback:**
```bash
ssh mint-apps "docker compose -f /opt/stacks/mint-apps/auth/docker-compose.yml down"
ssh mint-apps "docker compose -f /opt/stacks/mint-apps/payment/docker-compose.yml down"
```

---

### Phase 3: Business Logic (Gate-2 → Gate-3)

**Loops:** `LOOP-MINT-ORDER-LIFECYCLE-PHASE0-CONTRACT-20260222`, `LOOP-MINT-NOTIFICATION-PHASE0-CONTRACT-20260222`

**Depends on:** Phase 2 complete

**Step Order:**

1. **Verify core services phase passed**
   ```bash
   ./bin/ops cap run loops.progress --loop LOOP-MINT-AUTH-PHASE0-CONTRACT-20260222
   ./bin/ops cap run loops.progress --loop LOOP-MINT-PAYMENT-PHASE0-CONTRACT-20260222
   ```

2. **File/claim order-lifecycle gaps**
   ```bash
   ./bin/ops cap run gaps.file --type missing-entry --parent-loop LOOP-MINT-ORDER-LIFECYCLE-PHASE0-CONTRACT-20260222 \
     --description "Order lifecycle extraction from legacy v2-jobs.cjs: state machine contract, integration tests"
   ./bin/ops cap run gaps.claim --id GAP-OP-XXX --action "Order lifecycle Phase0 execution"
   ```

3. **File/claim notification gaps**
   ```bash
   ./bin/ops cap run gaps.file --type missing-entry --parent-loop LOOP-MINT-NOTIFICATION-PHASE0-CONTRACT-20260222 \
     --description "Notification routing: event-to-channel map, comms-agent credential wiring"
   ./bin/ops cap run gaps.claim --id GAP-OP-XXX --action "Notification Phase0 execution"
   ```

4. **Verify order-lifecycle module**
   ```bash
   ssh mint-apps "docker compose -f /opt/stacks/mint-apps/order-lifecycle/docker-compose.yml ps"
   ```
   - Stop condition: Order-lifecycle container healthy

5. **Verify notification module**
   ```bash
   ./bin/ops cap run communications.provider.status
   ssh mint-apps "docker compose -f /opt/stacks/mint-apps/notification/docker-compose.yml ps"
   ```
   - Stop condition: Notification container healthy, comms provider shows live mode

6. **Checkpoint: Business logic ready**
   ```bash
   ./bin/ops cap run verify.pack.run mint
   ```
   - Proceed to Phase 4 only if PASS

**Rollback:**
```bash
ssh mint-apps "docker compose -f /opt/stacks/mint-apps/order-lifecycle/docker-compose.yml down"
ssh mint-apps "docker compose -f /opt/stacks/mint-apps/notification/docker-compose.yml down"
```

---

### Phase 4: Infrastructure Migration (Gate-3 → Gate-4)

**Loop:** `LOOP-MINT-TUNNEL-MIGRATION-CONTRACT-20260222`

**Depends on:** Phase 3 complete

**Step Order:**

1. **Verify all Rank 5-7 modules deployed**
   ```bash
   ssh mint-apps "docker ps --format '{{.Names}}' | grep -E 'auth|payment|order-lifecycle|notification'"
   ```
   - Stop condition: All 4 containers running

2. **File/claim tunnel migration gaps**
   ```bash
   ./bin/ops cap run gaps.file --type missing-entry --parent-loop LOOP-MINT-TUNNEL-MIGRATION-CONTRACT-20260222 \
     --description "Tunnel cutover dependency: requires Rank 5-7 completion before Cloudflare route updates"
   ./bin/ops cap run gaps.claim --id GAP-OP-XXX --action "Tunnel migration execution"
   ```

3. **Prepare Cloudflare tunnel config**
   ```bash
   cat workbench/infra/cloudflare/tunnel/docker-compose.yml
   ```
   - Verify routes point to mint-apps services, not legacy docker-host

4. **Apply tunnel configuration**
   ```bash
   ssh docker-host "cd /opt/stacks/cloudflare/tunnel && docker compose up -d"
   ```

5. **Verify route cutover**
   ```bash
   curl -sI https://auth.mintprints.co/health
   curl -sI https://customer.mintprints.co/health
   ```
   - Stop condition: All routes return 200 from fresh-slate targets

6. **Final checkpoint**
   ```bash
   ./bin/ops cap run verify.pack.run mint
   ./bin/ops cap run verify.route.recommend
   ./bin/ops cap run verify.core.run
   ```

**Rollback:**
```bash
ssh docker-host "cd /opt/stacks/cloudflare/tunnel && git checkout HEAD~1 docker-compose.yml && docker compose up -d"
```

---

## Stop Conditions

Stop immediately and escalate if any of these occur:

| Condition | Action |
|-----------|--------|
| Any loop shows 0 linked gaps | File gaps before proceeding |
| `verify.pack.run mint` returns FAIL | Fix domain-specific gates before continuing |
| Health check returns non-200 for >60s | Initiate phase rollback |
| Secrets injection failure | Verify Infisical token validity |
| Tailscale connectivity lost | Re-establish before continuing |

## Verification Commands

```bash
./bin/ops cap run loops.status
./bin/ops cap run gaps.status
./bin/ops cap run verify.pack.run mint
./bin/ops cap run verify.pack.run loop_gap
./bin/ops cap run verify.core.run
./bin/ops cap run secrets.status
```

## Receipt Collection

After each phase, collect run keys:

```bash
ls receipts/sessions/RCAP-*/receipt.md | tail -5
```

Include run keys in phase completion notes.

## Completion Criteria

Rank 5+ cutover is complete when:

- [ ] All 7 Mint loops have ≥1 linked gap resolved
- [ ] `verify.pack.run mint` passes
- [ ] `verify.pack.run loop_gap` passes
- [ ] `verify.core.run` passes
- [ ] All Cloudflare routes point to fresh-slate targets
- [ ] No rollback actions taken
