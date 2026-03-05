# Worker Kickoff Prompt (A)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302"
export SPINE_ORCH_LOOP_ID="LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="A"
export SPINE_ORCH_SESSION_ID="wave-cc-benefits-20260305-A"
cd "/Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305-A"
git checkout "LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/a"
git status --short --branch
```

## Worker Contract

- lane: A
- agent_id: lane-a
- branch: LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/a
- worktree: /Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305-A
- packet: /Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305/mailroom/state/orchestration/LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/packet.yaml
- lock_claim: /Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305/mailroom/state/orchestration/LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/locks/A.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
