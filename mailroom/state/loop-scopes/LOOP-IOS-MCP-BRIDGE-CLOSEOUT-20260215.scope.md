---
id: LOOP-IOS-MCP-BRIDGE-CLOSEOUT-20260215
status: active
opened: 2026-02-15
owner: "@ronny"
gaps:
  - GAP-OP-437
---

# LOOP: iOS MCP Bridge Closeout

## Objective

Lock iOS/mobile bridge access guidance to the current tailnet-served contract and keep skill bootstrap content tracked in-repo for deterministic mobile setup.

## Problem Statement

Session protocol mobile/remote bridge references and iOS bootstrap skill surface were in flight without a registered loop/gap boundary, creating governance ambiguity during closeout.

## Deliverables

1. Session protocol reflects canonical mobile/tailnet bridge routing pattern used in production.
2. Claude iOS bootstrap skill content is tracked in `surfaces/claude-ai-skill/SKILL.md`.
3. Verification receipt confirms no governance regressions.

## Acceptance Criteria

1. `docs/governance/SESSION_PROTOCOL.md` mobile/remote bridge examples match current tailnet path contract.
2. `surfaces/claude-ai-skill/SKILL.md` exists in repo and documents bridge endpoints including `/cap/run` and `/rag/ask`.
3. `./bin/ops cap run spine.verify` completes without new regressions introduced by this loop.

## Constraints

1. No runtime bridge behavior changes in this loop; documentation + skill surface only.
2. Keep desktop localhost guidance intact.
