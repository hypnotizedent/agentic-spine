# Public GitHub Starter Surface

## Include

- `AGENTS.md`, `CLAUDE.md`, `README.md`
- `bin/ops`
- Minimal `ops/` control-plane core:
  `ops/bindings/**`, `ops/commands/**`, `ops/lib/**`, `ops/capabilities.yaml`
- Governance plugins only:
  `ops/plugins/session/**`, `ops/plugins/verify/**`, `ops/plugins/docs/**`, `ops/plugins/loops/**`, `ops/plugins/lifecycle/**`, `ops/plugins/orchestration/**`, `ops/plugins/proposals/**`, `ops/plugins/authority/**`, `ops/plugins/audit/**`, `ops/plugins/agent/**`, `ops/plugins/work-index/**`, `ops/plugins/budget/**`, `ops/plugins/surface/**`
- `surfaces/verify/**`
- `surfaces/commands/**`
- Canonical docs only:
  `docs/governance/SPINE.md`, `docs/governance/SESSION_PROTOCOL.md`, selected `docs/core/**`, and generated entry-surface projections
- Deterministic fixtures under `fixtures/`
- CI wiring that validates boringness and fast verify

## Exclude

- `mailroom/**` runtime payloads
- `receipts/**`
- `runtime/**`
- `ops/runtime/**`, `ops/engine/**`
- Domain-heavy plugins and product/operator extensions
- `docs/archive/**`, `docs/legacy/**`, `docs/planning/**`
- Local/private surfaces:
  `.environment.yaml`, `.identity.yaml`, `.mcp.json`, `.claude/settings.json`, `.spine/**`
- Staged/archive debt and rogue gate surfaces

## Product Shape

- The public repo should be a starter control plane, not a mirror of Ronny's live operator forge.
- The starter ships policies, bindings, verify, orchestration, and fixtures.
- Runtime implementations, domain packs, and operator-specific surface integrations belong in the extracted foundation or in private/operator repos.

## Private Operator Surface

Keep private:

- Local MCP config and IDE hooks
- Internal domain docs and domain plugins tied to Ronny's live infrastructure
- Runtime/evidence stores
- Environment identity and tenant-specific bootstrap state

