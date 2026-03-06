---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-05
scope: docs-entrypoint
---

# Agentic Spine Docs

Minimal landing page for live docs after the lean reset.

## Read First

- [governance/SPINE.md](governance/SPINE.md) - single canonical governance contract
- [governance/SESSION_PROTOCOL.md](governance/SESSION_PROTOCOL.md) - session entry and closeout rules
- [core/SPINE_STATE.md](core/SPINE_STATE.md) - what belongs in the repo and what does not

## Canonical Governance

- [governance/AGENT_GOVERNANCE_BRIEF.md](governance/AGENT_GOVERNANCE_BRIEF.md)
- [governance/STACK_REGISTRY.yaml](governance/STACK_REGISTRY.yaml)
- [governance/SERVICE_REGISTRY.yaml](governance/SERVICE_REGISTRY.yaml)
- [governance/DEVICE_IDENTITY_SSOT.md](governance/DEVICE_IDENTITY_SSOT.md)
- [governance/MINILAB_SSOT.md](governance/MINILAB_SSOT.md)

## Domain Docs

Domain authority is one file per domain under [`docs/governance/domains/`](governance/domains/).
Keep additions there instead of creating new governance roots.

## Supporting Surfaces

- [brain/README.md](brain/README.md) - context-loading and memory rules
- [core/AGENTIC_GAP_MAP.md](core/AGENTIC_GAP_MAP.md) - extraction and boundary tracking
- [core/STACK_ALIGNMENT.md](core/STACK_ALIGNMENT.md) - stack inventory alignment notes
- [CONTRIBUTING.md](CONTRIBUTING.md) - doc placement and minimality rules

## Directory Map

- `docs/core/` - core contracts and state summaries
- `docs/governance/` - live governance and SSOTs
- `docs/governance/domains/` - one canonical doc per domain
- `docs/brain/` - agent context helpers
- `docs/planning/` - scoped plans and execution notes
- `docs/runbooks/` - operational runbooks
