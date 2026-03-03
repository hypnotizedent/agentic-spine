# Worker Kickoff Prompt (E)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303"
export SPINE_ORCH_LOOP_ID="LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="E"
export SPINE_ORCH_SESSION_ID="kickoff-20260303T092657Z-E"
cd "/Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/E"
git checkout "LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/e"
git status --short --branch
```

## Worker Contract

- lane: E
- agent_id: lane-e
- branch: LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/e
- worktree: /Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/E
- packet: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/packet.yaml
- lock_claim: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/locks/E.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
