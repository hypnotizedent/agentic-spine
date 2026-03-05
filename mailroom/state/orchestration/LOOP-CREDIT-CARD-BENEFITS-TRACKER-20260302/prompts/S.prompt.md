# Worker Kickoff Prompt (S)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302"
export SPINE_ORCH_LOOP_ID="LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="S"
export SPINE_ORCH_SESSION_ID="wave-cc-benefits-20260305-S"
cd "/Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305-S"
git checkout "LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/s"
git status --short --branch
```

## Worker Contract

- lane: S
- agent_id: lane-s
- branch: LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/s
- worktree: /Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305-S
- packet: /Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305/mailroom/state/orchestration/LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/packet.yaml
- lock_claim: /Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305/mailroom/state/orchestration/LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/locks/S.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
