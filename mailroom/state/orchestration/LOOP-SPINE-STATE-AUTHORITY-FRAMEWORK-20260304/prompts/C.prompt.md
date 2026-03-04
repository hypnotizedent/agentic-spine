# Worker Kickoff Prompt (C)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304"
export SPINE_ORCH_LOOP_ID="LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="C"
export SPINE_ORCH_SESSION_ID="kickoff-20260304T230411Z-C"
cd "/Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/C"
git checkout "LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/c"
git status --short --branch
```

## Worker Contract

- lane: C
- agent_id: lane-c
- branch: LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/c
- worktree: /Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/C
- packet: /Users/ronnyworks/code/agentic-spine/.worktrees/state-authority-framework-20260304/mailroom/state/orchestration/LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/packet.yaml
- lock_claim: /Users/ronnyworks/code/agentic-spine/.worktrees/state-authority-framework-20260304/mailroom/state/orchestration/LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/locks/C.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
