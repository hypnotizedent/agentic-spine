---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
scope: aof-product-contract
---

# AOF Product Contract

> Canonical definition of the Agentic Operations Framework (AOF) as a deployable product.

## What is AOF?

AOF is a governed operations framework that provides:
- **Spine**: Capability registry, drift gates, gap lifecycle, loop management
- **Surfaces**: Agent instruction surfaces (CLAUDE.md, AGENTS.md, slash commands)
- **Bindings**: SSOT configuration files (YAML) for infrastructure, services, secrets
- **Receipts**: Append-only execution audit trail

## Product Boundary

### Included
- `ops/` — capabilities, plugins, bindings, runtime
- `surfaces/` — verify gates, command templates
- `docs/governance/` — authoritative governance docs
- `mailroom/` — inbox, proposals, loop scopes
- `receipts/` — session execution ledger

### Excluded
- Domain-specific workloads (mint, media, finance)
- VM/host provisioning (infrastructure-as-code)
- Secret values (managed via Infisical)

## Versioning

- **v0.1** — Foundation: product contract, tenant schema, policy presets, deployment playbook, support SLO
- Versioning follows `vMAJOR.MINOR` with no patch level
- Breaking changes increment MAJOR

## Tenant Model

Each AOF deployment is scoped to a single **tenant** (operator + infrastructure set).
See `ops/bindings/tenant.profile.schema.yaml` for the tenant profile schema.

## Policy Model

AOF ships with named policy presets (strict, balanced, permissive).
See `ops/bindings/policy.presets.yaml` for definitions.

## Acceptance Gates

A deployment is valid when all drift gates pass (`spine.verify` exits 0).
See `docs/product/AOF_ACCEPTANCE_GATES.md` for the full gate contract.

## Support

See `docs/product/AOF_SUPPORT_SLO.md` for support commitments.
