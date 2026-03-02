---
loop_id: LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: credit
priority: high
horizon: now
execution_readiness: blocked
blocked_by: "Overnight intake — requires operator review and approval before execution"
next_review: "2026-03-09"
objective: Create credit card benefits tracker to prevent expiring credits - proactive reminders before benefits expire
---

# Loop Scope: LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302

## Objective

Create credit card benefits tracker to prevent expiring credits - proactive reminders before benefits expire

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302`

## Phases
- Phase 1:  Research and design YAML schema for card/benefit tracking
- Phase 2:  Implement Python tracker script with expiration logic
- Phase 3:  Create n8n workflow for Slack/email notifications
- Phase 4:  Deploy to finance stack VM with cron scheduling

## Success Criteria
- User receives weekly summary of all benefit status
- User receives urgent alerts 7 days before benefits expire
- User can log redemptions to track usage

## Definition Of Done
- YAML config with 7 cards populated
- Python script runs on VM 211 with cron
- n8n workflow sends to Slack

## Proposals

- CP-20260302-031900__credit-card-benefits-tracker-implementation (pending)

## Context

**Problem:** Recently lost $600 in unused FHR credits due to no proactive reminders.

**Cards tracked:**
- Amex Platinum
- Amex Gold  
- Amex Blue Business Plus
- Amex Hilton Surpass
- Amex Delta Gold
- Amex BBP
- Chase Sapphire Reserve

**Integration points:**
- n8n webhook: `https://n8n.ronny.works/webhook/cc-benefits`
- Deploy target: VM 211 (100.76.153.100)
- Cron schedule: Weekly Sunday 9am, Daily 9am urgent
