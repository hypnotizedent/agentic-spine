---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-09
scope: shop-vm-architecture
derived_from:
  - docs/governance/SERVICE_REGISTRY.yaml
  - docs/governance/DEVICE_IDENTITY_SSOT.md
  - docs/governance/DOMAIN_ROUTING_REGISTRY.yaml
  - docs/governance/STACK_REGISTRY.yaml
  - ops/bindings/infra.placement.policy.yaml
  - ops/bindings/infra.relocation.plan.yaml
---

# Shop VM Architecture (Post Docker-Host Decomposition)

Purpose: a single, human-readable reference for how the shop estate is structured
after decomposing the monolithic `docker-host` (VM 200) into purpose-built VMs.

This is an **architecture overview**, not the lowest-level SSOT. If any detail in
this doc conflicts with a registry, defer to:
- `docs/governance/SERVICE_REGISTRY.yaml` (what runs where)
- `docs/governance/DEVICE_IDENTITY_SSOT.md` (hostnames + IPs)
- `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml` (hostname routing intent)
- `docs/governance/STACK_REGISTRY.yaml` (stack inventory)

## Executive Summary

The shop hypervisor (`pve`, R730XD) runs multiple VMs with clear responsibilities:
- `infra-core` (VM 204): ingress connector, DNS, secrets, auth, core infra
- `observability` (VM 205): metrics/logs/uptime monitoring
- `dev-tools` (VM 206): git forge + CI runner
- `ai-consolidation` (VM 207): AnythingLLM + Qdrant
- `automation-stack` (VM 202): n8n + ollama + open-webui (+ internal postgres/redis)
- Media split: `download-stack` (VM 209) + `streaming-stack` (VM 210)
- Legacy: `docker-host` (VM 200) retains **Mint OS business workloads only**

## Topology (Mental Model)

```
Internet
  └── Cloudflare (DNS + Tunnel)
        └── cloudflared connector (infra-core)
              ├── Caddy reverse proxy + Authentik (infra-core)
              │     ├── infisical (infra-core)
              │     ├── vaultwarden (infra-core)
              │     └── pihole admin (infra-core, :8053)
              ├── observability (Grafana, Prometheus, Loki, Uptime Kuma)
              ├── dev-tools (Gitea)
              ├── automation-stack (n8n, Open WebUI, Ollama)
              ├── ai-consolidation (AnythingLLM, Qdrant)
              ├── download-stack (arrs, SABnzbd, Tdarr, etc.)
              ├── streaming-stack (Jellyfin, Navidrome, Jellyseerr, Bazarr, etc.)
              └── docker-host (Mint OS + MinIO only; legacy)
```

## VM Responsibilities (What Belongs Where)

### infra-core (VM 204)
Role: **the “platform edge”** for the homelab.
- CF tunnel connector (`cloudflared`)
- Reverse proxy + auth (`caddy` + `authentik`)
- DNS (`pihole`)
- Secrets (`infisical`)
- Human creds (`vaultwarden`)

Rule: If you need “public ingress”, “auth”, “secrets”, “DNS”, start here.

### observability (VM 205)
Role: monitoring visibility (no runtime dependencies from other systems).
- `prometheus`, `grafana`, `loki`, `uptime-kuma`, `node-exporter`

Rule: Monitoring lives here. Do not deploy monitoring stacks on `docker-host`.

### dev-tools (VM 206)
Role: software delivery infrastructure.
- `gitea`, `gitea-runner`, `gitea-postgres`

### ai-consolidation (VM 207)
Role: RAG/AI services migrated off the MacBook.
- `anythingllm`, `qdrant`

### automation-stack (VM 202)
Role: workflow automation and local LLM runtime.
- `n8n`, `ollama`, `open-webui`
- internal `automation-postgres`, `automation-redis`

Note: this VM may contain legacy artifacts. Treat it as “useful but not sacred”
until it is fully spine-governed.

### docker-host (VM 200) (legacy, shrinking)
Role: **Mint OS business workloads only**.
- `mint-os-api`, `mint-os-postgres`, `mint-os-redis`
- `minio` (object storage)
- related Mint OS frontends/jobs/finance stack containers

Rule: No new infrastructure services on `docker-host`. New infra goes to a
purpose-built VM or a new VM.

### Media
Legacy monolith (`media-stack`, VM 201) is being decommissioned in favor of:
- `download-stack` (VM 209): IO-heavy download + arr tooling
- `streaming-stack` (VM 210): latency-sensitive streaming services

## “docker-host Is Being Chopped Up” (What That Means Operationally)

The decomposition is complete for core infra, but the long tail is:
- hunting stale references in workbench docs/scripts that still point to `docker-host`
- ensuring `docker-host` only contains Mint OS workloads
- moving any remaining “infrastructure-ish” containers off `docker-host` as separate scoped loops

The canonical migration map and closure evidence for the original restructure is:
`mailroom/state/loop-scopes/LOOP-INFRA-VM-RESTRUCTURE-20260206.scope.md`.

## How To Move A Service (Spine-Governed Checklist)

Use this checklist whenever you move something off `docker-host` or between VMs.

1. Decide target VM using `ops/bindings/infra.placement.policy.yaml`.
2. Deploy on the target VM (compose under `/opt/stacks/<stack>` on-host).
3. Update SSOTs (in this order):
   - `docs/governance/SERVICE_REGISTRY.yaml` (service -> host/port/health)
   - `ops/bindings/services.health.yaml` (health probe endpoint)
   - `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml` (if public hostname changes)
   - `ops/bindings/backup.inventory.yaml` (if backup expectations change)
4. Verify with receipts:
   - `./bin/ops cap run services.health.status`
   - `./bin/ops cap run spine.verify`
   - `./bin/ops cap run backup.status` (if backup targets involved)

## Where The Truth Lives (Pointers)

- Service locations: `docs/governance/SERVICE_REGISTRY.yaml`
- Hostnames/IPs: `docs/governance/DEVICE_IDENTITY_SSOT.md`
- Public routing intent: `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml`
- Stack inventory: `docs/governance/STACK_REGISTRY.yaml`
- Placement policy: `ops/bindings/infra.placement.policy.yaml`
- Current relocations: `ops/bindings/infra.relocation.plan.yaml`

