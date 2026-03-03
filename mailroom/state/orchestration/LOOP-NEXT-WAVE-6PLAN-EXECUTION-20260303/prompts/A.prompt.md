# Worker Kickoff Prompt (A)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303"
export SPINE_ORCH_LOOP_ID="LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="A"
export SPINE_ORCH_SESSION_ID="kickoff-20260303T092657Z-A"
cd "/Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/A"
git checkout "LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/a"
git status --short --branch
```

## Worker Contract

- lane: A
- agent_id: lane-a
- branch: LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/a
- worktree: /Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/A
- packet: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/packet.yaml
- lock_claim: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/locks/A.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
