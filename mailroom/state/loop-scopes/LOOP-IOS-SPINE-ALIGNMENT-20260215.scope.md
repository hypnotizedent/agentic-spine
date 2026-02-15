---
id: LOOP-IOS-SPINE-ALIGNMENT-20260215
status: active
opened: 2026-02-15
owner: "@ronny"
gaps:
  - GAP-OP-444
---

# LOOP: iOS Spine Alignment

## Objective

Harden the Claude iOS session bootloader skill so cloud-runtime sessions route correctly to bridge/offline flows and avoid false "spine unavailable" messaging.

## Problem Statement

Current skill detection can classify sessions by tool names alone, which is unreliable in hosted runtimes where tool names are present but local filesystem/tailnet access is not. This causes confusing fallback language and inconsistent bridge behavior.

## Deliverables

1. Strengthened environment detection that verifies actual filesystem access before desktop path.
2. Bridge failure branch that distinguishes runtime reachability limits from true spine downtime.
3. Clear next actions for token prompt, bridge retry, and offline handoff mode.

## Acceptance Criteria

1. Skill explicitly verifies read access to `~/code/agentic-spine` before desktop mode.
2. DNS/health failures on `macbook.taile9480.ts.net` produce "bridge unreachable from this runtime" messaging, not "spine unavailable".
3. Skill keeps bridge contract endpoints (`/health`, `/loops/open`, `/rag/ask`, `/cap/run`) and auth headers explicit.

## Constraints

1. Documentation/skill-only update in this loop.
2. No bridge server runtime behavior changes.
