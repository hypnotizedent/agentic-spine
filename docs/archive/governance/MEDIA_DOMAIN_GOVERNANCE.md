---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-26
scope: media-domain-governance
---

# Media Domain Governance

> **Loop:** LOOP-MEDIA-GOVERNANCE-NORMALIZATION-20260226

---

## 1. Canonical Naming Map

The media domain uses three distinct identifiers in different contexts:

| Identifier | Context | When to Use |
|------------|---------|-------------|
| `media-agent` | Agent ID | Routing dispatch, agent registry, capability ownership, MCP server identity |
| `DOMAIN-MEDIA-01` | Terminal role | Worker picker, terminal launcher, session wiring, write_scope enforcement |
| `media-stack` | Tenant/infra ID | Infisical secrets paths, tenant profiles, VM infrastructure, service onboarding |

**Rules:**
- `discovered_by` in gaps: Use loop ID (e.g., `LOOP-MEDIA-...-YYYYMMDD`) for loop-driven discovery, or `media-agent` for agent-driven discovery. Never mix terminal role IDs with agent prefixes.
- Routing dispatch: Always `agent_id: media-agent`, `terminal_affinity: [DOMAIN-MEDIA-01]`.
- Secrets paths: Always reference `media-stack` tenant (e.g., `/spine/vm-infra/media-stack/download`).

## 2. Authoritative Files

| File | Purpose | SSOT For |
|------|---------|----------|
| `ops/agents/media-agent.contract.md` | Agent contract | Ownership boundaries, drift gates, quality governance |
| `ops/bindings/agents.registry.yaml` | Agent registry | Capabilities, MCP config, implementation status, project_binding |
| `ops/bindings/routing.dispatch.yaml` | Capability routing | Per-capability dispatch (agent_id, terminal_affinity, approval) |
| `ops/bindings/capability.domain.catalog.yaml` | Domain catalog | Canonical capability list, owner repo/path |
| `ops/bindings/terminal.role.contract.yaml` | Terminal role | DOMAIN-MEDIA-01 scope, write permissions, capability access |
| `ops/bindings/terminal.launcher.view.yaml` | Launcher view | UI metadata (label, description, health_url, capability_count) |
| `ops/bindings/media.services.yaml` | Service inventory | All media containers, ports, health endpoints, status, dependencies |
| `ops/bindings/media.import.policy.yaml` | Import policy | Tier system, banned list types, archive routing |
| `ops/bindings/mcp.runtime.contract.yaml` | MCP registration | Required/optional MCP servers per surface |
| `ops/bindings/service.onboarding.contract.yaml` | Onboarding | deploy_stack_id, infisical_namespace, runbook paths |
| `ops/bindings/tenants/media-stack.yaml` | Tenant profile | VM IDs, IPs, NFS mounts, dependency chains |
| `ops/bindings/gate.domain.profiles.yaml` | Gate profile | Media domain gate IDs, path triggers, capability prefixes |

## 3. Required Invariants

| Invariant | Enforced By |
|-----------|-------------|
| Enabled Radarr import lists have tier tags | D240 |
| No TMDb keyword/company lists enabled | D240 |
| Fill-later tier uses archive root + unmonitored | D240 |
| Port collision matrix respected | D106 |
| NFS mounts present and healthy | D108 |
| Health endpoints reachable for probed services | D109 |
| Compose parity between staged and live | D107 |
| HA add-on overlap prevented | D110 |
| Recyclarr language CFs present | D220 |
| Music pipeline health (IntroSkipper, NFS I/O, Lidarr root, Docker net, SQLite) | D228-D232 |

## 4. Capability Surface

### Registered Capabilities (routing.dispatch.yaml)

| Capability | Safety | Approval | Agent |
|------------|--------|----------|-------|
| `media.status` | read-only | auto | media-agent |
| `media.health.check` | read-only | auto | media-agent |
| `media.service.status` | read-only | auto | media-agent |
| `media.metrics.today` | read-only | auto | media-agent |
| `media.nfs.verify` | read-only | auto | media-agent |
| `media.backup.create` | mutating | manual | media-agent |
| `media.backup.restore` | mutating | manual | media-agent |
| `homarr.config.generate` | read-only | auto | media-agent |
| `media.stack.restart` | mutating | manual | media-agent |

### Extended Capabilities (capabilities.yaml, not yet in routing.dispatch)

| Capability | Safety | Status |
|------------|--------|--------|
| `media.music.metrics.today` | read-only | registered, not routed |
| `media.vpn.health` | read-only | registered, not routed |
| `media.slskd.status` | read-only | registered, not routed |
| `media.soularr.status` | read-only | registered, not routed |
| `media.qbittorrent.status` | read-only | registered, not routed |
| `media.storage.status` | read-only | registered, not routed |
| `media.sonarr.metrics.today` | read-only | registered, not routed |
| `media.pipeline.trace` | read-only | registered, not routed |
| `media-content-snapshot-refresh` | read-only | registered, not routed |
| `recyclarr.sync` | mutating | routed, domain: media |

## 5. Agent Operator Flow

```
status          ->  ./bin/ops cap run media.status
diagnose        ->  ./bin/ops cap run media.health.check
                    ./bin/ops cap run media.service.status
                    ./bin/ops cap run media.nfs.verify
remediate       ->  ./bin/ops cap run media.stack.restart  (manual approval)
                    ./bin/ops cap run recyclarr.sync       (manual approval)
verify          ->  ./bin/ops cap run verify.pack.run media
receipt         ->  Check receipts/sessions/ for RCAP-* entries
```

## 6. Service Health Classification

Services in `media.services.yaml` use this health governance model:

| health value | Meaning |
|-------------|---------|
| `/path` | HTTP health endpoint, probed by D109 |
| `null` + `health_reason: no_http_port` | Daemon/sidecar with no HTTP listener — exempt from D109 |
| `null` + `health_reason: auth_gated` | HTTP port exists but all routes require auth — exempt from D109 |
| `null` + status: `parked` | Intentionally stopped — exempt from all probes |

## 7. MCP Governance

- Media-agent MCP is registered as an **optional** server for `claude_desktop` in `mcp.runtime.contract.yaml`.
- Local implementation: `~/code/workbench/agents/media/tools/`
- MCPJungle mirror: `~/code/workbench/infra/compose/mcpjungle/servers/media-stack/`
- Parity enforced by D66 gate (post-facto detection).
- Open gap: 5 missing MCP tools (GAP-OP-963), parity hook (GAP-OP-964), secrets pattern (GAP-OP-965).

## 8. Canonical Operator Dashboard (Homarr)

- `homarr` is the canonical operator dashboard for media runtime visibility.
- Service inventory source of truth remains `ops/bindings/media.services.yaml`.
- Dashboard data is generated via `homarr.config.generate` to keep UI tiles aligned with governed service inventory and VM split (download-stack vs streaming-stack).
- Homarr health remains covered by `services.health.yaml` + media/observability verify surfaces.

## 9. Cross-Stack Secret Access Pattern

When a service in one stack needs a secret owned by another stack path (example: `autopulse` on `download-stack` consuming `JELLYFIN_API_TOKEN` from streaming path):

1. Keep canonical ownership in `secrets.namespace.policy.yaml` path overrides.
2. Annotate governed exception intent in `rules.cross_stack_consumers`.
3. Ensure compose wiring is explicit in the consuming stack (`AUTOPULSE__TARGETS__JELLYFIN__TOKEN=${JELLYFIN_API_TOKEN}`).
4. Inject both required secret paths during deploy:

```bash
infisical run --path /spine/vm-infra/media-stack/download \
  --path /spine/vm-infra/media-stack/streaming \
  -- docker compose up -d
```

5. Verify with D224 to confirm canonical routing + runtime parity.
