# n8n-agent Contract

> **Status:** registered
> **Domain:** automation (n8n workflows)
> **Owner:** @ronny
> **Created:** 2026-02-09
> **Loop:** LOOP-N8N-AGENT-20260209

---

## Identity

- **Agent ID:** n8n-agent
- **Domain:** automation (workflow governance)
- **Implementation:** `~/code/workbench/agents/n8n/`
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Workflow naming + organization | n8n |
| Export/import discipline (repo-as-log) | n8n + workbench |
| Execution triage + failure review | n8n |
| Safe manual execution policy | n8n |

## Defers To Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Stack deployment / restart | `ops/bindings/docker.compose.targets.yaml` + `docker.compose.*` capabilities |
| Health probes | `ops/bindings/services.health.yaml` |
| Routing/DNS/tunnel | `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml` |
| Secrets policy/inventory | `docs/governance/SECRETS_POLICY.md` + Infisical |
| Backups | `backup.*` capabilities + `ops/bindings/backup.inventory.yaml` |

## Invocation

On-demand via Claude Code session. No watchers, no cron, no schedulers (WORKBENCH_CONTRACT compliance).

## Endpoint

| Service | Host | URL |
|---------|------|-----|
| n8n | automation-stack (VM 202) | https://n8n.ronny.works |

