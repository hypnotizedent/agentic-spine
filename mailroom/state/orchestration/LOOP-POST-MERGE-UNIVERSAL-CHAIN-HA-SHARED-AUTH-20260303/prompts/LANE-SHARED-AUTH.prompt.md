# Worker Kickoff Prompt (LANE-SHARED-AUTH)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303"
export SPINE_ORCH_LOOP_ID="LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="LANE-SHARED-AUTH"
export SPINE_ORCH_SESSION_ID="kickoff-20260303T163303Z-LANE-SHARED-AUTH"
cd "/Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/LANE-SHARED-AUTH"
git checkout "LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/lane-shared-auth"
git status --short --branch
```

## Worker Contract

- lane: LANE-SHARED-AUTH
- agent_id: lane-lane-shared-auth
- branch: LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/lane-shared-auth
- worktree: /Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/LANE-SHARED-AUTH
- packet: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/packet.yaml
- lock_claim: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/locks/LANE-SHARED-AUTH.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
