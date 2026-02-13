---
loop_id: LOOP-BASELINE-STABILIZATION-WAVE-20260213
status: closed
severity: medium
owner: "@ronny"
created: 2026-02-13
---

# Loop Scope: Baseline Stabilization Wave

## Goal
Close open gaps 266-269, fix residual inbox observability drift (partial close from 263), and leave spine at a hard baseline with spine.verify PASS 84/84, gaps.status 0 open, and ops status surfaces truthful mailbox/proposal state.

## Gaps
- GAP-OP-266: archive candidates cleanup
- GAP-OP-267: docs condense/pointer-shim consistency
- GAP-OP-268: doc freshness normalization
- GAP-OP-269: docs self-management capability coverage
- GAP-OP-270: inbox lane observability parity (follow-up from partial GAP-OP-263 fix)

## Lanes
- Lane D: GAP-OP-266 (archive candidates)
- Lane E: GAP-OP-267 (condense + pointer shims)
- Lane F: GAP-OP-268 (freshness)
- Lane G: GAP-OP-269 (docs self-management capabilities)
- Lane H: GAP-OP-270 (residual observability/proposal parity)

## Scope
- docs/brain/_imported/claude-commands/
- docs/governance/CANONICAL.md
- docs/legacy/_imports/
- docs/governance/AGENT_GOVERNANCE_BRIEF.md
- docs/governance/AGENTS_GOVERNANCE.md
- docs/governance/AGENT_BOUNDARIES.md
- AGENTS.md, CLAUDE.md
- docs/core/GOVERNANCE_MINIMUM.md
- docs/core/CANONICAL_DOCS.md
- docs/ACTIVE_DOCS_INDEX.md
- docs/README.md
- docs/governance/GOVERNANCE_INDEX.md
- docs/governance/_index.yaml
- docs/core/CORE_LOCK.md
- docs/brain/memory.md
- docs/core/AGENT_CONTRACT.md
- docs/core/AGENT_OUTPUT_CONTRACT.md
- surfaces/verify/d58-ssot-freshness-lock.sh
- ops/capabilities.yaml
- ops/bindings/capability_map.yaml
- ops/plugins/docs/bin/
- ops/commands/status.sh
- ops/plugins/proposals/bin/
- surfaces/verify/d83-proposal-queue-health-lock.sh
