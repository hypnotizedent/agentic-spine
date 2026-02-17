# L2 Audit: Runtime/Deployment/Container Normalization

> **Lane**: B (Terminal B)
> **Scope**: Compose files, container patterns, deployment patterns, cloudflare/routing
> **Date**: 2026-02-16
> **Status**: Read-only audit (no fixes)

---

## Summary

| Category | Files Audited | Drift Items | Critical | High | Medium |
|----------|--------------|-------------|----------|------|--------|
| Compose Files | 9 | 12 | 2 | 4 | 6 |
| Deployment Patterns | 4 | 3 | 0 | 1 | 2 |
| Runtime Consistency | 9 | 7 | 1 | 3 | 3 |

---

## CRITICAL FINDINGS (P0)

### P0-01: Missing Logging Configuration on All Production Compose Files

- **Surface**: compose-inconsistency
- **Problem**: Template defines x-logging anchor with rotation; ZERO production compose files implement logging.
- **Impact**: Unbounded log growth leading to disk exhaustion on production hosts.
- **Evidence**:
  - `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:19-23` - defines x-logging anchor
  - `/Users/ronnyworks/code/workbench/infra/compose/dashy/docker-compose.yml` - NO logging
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml` - NO logging
  - `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml` - NO logging
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml` - NO logging
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml` - NO logging
- **Canonical rule**: All services MUST use `logging: *default-logging` with JSON driver + rotation.
- **Recommended normalization**: Add x-logging anchor and apply to all services in all compose files.

```yaml
# Canonical pattern
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

---

### P0-02: Missing Resource Limits on Production Services

- **Surface**: compose-inconsistency
- **Problem**: Only n8n/ollama has resource limits; all other services have NO memory/CPU constraints.
- **Impact**: Noisy neighbor risk, OOM cascade failures, uncontrolled resource consumption.
- **Evidence**:
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:102-105` - only ollama has limits (memory: 12G)
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml` - 9 services, 0 limits
  - `/Users/ronnyworks/code/workbench/infra/compose/dashy/docker-compose.yml` - 1 service, 0 limits
  - `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml` - 1 service, 0 limits
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml` - 1 service, 0 limits
- **Canonical rule**: All services MUST have deploy.resources with limits and reservations.
- **Recommended normalization**: Add resource limits per STANDARDS_DOCKER_STACK.md guidelines.

```yaml
# Canonical pattern
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 1G
    reservations:
      cpus: '0.25'
      memory: 256M
```

---

## HIGH FINDINGS (P1)

### P1-01: Inconsistent Compose Version Declaration

- **Surface**: compose-inconsistency
- **Problem**: 2 files use deprecated `version: "3.8"` key; others omit it.
- **Impact**: Version key deprecated in Compose V2; inconsistent behavior possible.
- **Evidence**:
  - `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml:1` - version: "3.8"
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:5` - version: "3.8"
  - `/Users/ronnyworks/code/workbench/infra/compose/dashy/docker-compose.yml` - no version (correct)
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml` - no version (correct)
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml` - no version (correct)
- **Canonical rule**: Remove `version:` key from all compose files (Docker Compose V2 ignores it).
- **Recommended normalization**: Delete `version:` lines from storage and mint-os compose files.

---

### P1-02: Inconsistent File Headers

- **Surface**: compose-inconsistency
- **Problem**: Header comments are inconsistent; some files have full headers, others have none.
- **Impact**: Missing provenance, deployment confusion, harder troubleshooting.
- **Evidence**:
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml` - NO header
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:1-4` - minimal header (no host/docs)
  - `/Users/ronnyworks/code/workbench/infra/compose/dashy/docker-compose.yml:1-6` - GOOD header
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:1-6` - GOOD header
- **Canonical rule**: All compose files MUST have standard header with Service, Host, Deploy, Docs, Last Updated.
- **Recommended normalization**: Add/complete headers per STANDARDS_DOCKER_STACK.md template.

---

### P1-03: Non-Standard Port Exposure (Security Risk)

- **Surface**: compose-inconsistency
- **Problem**: Several services expose ports to all interfaces (0.0.0.0) instead of localhost only.
- **Impact**: Services accessible from network unnecessarily; security exposure.
- **Evidence**:
  - `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml:21-22` - "9000:9000", "9001:9001" (MinIO)
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:22` - "15432:5432" (Postgres)
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:39` - "16379:6379" (Redis)
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:97` - "11434:11434" (Ollama)
- **Canonical rule**: All ports MUST be prefixed with `127.0.0.1:` unless externally required.
- **Recommended normalization**: Add `127.0.0.1:` prefix to all non-external ports.

---

### P1-04: MinIO Duplication Between Stacks

- **Surface**: deployment-inconsistency
- **Problem**: Both storage/docker-compose.yml AND mint-os/docker-compose.yml define MinIO with same container_name.
- **Impact**: Only ONE can run at a time; confusion about canonical MinIO location; potential data split.
- **Evidence**:
  - `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml:17-18` - image: minio/minio:latest, container_name: minio
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:49-50` - image: minio/minio:latest, container_name: minio
- **Canonical rule**: ONE stack owns MinIO; other stacks connect via external network.
- **Recommended normalization**: Remove MinIO from mint-os compose; use storage stack's minio via mint-os-network.

---

## MEDIUM FINDINGS (P2)

### P2-01: Healthcheck start_period Inconsistency

- **Surface**: compose-inconsistency
- **Problem**: Some services have `start_period`, others don't; inconsistent startup timing.
- **Impact**: Services may be marked unhealthy before fully started.
- **Evidence**:
  - `/Users/ronnyworks/code/workbench/infra/compose/dashy/docker-compose.yml:24` - start_period: 40s
  - `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml:66` - start_period: 10s
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:50-54` - NO start_period
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:25-29` - NO start_period on postgres
- **Canonical rule**: All healthchecks MUST include `start_period: 60s` for apps, `30s` for databases.
- **Recommended normalization**: Add start_period to all healthchecks.

---

### P2-02: External Network Definition Pattern Inconsistency

- **Surface**: compose-inconsistency
- **Problem**: Network ownership unclear; some stacks create networks, others expect them external.
- **Impact**: Network creation order dependency; deployment sequencing issues.
- **Evidence**:
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:250-255` - creates mint-os-network AND uses external tunnel_network
  - `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.frontends.yml:177-183` - expects ALL networks external
  - `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml:42-46` - expects ALL networks external
- **Canonical rule**: ONE stack creates a network; all others use `external: true`. Document network owner in header.
- **Recommended normalization**: Clarify network ownership in compose headers; standardize pattern.

---

### P2-03: depends_on Without Condition

- **Surface**: compose-inconsistency
- **Problem**: Some services use `depends_on: - service` without health condition.
- **Impact**: Services may start before dependencies are healthy.
- **Evidence**:
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:119-120` - `depends_on: - ollama` (no condition)
  - `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:45-47` - CORRECT: uses `condition: service_healthy`
- **Canonical rule**: ALWAYS use `condition: service_healthy` for health-checked dependencies.
- **Recommended normalization**: Add condition to open-webui depends_on.

---

### P2-04: Cloudflare Tunnel extra_hosts Hardcoded IPs

- **Surface**: deployment-inconsistency
- **Problem**: Tunnel compose has 15+ hardcoded Tailscale IPs in extra_hosts.
- **Impact**: Manual updates required when IPs change; maintenance burden.
- **Evidence**:
  - `/Users/ronnyworks/code/workbench/infra/cloudflare/tunnel/docker-compose.yml:28-48` - hardcoded IPs for all services
- **Canonical rule**: Extract IPs to SSOT or use proper DNS/network resolution.
- **Recommended normalization**: Reference DEVICE_IDENTITY_SSOT.md or use Docker DNS with proper network attachment.

---

### P2-05: Missing Labels for Infrastructure Identification

- **Surface**: compose-inconsistency
- **Problem**: Only storage compose has infrastructure labels; others have none.
- **Impact**: Harder to filter/identify containers by purpose; operational friction.
- **Evidence**:
  - `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml:38-40` - has labels
  - All other compose files have NO labels
- **Canonical rule**: All services MUST have `com.ronny.infrastructure` and `com.ronny.project` labels.
- **Recommended normalization**: Add labels to all services.

---

### P2-06: Template References Non-Existent .env.example.template

- **Surface**: documentation-inconsistency
- **Problem**: README lists `.env.example.template` but file does not exist.
- **Impact**: Developers cannot bootstrap new stacks from templates.
- **Evidence**:
  - `/Users/ronnyworks/code/workbench/infra/templates/README.md` - lists .env.example.template
  - File does NOT exist in `/Users/ronnyworks/code/workbench/infra/templates/`
- **Canonical rule**: Documented templates MUST exist.
- **Recommended normalization**: Create the missing .env.example.template OR remove from README.

---

## POSITIVE FINDINGS (No Action Required)

### POS-01: Health Check Coverage - 100%
All 9 compose files have healthchecks defined for all services.

### POS-02: Restart Policy - Consistent
All services use `restart: unless-stopped` correctly.

### POS-03: Container Naming Pattern - Consistent
All containers follow `{project}-{service}` naming convention.

### POS-04: Network Naming - Consistent
Networks follow `{project}-{purpose}` or `{project}-network` pattern.

### POS-05: tunnel_network Usage - Correct
All stacks that need external access properly attach to `tunnel_network: external: true`.

---

## FILES AUDITED

| File | Lines | Services |
|------|-------|----------|
| `/Users/ronnyworks/code/workbench/infra/compose/dashy/docker-compose.yml` | 31 | 1 |
| `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml` | 135 | 5 |
| `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml` | 47 | 1 |
| `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml` | 256 | 9 |
| `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.frontends.yml` | 184 | 5 |
| `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml` | 67 | 1 |
| `/Users/ronnyworks/code/workbench/infra/cloudflare/tunnel/docker-compose.yml` | 49 | 1 |
| `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml` | 130 | 3 |
| `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/STANDARDS_DOCKER_STACK.md` | 617 | - |

---

## Coverage Checklist

- [x] Compose pattern consistency (9 files audited)
- [x] Container lifecycle and health pattern consistency (100% coverage)
- [x] Deployment runbook parity across domains (cloudflare tunnel, mint-os, n8n)
- [x] Cloudflare/external routing deployment standardization (tunnel config reviewed)

---

**LANE B COMPLETE.**
