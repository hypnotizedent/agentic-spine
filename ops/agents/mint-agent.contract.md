# mint-agent Contract

> **Status:** active
> **Domain:** mint
> **Owner:** @ronny
> **Created:** 2026-02-12
> **Last Updated:** 2026-02-22
> **Loop:** LOOP-MINT-AGENT-CANONICALIZATION-20260216

---

## Identity

- **Agent ID:** mint-agent
- **Domain:** mint-modules (artwork, quote-page, order-intake, pricing, shipping, suppliers, finance-adapter, payment)
- **Workbench Implementation (canonical):** `~/code/workbench/agents/mint-agent/`
- **Module Tool Source (product repo):** `~/code/mint-modules/agents/mcp-server/`
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | Services | VMs |
|---------|----------|-----|
| Module endpoint health probes | files-api, order-intake, quote-page, pricing, suppliers, shipping, finance-adapter | VM 213 (mint-apps) |
| Seed intake data query | files-api (artwork) | VM 213 (mint-apps) |
| Intake contract validation | order-intake | VM 213 (mint-apps) |
| Deploy/runtime status checks | mint-apps + mint-data stacks | VM 213 + VM 212 |
| Migration preflight checks | mint-data postgres | VM 212 (mint-data) |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Compose deployment and runtime paths | `ops/bindings/docker.compose.targets.yaml` |
| Health registry and service parity | `ops/bindings/services.health.yaml` + D23 |
| Secrets | Infisical `/spine/services/artwork/`, `/spine/services/quote-page/`, `/spine/services/order-intake/` |
| SSH targets | `ops/bindings/ssh.targets.yaml` (mint-apps, mint-data) |
| Backup and infrastructure lifecycle | `ops/bindings/backup.inventory.yaml`, `ops/bindings/vm.lifecycle.yaml` |
| Governed execution path | `ops/plugins/mint/` capabilities (`mint.*`) |

## Invocation

Primary path is spine capability execution with receipts:

- `mint.modules.health`
- `mint.seeds.query`
- `mint.intake.validate`
- `mint.deploy.status`
- `mint.migrate.dryrun`

Optional MCP surface (read-only tooling) is sourced from `mint-modules` for product-local iteration.
No watchers or cron in workbench.

## Endpoints

| VM | Tailscale IP | Role |
|----|-------------|------|
| 213 (mint-apps) | 100.79.183.14 | App plane: files-api (:3500), order-intake (:3400), quote-page (:3341), pricing (:3700), suppliers (:3800), shipping (:3900), finance-adapter (:3600) |
| 212 (mint-data) | 100.106.72.25 | Data plane: PostgreSQL (:5432), MinIO (:9000), Redis (:6379) |

## Read-Only Tool Surface

| Tool | Safety | Description |
|------|--------|-------------|
| `mint.modules.health` | read-only | Health probe for mint app/data endpoints |
| `mint.seeds.query` | read-only | Query artwork seed records on mint-data |
| `mint.intake.validate` | read-only | Validate intake payload against order-intake contract |
| `mint.deploy.status` | read-only | Read container status on mint-apps + mint-data |
| `mint.migrate.dryrun` | read-only | Check pending migrations without applying changes |

> **Mutation policy:** `mint.deploy.sync` is the single authorized mutation capability. Requires: `approval: manual`, single-module targeting, pre-built image only (no build-on-VM), env preflight, post-deploy runtime proof. See `docs/SOPs/MINT_DEPLOY_PROMOTION_SOP_V1.md`.

## Mutating Tool Surface

| Tool | Safety | Description |
|------|--------|-------------|
| `mint.deploy.sync` | mutating (manual) | Promote pre-built image for single module to VM 213 |
