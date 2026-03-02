---
loop_id: LOOP-MEDIA-MAINTAINERR-SEER-HUNTARR-RD-20260301
created: 2026-03-01
status: closed
owner: "@ronny"
scope: media
priority: medium
horizon: now
execution_readiness: runnable
objective: "Execute media-stack remediation: deprecate Huntarr, stabilize ARR request/download pipeline, deploy native replacement search automation, and produce governed receipts/handoff."
activation_trigger: manual
---

# Loop Scope: LOOP-MEDIA-MAINTAINERR-SEER-HUNTARR-RD-20260301

## Objective

Execute media-stack remediation: deprecate Huntarr, stabilize ARR request/download pipeline, deploy native replacement search automation, and produce governed receipts/handoff.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MEDIA-MAINTAINERR-SEER-HUNTARR-RD-20260301`

## Phases
- Step 1:  Runtime stabilization and health triage (ARR + downloader path)
- Step 2:  Huntarr deprecation + replacement rollout (arr-native-search)
- Step 3:  End-to-end verification (request/search/import/Jellyfin playback evidence)
- Step 4:  Docs/receipts/handoff closeout for next agents

## Success Criteria
- Huntarr removed from active runtime and disabled in health probes
- Replacement scheduler active and issuing native ARR search commands
- Evidence that Bourne title is present and direct-playable in Jellyfin
- Open blockers recorded with explicit "need Ronny approval" receipts

## Definition Of Done
- Runtime and SSOT reflect Huntarr deprecation state
- ARR/movie pipeline evidence captured in receipts and domain impact notes
- Session handoff artifact created with residual risks and next actions
