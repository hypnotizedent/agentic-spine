# Worker Kickoff Prompt (LANE-HA)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303"
export SPINE_ORCH_LOOP_ID="LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="LANE-HA"
export SPINE_ORCH_SESSION_ID="kickoff-20260303T163303Z-LANE-HA"
cd "/Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/LANE-HA"
git checkout "LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/lane-ha"
git status --short --branch
```

## Worker Contract

- lane: LANE-HA
- agent_id: lane-lane-ha
- branch: LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/lane-ha
- worktree: /Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/LANE-HA
- packet: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/packet.yaml
- lock_claim: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/locks/LANE-HA.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
