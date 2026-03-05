# Worker Kickoff Prompt (B)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302"
export SPINE_ORCH_LOOP_ID="LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="B"
export SPINE_ORCH_SESSION_ID="wave-cc-benefits-20260305-B"
cd "/Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305-B"
git checkout "LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/b"
git status --short --branch
```

## Worker Contract

- lane: B
- agent_id: lane-b
- branch: LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/b
- worktree: /Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305-B
- packet: /Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305/mailroom/state/orchestration/LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/packet.yaml
- lock_claim: /Users/ronnyworks/code/.wt/agentic-spine/WAVE-CREDIT-CARD-BENEFITS-TRACKER-20260305/mailroom/state/orchestration/LOOP-CREDIT-CARD-BENEFITS-TRACKER-20260302/locks/B.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
