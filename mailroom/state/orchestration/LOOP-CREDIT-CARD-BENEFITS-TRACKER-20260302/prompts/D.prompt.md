# Worker Kickoff Prompt (D)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302"
export SPINE_ORCH_LOOP_ID="LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="D"
export SPINE_ORCH_SESSION_ID="wave-cc-benefits-20260305-D"
cd "/Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305-D"
git checkout "LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/d"
git status --short --branch
```

## Worker Contract

- lane: D
- agent_id: lane-d
- branch: LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/d
- worktree: /Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305-D
- packet: /Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305/mailroom/state/orchestration/LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/packet.yaml
- lock_claim: /Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305/mailroom/state/orchestration/LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/locks/D.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
