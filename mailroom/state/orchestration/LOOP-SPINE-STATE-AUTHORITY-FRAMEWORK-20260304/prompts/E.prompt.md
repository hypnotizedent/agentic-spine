# Worker Kickoff Prompt (E)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304"
export SPINE_ORCH_LOOP_ID="LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="E"
export SPINE_ORCH_SESSION_ID="kickoff-20260304T230411Z-E"
cd "/Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/E"
git checkout "LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/e"
git status --short --branch
```

## Worker Contract

- lane: E
- agent_id: lane-e
- branch: LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/e
- worktree: /Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/E
- packet: /Users/ronnyworks/code/agentic-spine/.worktrees/state-authority-framework-20260304/mailroom/state/orchestration/LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/packet.yaml
- lock_claim: /Users/ronnyworks/code/agentic-spine/.worktrees/state-authority-framework-20260304/mailroom/state/orchestration/LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304/locks/E.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
