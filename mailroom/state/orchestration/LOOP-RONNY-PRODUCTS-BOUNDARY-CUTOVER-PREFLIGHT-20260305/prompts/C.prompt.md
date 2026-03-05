# App Terminal Prompt: inbox-shield

## Identity
- Product: inbox-shield
- Profile: research-phase
- Spine Loop: LOOP-INBOX-SHIELD-PHASE-0-20260302
- Spine Proposal: CP-20260302-032318

## Status: BLOCKED
Blocker: Phase 0 research approval required. No runtime code until research phase approved.

## Objective
Complete Phase 0 research for AI-powered communication buffer, then scaffold for Phase 1.

## Pre-Requisites
- [ ] Phase 0 research artifacts reviewed and approved:
  - INBOX_SHIELD_ARCHITECTURE_V1.md
  - inbox-shield.contracts.yaml
  - TWILIO_CARRIER_RESEARCH.md
  - MODEL_APPROACH_ANALYSIS.md
- [ ] Operator decisions:
  - iMessage interception strategy
  - Twilio budget approval
  - Model approach (local vs API)

## Phase 1: Scaffold (after research approval)
```bash
cd /Users/ronnyworks/code/ronny-products
./bin/productctl scaffold inbox-shield --profile research-phase
```

### Verify scaffold
```bash
./bin/productctl shape-check inbox-shield
./bin/productctl content-check inbox-shield
```

## Phase 2: Research Documentation
1. Move approved research artifacts to `inbox-shield/docs/`
2. Update `inbox-shield/app.contract.yaml`:
   - Set governance.spine_loop_id
   - Set governance.spine_proposal_id
   - Set status to "research"

## Phase 3: Phase 1 Planning (requires separate proposal)
1. Create Phase 1 implementation proposal in spine
2. Design Twilio integration architecture
3. Define model fine-tuning pipeline
4. Create deployment plan

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
- [ ] Research artifacts are complete and reviewed
- [ ] shape-check passes
- [ ] content-check passes
- [ ] No runtime code present (research-phase profile)

## Rollback
1. Delete `inbox-shield/` directory
2. No runtime changes — research artifacts only

## Receipts
- Scaffold dry-run output
- Research review checklist
- Spine verify output
