# App Terminal Prompt: vouchervault

## Identity
- Product: vouchervault
- Profile: integration-only
- Spine Loop: LOOP-VOUCHERVAULT-DEPLOYMENT-20260302
- Spine Proposal: CP-20260302-031644

## Status: DEFERRED
Review date: 2026-04-01
Blocker: Loop must be promoted from horizon=later to horizon=now

## Objective
Deploy VoucherVault self-hosted gift card management system (integration-only, no custom code).

## Pre-Requisites
- [ ] Spine loop promoted to horizon=now, execution_readiness=runnable
- [ ] VM allocation decision made
- [ ] Authentik OIDC client configured

## Phase 1: Scaffold
```bash
cd /Users/ronnyworks/code/ronny-products
./bin/productctl scaffold vouchervault --profile integration-only
```

### Verify scaffold
```bash
./bin/productctl shape-check vouchervault
./bin/productctl content-check vouchervault
```

## Phase 2: Configuration
1. Create `vouchervault/docs/DEPLOYMENT_PLAN.md`
2. Create `vouchervault/config/docker-compose.yml` — VoucherVault official image
3. Create `vouchervault/config/oidc.env` — OIDC SSO config for Authentik
4. Update `vouchervault/app.contract.yaml`:
   - Set governance.spine_loop_id
   - Set deployment target_vm, compose_path, health_endpoint

## Phase 3: Deployment
1. Provision VM or container slot
2. Deploy VoucherVault via Docker compose
3. Configure OIDC SSO with Authentik
4. Register in spine service registry
5. Create health check capability

## Phase 4: Verify
```bash
cd /Users/ronnyworks/code/ronny-products
./bin/productctl doctor
```

### Spine verification
```bash
cd ~/code/agentic-spine
./bin/ops cap run verify.run -- fast
```

## Required Tests
- [ ] VoucherVault web UI accessible
- [ ] OIDC login works via Authentik
- [ ] Health endpoint responds
- [ ] shape-check passes
- [ ] content-check passes

## Rollback
1. Remove container/VM allocation
2. Delete `vouchervault/` directory
3. Remove spine service registry entry

## Receipts
- Scaffold dry-run output
- Docker compose up output
- Health endpoint check
- Spine verify output
