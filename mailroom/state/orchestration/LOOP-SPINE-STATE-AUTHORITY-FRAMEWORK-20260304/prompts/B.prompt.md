# Worker Kickoff Prompt (B)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304"
export SPINE_ORCH_LOOP_ID="LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="B"
export SPINE_ORCH_SESSION_ID="kickoff-20260304T230411Z-B"
cd "/Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/B"
git checkout "LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/b"
git status --short --branch
```

## Worker Contract

- lane: B
- agent_id: lane-b
- branch: LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/b
- worktree: /Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/B
- packet: /Users/ronnyworks/code/agentic-spine/.worktrees/state-authority-framework-20260304/mailroom/state/orchestration/LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/packet.yaml
- lock_claim: /Users/ronnyworks/code/agentic-spine/.worktrees/state-authority-framework-20260304/mailroom/state/orchestration/LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/locks/B.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
