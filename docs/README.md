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

## Canonical Governance

- [governance/LOCAL_CONTROL_PLANE_CONTRACT.md](governance/LOCAL_CONTROL_PLANE_CONTRACT.md)
- [governance/STACK_REGISTRY.yaml](governance/STACK_REGISTRY.yaml)
- [governance/DEVICE_IDENTITY_SSOT.md](governance/DEVICE_IDENTITY_SSOT.md)
- [governance/MINILAB_SSOT.md](governance/MINILAB_SSOT.md)

## Domain Docs

Domain docs under [`docs/governance/domains/`](governance/domains/) are
supporting, domain-specific reference. They are not L1 entry doctrine.
Keep additions there instead of creating new governance roots.

## Supporting Surfaces

- [reference/brain/memory.md](reference/brain/memory.md) - context-loading and memory rules
- [contracts/](contracts/) - stable contract/policy docs that are still human-read

Deferred-intent plans are not authored in `docs/reference/`.
Use the governed plans authority:

- `./bin/ops cap run planning.plans.create -- ...`
- `./bin/ops cap run planning.plans.status -- --json`

Plan authority lives in runtime shared authority and projects to
`$SPINE_STATE/plans/PLAN-*.md`.

## Directory Map

- `docs/core/` - core contracts and state summaries
- `docs/contracts/` - stable human-read contracts referenced by bindings/plugins
- `docs/governance/` - live governance, conventions, and thin read-model entrypoints
- `docs/governance/domains/` - supporting domain-specific reference, not L1 entry doctrine
- `docs/reference/` - non-authoritative support material
- `docs/reference/generated/` - generated projections and legacy-generated notes that remain machine-useful but non-authoritative
- `docs/reference/brain/` - agent context helpers
- `docs/reference/mint/` - retained Mint reference packets and audits
- `docs/reference/media/` - retained media migration reference packets
- `docs/runbooks/` - operational runbooks
