# Worker Kickoff Prompt (LANE-CHAIN)

## Environment Preamble (run exactly)

```bash
export SPINE_LOOP_ID="LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303"
export SPINE_ORCH_LOOP_ID="LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303"
export SPINE_ORCH_ROLE="worker"
export SPINE_ORCH_LANE="LANE-CHAIN"
export SPINE_ORCH_SESSION_ID="kickoff-20260303T163303Z-LANE-CHAIN"
cd "/Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/LANE-CHAIN"
git checkout "LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/lane-chain"
git status --short --branch
```

## Worker Contract

- lane: LANE-CHAIN
- agent_id: lane-lane-chain
- branch: LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/lane-chain
- worktree: /Users/ronnyworks/code/agentic-spine/.worktrees/orchestration/LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/LANE-CHAIN
- packet: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/packet.yaml
- lock_claim: /Users/ronnyworks/code/agentic-spine/mailroom/state/orchestration/LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303/locks/LANE-CHAIN.lock

Execute only within this lane worktree/branch. Report receipt run keys and changed file list for integration sequencing.
