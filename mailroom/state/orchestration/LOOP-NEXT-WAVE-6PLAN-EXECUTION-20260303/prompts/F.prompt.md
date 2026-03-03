# Worker Kickoff Prompt (F)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303"
export SPINE_ORCH_LOOP_ID="LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="F"
export SPINE_ORCH_SESSION_ID="kickoff-20260303T092657Z-F"
cd "/Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/F"
git checkout "LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/f"
git status --short --branch
```

## Worker Contract

- lane: F
- agent_id: lane-f
- branch: LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/f
- worktree: /Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/F
- packet: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/packet.yaml
- lock_claim: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303/locks/F.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
