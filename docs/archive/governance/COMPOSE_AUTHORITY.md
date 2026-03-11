---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-28
scope: compose-locations
---

# Compose Authority Map

Purpose: prevent "compose guessing" by defining where authoritative compose lives, and where the *live* compose directories are on each host.

## Rules (Non-Negotiables)

- **Never guess live paths** like `/opt/stacks` vs `~/stacks`.
  - Live paths are declared in `ops/bindings/docker.compose.targets.yaml` (SSOT).
- **Typed VM-infra compose SSOT (sanitized)** lives under `agentic-foundation/ops/{infra,domains}/**`.
- **`agentic-foundation/ops/staged/` is interim only** for untyped transition material and decision residue.
- **Workbench compose** (`/Users/ronnyworks/code/workbench/infra/compose/**`) is a *supporting/reference surface* for non-VM-infra stacks.
- **Legacy ronny-ops compose is non-authoritative** and must not be used for deployment.
  - Example stale runtime copy: `$LEGACY_ROOT/infrastructure/cloudflare/tunnel/docker-compose.yml`

## VM-Infra Stacks (Spine-Owned, Canonical)

| Stack | Canonical Compose (Spine) |
|------|----------------------------|
| cloudflared | `ops/infra/cloudflared/docker-compose.yml` |
| caddy-auth (Caddy + Authentik) | `ops/infra/caddy-auth/docker-compose.yml` |
| pihole | `ops/infra/pihole/docker-compose.yml` |
| vaultwarden | `ops/infra/vaultwarden/docker-compose.yml` |
| secrets (Infisical) | `ops/infra/secrets/docker-compose.yml` |
| dev-tools (gitea) | `ops/domains/dev-tools/gitea/docker-compose.yml` |
| observability (prometheus) | `ops/infra/observability/prometheus/docker-compose.yml` |
| observability (grafana) | `ops/infra/observability/grafana/docker-compose.yml` |
| observability (loki) | `ops/infra/observability/loki/docker-compose.yml` |
| observability (uptime-kuma) | `ops/infra/observability/uptime-kuma/docker-compose.yml` |
| observability (node-exporter) | `ops/infra/observability/node-exporter/docker-compose.yml` |
| download-stack | `ops/domains/download-stack/docker-compose.yml` |
| streaming-stack | `ops/domains/streaming-stack/docker-compose.yml` |

## Workbench Compose (Supporting / Reference)

Workbench repo path: `/Users/ronnyworks/code/workbench/infra/compose/**`

Examples:

| Stack | Workbench Path |
|------|-----------------|
| mint-os | `/Users/ronnyworks/code/workbench/infra/compose/mint-os/` |
| media-stack | `/Users/ronnyworks/code/workbench/infra/compose/media-stack/docker-compose.yml` |
| finance | `/Users/ronnyworks/code/workbench/infra/compose/finance/docker-compose.yml` |
| communications-stack mail-archiver | `/opt/stacks/communications-stack/docker-compose.yml` (VM 214) |
| monitoring | `/Users/ronnyworks/code/workbench/infra/compose/monitoring/docker-compose.yml` |
| pihole | `/Users/ronnyworks/code/workbench/infra/compose/pihole/docker-compose.yml` |
| n8n | `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml` |
| dashy | `/Users/ronnyworks/code/workbench/infra/compose/dashy/docker-compose.yml` |
| mcpjungle | `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml` |
| storage (legacy) | `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml` |

## Live Runtime Directories (Operations)

To check what is deployed and where it lives on each host:

```bash
./bin/ops cap run docker.compose.status
```

Binding SSOT for live paths:

- `ops/bindings/docker.compose.targets.yaml`
