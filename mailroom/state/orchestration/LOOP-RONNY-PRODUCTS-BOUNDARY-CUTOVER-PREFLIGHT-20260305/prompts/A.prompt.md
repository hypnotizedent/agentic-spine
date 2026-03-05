# App Terminal Prompt: cc-benefits-tracker

## Identity
- Product: cc-benefits-tracker
- Profile: standalone-app
- Spine Loop: LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302
- Spine Proposal: CP-20260302-031900

## Objective
Scaffold, implement, and deploy a credit card benefits expiration reminder tool.

## Pre-Requisites
- [ ] Spine loop promoted to active
- [ ] ronny-products repo initialized (DONE)
- [ ] VM 211 finance-stack accessible

## Phase 1: Scaffold
```bash
cd /Users/ronnyworks/code/ronny-products
./bin/productctl scaffold cc-benefits-tracker --profile standalone-app
```

### Verify scaffold
```bash
./bin/productctl shape-check cc-benefits-tracker
./bin/productctl content-check cc-benefits-tracker
```

## Phase 2: Implementation
1. Create `cc-benefits-tracker/src/tracker.py` — CLI with commands: status, urgent, weekly, redeem, value
2. Create `cc-benefits-tracker/schema/cards.yaml` — 7 credit card definitions with benefit structures
3. Create `cc-benefits-tracker/src/CC-BENEFITS-ALERT.json` — n8n workflow definition
4. Update `cc-benefits-tracker/app.contract.yaml`:
   - Set governance.spine_loop_id
   - Set governance.spine_proposal_id
   - Set deployment target_vm, target_stack, health_endpoint

## Phase 3: Deployment
1. Deploy to VM 211 finance-stack (100.76.153.100)
2. Add cron entries:
   - Weekly summary: Sundays 9am
   - Urgent alerts: Daily 9am (benefits expiring within 7 days)
3. Configure n8n webhook endpoint

## Phase 4: Verify
```bash
cd /Users/ronnyworks/code/ronny-products
./bin/productctl doctor
```

### Spine verification
```bash
cd ~/code/agentic-spine
./bin/ops cap run verify.run -- fast
./bin/ops cap run verify.run -- domain loop_gap
```

## Required Tests
- [ ] `tracker.py --status` returns data for all 7 cards
- [ ] `tracker.py --urgent` runs without error
- [ ] shape-check passes
- [ ] content-check passes
- [ ] n8n webhook fires test notification

## Rollback
1. Delete `cc-benefits-tracker/` directory from ronny-products
2. Remove cron entries from finance-stack
3. No persistent state to clean

## Receipts
- Scaffold dry-run output
- Doctor check output
- Spine verify fast output
- Deployment SSH receipt
