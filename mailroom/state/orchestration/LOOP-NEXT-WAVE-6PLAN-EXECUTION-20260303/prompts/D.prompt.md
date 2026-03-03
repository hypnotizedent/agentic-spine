# Worker Kickoff Prompt (D)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303"
export SPINE_ORCH_LOOP_ID="LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="D"
export SPINE_ORCH_SESSION_ID="kickoff-20260303T092657Z-D"
cd "/Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/D"
git checkout "LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/d"
git status --short --branch
```

## Worker Contract

- lane: D
- agent_id: lane-d
- branch: LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/d
- worktree: /Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/D
- packet: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/packet.yaml
- lock_claim: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/locks/D.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
