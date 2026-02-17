---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
scope: compose-locations
---

# Compose Authority Map

Purpose: prevent "compose guessing" by defining where authoritative compose lives, and where the *live* compose directories are on each host.

## Rules (Non-Negotiables)

- **Never guess live paths** like `/opt/stacks` vs `~/stacks`.
  - Live paths are declared in `ops/bindings/docker.compose.targets.yaml` (SSOT).
- **VM-infra compose SSOT (sanitized)** lives in this repo under `ops/staged/**`.
- **Workbench compose** (`/Users/ronnyworks/code/workbench/infra/compose/**`) is a *supporting/reference surface* for non-VM-infra stacks.
- **Legacy ronny-ops compose is non-authoritative** and must not be used for deployment.
  - Example stale runtime copy: `/Users/ronnyworks/ronny-ops/infrastructure/cloudflare/tunnel/docker-compose.yml`

## VM-Infra Stacks (Spine-Owned, Canonical)

| Stack | Canonical Compose (Spine) |
|------|----------------------------|
| cloudflared | `ops/staged/cloudflared/docker-compose.yml` |
| caddy-auth (Caddy + Authentik) | `ops/staged/caddy-auth/docker-compose.yml` |
| pihole | `ops/staged/pihole/docker-compose.yml` |
| vaultwarden | `ops/staged/vaultwarden/docker-compose.yml` |
| secrets (Infisical) | `ops/staged/secrets/docker-compose.yml` |
| dev-tools (gitea) | `ops/staged/dev-tools/gitea/docker-compose.yml` |
| observability (prometheus) | `ops/staged/observability/prometheus/docker-compose.yml` |
| observability (grafana) | `ops/staged/observability/grafana/docker-compose.yml` |
| observability (loki) | `ops/staged/observability/loki/docker-compose.yml` |
| observability (uptime-kuma) | `ops/staged/observability/uptime-kuma/docker-compose.yml` |
| observability (node-exporter) | `ops/staged/observability/node-exporter/docker-compose.yml` |
| download-stack | `ops/staged/download-stack/docker-compose.yml` |
| streaming-stack | `ops/staged/streaming-stack/docker-compose.yml` |

## Workbench Compose (Supporting / Reference)

Workbench repo path: `/Users/ronnyworks/code/workbench/infra/compose/**`

Examples:

| Stack | Workbench Path |
|------|-----------------|
| mint-os | `/Users/ronnyworks/code/workbench/infra/compose/mint-os/` |
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
