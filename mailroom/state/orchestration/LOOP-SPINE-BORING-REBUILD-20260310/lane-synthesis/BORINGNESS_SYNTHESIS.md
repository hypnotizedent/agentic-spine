# Boringness Synthesis

## What Must Stay In Spine

- Entry surfaces and the single front door: `AGENTS.md`, `CLAUDE.md`, `README.md`, `bin/ops`
- Declarative control-plane source: `ops/bindings/**`, `ops/commands/**`, `ops/lib/**`, `ops/capabilities.yaml`
- Governance plugins that enforce lifecycle, verification, orchestration, proposals, and documentation
- Canonical control-plane governance docs and deterministic fixtures
- Governance-only mailroom state: active loop scopes, active plans, active orchestration packets, gap state, and a small declarative state set

## What Must Leave

- Live runtime payloads: `mailroom/inbox/**`, `mailroom/logs/**`, non-governance `mailroom/state/**`, `runtime/**`
- All receipts and audit payloads under `receipts/**`
- Runtime implementation source and most extension plugins under `ops/runtime/**`, `ops/engine/**`, and large parts of `ops/plugins/**`
- Domain/product/operator doc surfaces now living in `docs/product/**`, `docs/brain/**`, `docs/runbooks/**`, `docs/pillars/**`, domain-heavy governance docs, and governance-path product plans or operator checklists

## Why

The boring spine should be declarative, canonical, and enforcement-heavy. Anything that is live state, generated proof, domain runtime logic, or operator-local customization increases ceremony and split-brain risk without improving the control plane itself.
