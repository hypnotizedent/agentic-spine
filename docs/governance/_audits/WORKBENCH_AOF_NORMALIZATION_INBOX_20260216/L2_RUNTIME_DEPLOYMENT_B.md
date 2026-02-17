# Lane B — Runtime, Deploy, Containers (Run 2)

**Audit Date:** 2026-02-16
**Auditor:** OpenCode Terminal B (read-only)
**Scope:** `/Users/ronnyworks/code/workbench` compose files, deployment patterns, container configs

---

## Findings (Severity Ordered)

### P0 — MinIO Container Name Collision

- **Surface:** compose/infrastructure
- **Problem:** Two compose files declare `container_name: minio`, causing conflict if both deployed.
- **Impact:** Cannot run storage stack and mint-os stack simultaneously; second deployment fails with name conflict.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml:18`
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:50`
- **Canonical rule (expected):** One canonical MinIO instance; dependent stacks connect via shared network, not duplicate containers.
- **Recommended normalization:** Remove MinIO from mint-os compose file; mint-os already references `storage-network` and `mint-os-network` in storage compose. Consolidate to single MinIO in storage stack.

---

### P0 — Cloudflare Tunnel extra_hosts Drift Risk

- **Surface:** ingress/routing
- **Problem:** Tunnel compose hardcodes 17+ `extra_hosts` entries with Tailscale IPs that can change.
- **Impact:** If VM is relocated or re-IP'd, tunnel routing breaks silently; 502 errors for all public URLs.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/cloudflare/tunnel/docker-compose.yml:26-48`
- **Canonical rule (expected):** Service discovery via DNS or dynamic resolution, not static IP lists in compose files.
- **Recommended normalization:** Either (a) add comment header linking to DEVICE_IDENTITY_SSOT.md with sync requirement, or (b) migrate to internal DNS resolution via Pi-hole/coredns. Add D54/D59 sync gate to compose header.

---

### P1 — Inconsistent Compose Version Declaration

- **Surface:** compose/templates
- **Problem:** Some files declare `version: "3.8"` (storage, mint-os), others omit it entirely (template, n8n, dashy, mcpjungle, cloudflare).
- **Impact:** Inconsistent developer experience; no clear standard; potential parser confusion.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml:1` — has version
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:5` — has version
  - `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:1` — NO version
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:1` — NO version
- **Canonical rule (expected):** Docker Compose V2 deprecated the version field. Modern compose files should omit it.
- **Recommended normalization:** Remove `version:` from storage and mint-os compose files to match modern standard. Document in template README.

---

### P1 — Logging Configuration Missing Across Stacks

- **Surface:** compose/lifecycle
- **Problem:** Template defines `x-logging: &default-logging` with rotation (10m max, 3 files), but NO actual compose file uses it.
- **Impact:** Unbounded log growth; disk exhaustion risk on long-running containers.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:19-23` — defines anchor
  - All other compose files — no `logging:` sections
- **Canonical rule (expected):** All containers should have log rotation configured.
- **Recommended normalization:** Add `logging: *default-logging` (or inline equivalent) to all services in all compose files. For files without anchor, add inline config:
  ```yaml
  logging:
    driver: "json-file"
    options:
      max-size: "10m"
      max-file: "3"
  ```

---

### P1 — Network Declaration Pattern Inconsistency

- **Surface:** compose/networking
- **Problem:** Three different patterns for network declaration:
  1. Template: `name:` + `driver:` + `external: true` for tunnel_network
  2. n8n/dashy/mcpjungle: Just `driver: bridge`, no `name:` field
  3. mcpjungle: Networks declared BEFORE services (non-standard ordering)
- **Impact:** Inconsistent behavior; potential network isolation issues; harder to debug.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:124-129` — canonical pattern
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:132-134` — missing `name:`
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml:1-3` — networks before services
- **Canonical rule (expected):** Networks declared at bottom with explicit `name:` and `driver: bridge`. External networks declared with `external: true`.
- **Recommended normalization:**
  - Add `name: {stack}-network` to all internal networks
  - Move mcpjungle networks to bottom of file
  - Standardize order: services → volumes → networks

---

### P1 — Port Binding Scope Inconsistency

- **Surface:** compose/security
- **Problem:** Some services bind to all interfaces (`0.0.0.0` implied), others to localhost only.
  - dashy: `4000:8080` — binds to all interfaces
  - mint-os ports: `15432:5432`, `16379:6379` — binds to all interfaces
  - Template: `127.0.0.1:{APP_PORT}:{APP_PORT}` — localhost only
- **Impact:** Services unintentionally exposed on LAN; security surface larger than necessary.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/compose/dashy/docker-compose.yml:14`
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:22,39,51-52`
  - `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:40,104`
- **Canonical rule (expected):** Default to localhost binding (`127.0.0.1:host:container`) unless external access explicitly required. Public access via tunnel_network only.
- **Recommended normalization:** Audit all port mappings; add `127.0.0.1:` prefix where external access not required. Document exceptions in compose header comments.

---

### P2 — Resource Limits Sparse Application

- **Surface:** compose/resources
- **Problem:** Template defines `deploy: resources:` limits for all services, but only n8n/ollama has any limits (memory: 12G).
- **Impact:** Runaway containers can starve host; no memory/CPU guardrails.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:50-57,77-81,115-122` — defines limits
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:102-105` — only Ollama has limits
  - All other compose files — no resource limits
- **Canonical rule (expected):** All services should have memory limits; CPU limits optional but recommended for resource-intensive services.
- **Recommended normalization:** Add baseline memory limits to all services. Start conservative (512M-1G for typical services, more for databases/LLMs).

---

### P2 — Healthcheck Pattern Variations

- **Surface:** compose/lifecycle
- **Problem:** Template standardizes `interval: 30s, timeout: 10s, retries: 3, start_period: 60s` for apps, but actual compose files vary.
- **Impact:** Containers marked unhealthy prematurely or fail to detect actual failures.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:108-113` — canonical pattern
  - `/Users/ronnyworks/code/workbench/infra/compose/dashy/docker-compose.yml:19-24` — `start_period: 40s`
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:50-54` — no `start_period`
  - `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml:32-37` — `start_period: 10s`
- **Canonical rule (expected):** Consistent healthcheck intervals with reasonable `start_period` per service type (databases: 30s, apps: 60s, lightweight: 10s).
- **Recommended normalization:** Standardize healthcheck patterns:
  - Databases: `interval: 10s, timeout: 5s, retries: 5, start_period: 30s`
  - Apps: `interval: 30s, timeout: 10s, retries: 3, start_period: 60s`
  - Lightweight (redis, etc.): `interval: 10s, timeout: 5s, retries: 5`

---

### P2 — tunnel_network Source Undefined

- **Surface:** compose/networking
- **Problem:** Template and mint-os reference `tunnel_network: external: true`, but no documentation identifies where this network is created.
- **Impact:** New deployments fail if network doesn't exist; onboarding confusion.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:128-129`
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:254-255`
- **Canonical rule (expected):** External networks must be documented with creation command and owning stack.
- **Recommended normalization:** Add to template README and a network SSOT document:
  ```bash
  # Create tunnel_network (one-time)
  docker network create tunnel_network
  ```
  Document which host owns the canonical tunnel_network creation.

---

### P2 — Environment Variable Expansion Pattern Inconsistency

- **Surface:** compose/configuration
- **Problem:** Mix of expansion patterns:
  - Template: `${VAR:-default}` and `${VAR:?error message}`
  - n8n: `${VAR}` (no default, no error)
  - mint-os: Mix of both
  - mcpjungle: `${VAR:-default}` only
- **Impact:** Silent failures or confusing errors when .env is incomplete.
- **Evidence:**
  - `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:34-36` — canonical pattern
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:28` — no error message
- **Canonical rule (expected):** Required vars use `${VAR:?error}`, optional use `${VAR:-default}`.
- **Recommended normalization:** Audit all compose files; ensure required secrets fail fast with clear error messages.

---

## Coverage Checklist

| Item | Status | Notes |
|------|--------|-------|
| Compose pattern consistency | AUDITED | 8 compose files, multiple drift patterns found |
| Container lifecycle and health pattern consistency | AUDITED | Healthcheck variations, missing start_period |
| Deployment runbook parity across domains | NOT IN SCOPE | Runbooks in docs/, not compose files |
| Cloudflare/external routing deployment standardization | AUDITED | extra_hosts drift risk, tunnel_network ownership unclear |

---

## Compose File Inventory (Audited)

| File | Host | Version Field | Logging | Resource Limits | Networks |
|------|------|---------------|---------|-----------------|----------|
| `infra/templates/docker-compose.template.yml` | template | NO | YES (anchor) | YES | YES (canonical) |
| `infra/cloudflare/tunnel/docker-compose.yml` | infra-core | NO | NO | NO | host mode |
| `infra/compose/dashy/docker-compose.yml` | docker-host | NO | NO | NO | basic |
| `infra/compose/storage/docker-compose.yml` | docker-host | YES (3.8) | NO | NO | external |
| `infra/compose/mcpjungle/docker-compose.yml` | automation-stack | NO | NO | NO | basic (top) |
| `infra/compose/n8n/docker-compose.yml` | automation-stack | NO | NO | YES (ollama) | basic |
| `infra/compose/mint-os/docker-compose.yml` | docker-host | YES (3.8) | NO | NO | canonical |
| `infra/compose/mint-os/docker-compose.frontends.yml` | docker-host | NO | NO | NO | external |

---

## Recommended Canonical Compose Contract

Based on template and best practices:

```yaml
# =============================================================================
# Service: {STACK_NAME} ({DESCRIPTION})
# Host: {HOST} ({TAILSCALE_IP})
# Deploy: docker compose up -d
# Last Updated: {DATE}
# =============================================================================

x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

services:
  {service}:
    image: {image}:{tag}
    container_name: {stack}-{service}
    restart: unless-stopped
    environment:
      - REQUIRED_VAR=${REQUIRED_VAR:?REQUIRED_VAR required}
      - OPTIONAL_VAR=${OPTIONAL_VAR:-default}
    ports:
      - "127.0.0.1:{host_port}:{container_port}"
    networks:
      - {stack}-internal
      - tunnel_network
    healthcheck:
      test: ["CMD", "healthcheck-command"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    logging: *default-logging
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 256M

networks:
  {stack}-internal:
    name: {stack}-network
    driver: bridge
  tunnel_network:
    external: true
```

---

**LANE B COMPLETE.**
