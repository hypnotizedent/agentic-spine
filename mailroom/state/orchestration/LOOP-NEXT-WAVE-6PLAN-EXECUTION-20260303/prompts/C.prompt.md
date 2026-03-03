# Worker Kickoff Prompt (C)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303"
export SPINE_ORCH_LOOP_ID="LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="C"
export SPINE_ORCH_SESSION_ID="kickoff-20260303T092657Z-C"
cd "/Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/C"
git checkout "LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/c"
git status --short --branch
```

## Worker Contract

- lane: C
- agent_id: lane-c
- branch: LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/c
- worktree: /Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/C
- packet: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/packet.yaml
- lock_claim: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/locks/C.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
