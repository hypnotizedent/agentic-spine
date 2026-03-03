# Worker Kickoff Prompt (B)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303"
export SPINE_ORCH_LOOP_ID="LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="B"
export SPINE_ORCH_SESSION_ID="kickoff-20260303T092657Z-B"
cd "/Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/B"
git checkout "LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/b"
git status --short --branch
```

## Worker Contract

- lane: B
- agent_id: lane-b
- branch: LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/b
- worktree: /Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/B
- packet: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/packet.yaml
- lock_claim: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/locks/B.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
