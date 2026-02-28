# W60 Concern Authority Map

Date: 2026-02-28 (UTC)
Source contract: `ops/bindings/single.authority.contract.yaml`

| concern | authority_winner | non_authoritative_surfaces | lifecycle_state |
|---|---|---|---|
| services | `docs/governance/SERVICE_REGISTRY.yaml` | `ops/bindings/services.health.yaml` (projection), `ops/bindings/docker.compose.targets.yaml` (projection) | active |
| gates | `ops/bindings/gate.registry.yaml` | `AGENTS.md` (projection), `CLAUDE.md` (projection) | active |
| agents/domains | `ops/bindings/agents.registry.yaml` | `ops/bindings/terminal.role.contract.yaml` (projection), `docs/governance/domains/README.md` (projection) | active |
| mcpjungle config root | `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/servers/README.md` | `/Users/ronnyworks/code/workbench/mcpjungle/servers/README.md` (projection) | active |
| supplier decisions | `/Users/ronnyworks/code/mint-modules/docs/CANONICAL/MINT_SUPPLIER_DECISIONS_V3.yaml` | `...V2.yaml` (tombstoned), `...V1.yaml` (tombstoned) | active |
| supplier sync contract | `/Users/ronnyworks/code/mint-modules/docs/CANONICAL/MINT_SUPPLIER_SYNC_CONTRACT_V2.md` | `...V1.md` (tombstoned) | active |
| staged compose authority | `ops/staged/README.md` | `.archive/staged/README.md` (projection) | active |

## Marker Policy

- Projection surfaces must declare `projection_of` and `authority_state: projection`.
- Tombstoned surfaces must declare `superseded_by` and `do_not_use_for_runtime: true`.
- Enforcement lock: `surfaces/verify/d275-single-authority-per-concern-lock.sh`.
