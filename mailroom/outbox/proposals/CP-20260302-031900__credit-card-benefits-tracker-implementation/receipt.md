# Credit Card Benefits Tracker - Implementation Plan

**Proposal:** CP-20260302-031900
**Loop:** LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302
**Created:** 2026-03-02
**Status:** pending

## Problem Statement

You have 7 credit cards (6 Amex + 1 Chase) with various perks that reset annually, monthly, or quarterly. You recently lost $600 in unused FHR credits. Card Pointers doesn't solve this - you need proactive reminders BEFORE benefits expire.

## Solution Architecture

### Location
`workbench/agents/finance/tools/cc-tracker/` (syncs to VM 211)

### Components
1. **YAML config** - All cards, benefits, reset dates, redemption tracking
2. **Python script** - Parses YAML, calculates expiring benefits, generates alerts
3. **n8n workflow** - Push alerts to Slack via webhook
4. **Cron jobs** - Weekly summary + daily urgent alerts

## Data Model (cards.yaml)

```yaml
cards:
  - name: "Amex Platinum"
    issuer: amex
    annual_fee: 695
    fee_date: "2025-03-15"
    benefits:
      - name: "Fine Hotels & Resorts"
        value: 200
        type: annual
        reset_date: "01-01"
        quantity: 1
        redeemed: 0
      - name: "Airline Fee Credit"
        value: 200
        type: annual
        reset_date: "01-01"
        quantity: 1
        redeemed: 0
        selected_airline: "United"
      - name: "Uber Credits"
        value: 15
        type: monthly
        reset_date: "01"
        quantity: 12
        redeemed: []
      - name: "Saks Credit"
        value: 50
        type: semiannual
        reset_dates: ["01-01", "07-01"]
        redeemed: []
```

## Script Logic (tracker.py)

### Core Functions
- `load_cards()` - Parse YAML config
- `get_expiring_benefits(days_ahead=7)` - Find benefits expiring within N days
- `get_unused_benefits()` - Find unredeemed benefits for current period
- `generate_weekly_summary()` - Weekly digest of all benefits status
- `generate_urgent_alerts()` - Benefits expiring within 7 days
- `log_redemption(card, benefit, amount)` - Mark a benefit as used

### CLI Interface
```bash
./tracker.py status      # View all benefits status
./tracker.py urgent      # What's expiring soon
./tracker.py weekly      # Weekly summary
./tracker.py redeem "Amex Platinum" "Uber Credits"
./tracker.py value       # Calculate total annual value
```

## Alert Schedule

| Alert Type | Frequency | Time | Delivery | Content |
|------------|-----------|------|----------|---------|
| Weekly Summary | Sunday | 9am | Slack | All cards, % used, value remaining |
| Urgent Alert | Daily | 9am | Slack | Benefits expiring in 7 days |
| Month-End Warning | 25th | 9am | Slack | Monthly credits about to reset |
| Year-End Warning | Dec 15,20,26 | 9am | Slack | Annual credits expiring |

## Integration with Existing Systems

### n8n Workflow
- Trigger: Webhook from tracker.py
- Format: JSON payload with alert type and content
- Destination: Slack incoming webhook
- Pattern matches: `A05`/`A06` notification workflows

### Finance Stack Deployment
- Target: VM 211 (100.76.153.100)
- Path: `/home/docker-host/stacks/finance/cc-tracker/`
- Cron: `/etc/cron.d/cc-tracker`

## Implementation Phases

### Phase 1: YAML Schema & Config (30 min)
- Design schema for card/benefit structure
- Populate with your 7 actual cards
- Include common Amex benefit structures

### Phase 2: Core Script (2-3 hrs)
- Date math for annual/monthly/quarterly resets
- Expiration calculation logic
- CLI interface with argparse
- Redemption logging to redemptions.yaml

### Phase 3: n8n Integration (1 hr)
- Create workflow JSON
- Configure Slack webhook
- Test alert delivery

### Phase 4: Deployment (30 min)
- Sync to VM 211
- Add cron entries
- Verify execution

## Sample Output

### Weekly Summary
```
💳 CREDIT CARD BENEFITS - Week of Mar 2, 2026

AMEX PLATINUM ($695/yr)
├─ FHR Credit: $0/$200 used (0%) ⚠️ EXPIRES DEC 31
├─ Airline Credit: $200/$200 used ✅
├─ Uber: $15/$15 used this month ✅
├─ Saks: $0/$50 used (H1) ⚠️ EXPIRES JUN 30
└─ Digital: $20/$20 used ✅

AMEX GOLD ($250/yr)
├─ Uber: $10/$10 used ✅
└─ Dining: $0/$10 used ⚠️ 6 DAYS LEFT

TOTAL VALUE THIS YEAR: $3,200
REDEEMED: $1,850 (58%)
AT RISK: $350 (expiring within 30 days)
```

## Files to Create

| File | Purpose |
|------|---------|
| `workbench/agents/finance/tools/cc-tracker/cards.yaml` | Card/benefit definitions |
| `workbench/agents/finance/tools/cc-tracker/tracker.py` | Main script |
| `workbench/agents/finance/tools/cc-tracker/redemptions.yaml` | Redemption log |
| `workbench/agents/finance/tools/cc-tracker/README.md` | Documentation |
| `workbench/infra/compose/n8n/workflows/CC-BENEFITS-ALERT.json` | n8n workflow |

## Estimated Total Effort
3-4 hours

## Next Steps

1. Review and approve this proposal
2. Execute via `/gsd-execute-phase` or manual implementation
3. Populate cards.yaml with actual card data
4. Build tracker.py with core logic
5. Wire up notifications via n8n
6. Deploy to VM 211 with cron

---

**This is a planning proposal. No execution will occur until approved.**
