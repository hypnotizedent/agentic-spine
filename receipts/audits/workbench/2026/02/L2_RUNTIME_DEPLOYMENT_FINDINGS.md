# L2 Audit: Runtime/Deployment Normalization

**Audit Date:** 2026-02-16
**Scope:** `/Users/ronnyworks/code/workbench`
**Focus:** Compose files, container patterns, deployment/routing standardization
**Status:** READ-ONLY (no fixes applied)

---

## Summary

| Metric | Count |
|--------|-------|
| Compose files analyzed | 8 |
| Deployment scripts found | 20+ |
| Standards documents | 1 (`STANDARDS_DOCKER_STACK.md`) |
| **CRITICAL findings** | 2 |
| **HIGH findings** | 4 |
| **MEDIUM findings** | 3 |

**Overall Assessment:** Strong canonical standard exists (`STANDARDS_DOCKER_STACK.md`) but **actual compose files deviate significantly** from the documented patterns. Gap between documented standards and runtime reality.

---

## Findings (Severity-Ordered)

### P0: Logging Configuration Not Applied

**Drift Type:** Runtime inconsistency

**Problem:** The canonical template defines `x-logging` anchor with JSON file driver and rotation, but **zero compose files apply this pattern**.

**Impact:** Unbounded log growth on hosts, disk exhaustion risk on long-running services, no log rotation enforced.

**Evidence:**
- `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:19-23`: Defines `x-logging`
- `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml`: Missing `logging:` blocks
- `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml`: Missing `logging:` blocks
- `/Users/ronnyworks/code/workbench/infra/compose/dashy/docker-compose.yml`: Missing `logging:` blocks
- `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml`: Missing `logging:` blocks

**Canonical rule (expected):**
```yaml
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

services:
  app:
    logging: *default-logging
```

**Recommended normalization:** Add `logging: *default-logging` to every service in every compose file.

---

### P0: Resource Limits Not Enforced

**Drift Type:** Runtime inconsistency

**Problem:** The canonical template defines `deploy.resources` limits, but **only 1 service** (ollama) has resource limits applied.

**Impact:** Runaway containers can exhaust host memory, no CPU throttling for noisy neighbors, unpredictable performance degradation.

**Evidence:**
- `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:50-57,77-81,115-122`: Defines limits
- `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:102-106`: Only ollama has limits
- All other compose files: Missing `deploy:` blocks entirely

**Canonical rule (expected):**
```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 1G
    reservations:
      cpus: '0.25'
      memory: 256M
```

**Recommended normalization:** Apply resource limits per service type using guidelines from `STANDARDS_DOCKER_STACK.md` lines 257-264.

---

### P1: Healthcheck Patterns Inconsistent

**Drift Type:** Compose inconsistency

**Problem:** Three different healthcheck invocation patterns used across compose files.

**Impact:** Difficult to debug failed healthchecks, some patterns may not set proper exit codes, wget availability varies by base image.

**Evidence:**
- `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:125`: `wget -q -O /dev/null`
- `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:51`: `wget -qO-`
- `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml:33`: `curl -f`
- `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:178`: `node -e` inline

**Canonical rule (expected):**
```yaml
# HTTP services (preferred)
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:PORT/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s

# PostgreSQL (canonical)
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
  interval: 10s
  timeout: 5s
  retries: 5

# Redis (canonical)
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 10s
  timeout: 5s
  retries: 5
```

**Recommended normalization:** Standardize on wget-based healthcheck for HTTP, pg_isready for postgres, redis-cli for redis.

---

### P1: Network Naming Inconsistency

**Drift Type:** Compose inconsistency

**Problem:** Mix of naming conventions for networks.

**Impact:** Cross-stack communication requires explicit external network setup, inconsistent naming makes service discovery harder, tunnel network usage varies.

**Evidence:**
- `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:250-255`: `mint-os-network`, `tunnel_network`
- `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:132-134`: `automation-network`
- `/Users/ronnyworks/code/workbench/infra/compose/dashy/docker-compose.yml:28-30`: `dashy-network`
- `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml:1-3`: `mcpjungle_network`

**Canonical rule (expected):**
```yaml
networks:
  # Internal (created by this compose)
  {project}-internal:
    name: {project}-network
    driver: bridge
  
  # External tunnel (shared)
  tunnel_network:
    external: true
```

**Recommended normalization:** Adopt `{project}-network` pattern for internal, `tunnel_network` external for all public-facing services.

---

### P1: No CI/CD Deployment Automation

**Drift Type:** Deployment inconsistency

**Problem:** Deployment relies entirely on manual script execution. No `.github/workflows/` directory exists in workbench.

**Impact:** Deployments require manual SSH + script execution, no automated rollback capability, no deployment audit trail, human error risk.

**Evidence:**
- `/Users/ronnyworks/code/workbench/scripts/root/deploy-api.sh`: Manual deployment script
- `/Users/ronnyworks/code/workbench/scripts/root/deploy-admin.sh`: Manual deployment script
- `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:4`: Documents manual `docker compose up -d`
- `/Users/ronnyworks/code/workbench/.github/workflows/`: Directory does not exist

**Canonical rule (expected):**
1. Create `.github/workflows/deploy-{stack}.yml` for each stack
2. Trigger on push to main branch
3. Validate secrets from Infisical before deploy
4. Run healthchecks after deploy
5. Rollback on failure

**Recommended normalization:** Implement GitHub Actions workflows following pattern in `deploy-api.sh` (which already has proper Infisical integration at lines 27-70).

---

### P1: Port Exposure Inconsistency

**Drift Type:** Compose inconsistency

**Problem:** Mix of localhost-only binding and all-interfaces binding.

**Impact:** Exposed database ports accessible from any network, security risk on multi-homed hosts, inconsistent with documented standard.

**Evidence:**
- `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:22`: `"15432:5432"` (all interfaces)
- `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:40`: `"127.0.0.1:{DB_PORT}:5432"` (localhost only)
- `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:97`: `"11434:11434"` (all interfaces - ollama)

**Canonical rule (expected):**
```yaml
# Internal only (preferred)
ports:
  - "127.0.0.1:8080:8080"

# External access (only when required)
ports:
  - "0.0.0.0:8080:8080"
```

**Recommended normalization:** Bind all internal services to `127.0.0.1`. Only expose externally when tunneled access is insufficient.

---

### P2: Compose Version Declaration Mixed

**Drift Type:** Compose inconsistency

**Problem:** Some files declare `version: "3.8"`, others omit it entirely (Compose v2 style).

**Impact:** Minor inconsistency, version field deprecated in Compose v2, may cause confusion about which syntax is expected.

**Evidence:**
- `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:5`: `version: "3.8"`
- `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml:1`: `version: "3.8"`
- `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml`: No version (modern)
- `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml`: No version (modern)

**Canonical rule (expected):** Omit `version:` entirely (Compose v2+ style). The field is obsolete.

**Recommended normalization:** Remove `version:` from all compose files.

---

### P2: Header Comment Inconsistency

**Drift Type:** Compose inconsistency

**Problem:** Header comments vary in completeness. Some have full metadata, some minimal, some none.

**Impact:** Harder to identify stack purpose at a glance, missing host/deploy information requires context lookup.

**Evidence:**
- `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml:1-18`: Full template with placeholders
- `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:1-6`: Good header
- `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml`: No header at all
- `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml:1-13`: Good header with note

**Canonical rule (expected):**
```yaml
# =============================================================================
# Service: {stack-name} ({brief description})
# Host: {hostname} ({tailscale-ip})
# Deploy: docker compose up -d
# Last Updated: YYYY-MM-DD
# =============================================================================
```

**Recommended normalization:** Add/standardize headers on all compose files.

---

### P2: Volume Pattern Inconsistency

**Drift Type:** Compose inconsistency

**Problem:** Mix of bind mounts and named volumes without clear rationale.

**Impact:** Backup strategies differ by stack, Docker volume management complexity, path assumptions may not hold across hosts.

**Evidence:**
- `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml:19-20,36-37`: Bind mounts to `/mnt/data/`
- `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml:66-67,82`: Named volumes
- `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml:53-56`: Bind mounts for data, db

**Canonical rule (expected):** From `STANDARDS_DOCKER_STACK.md` lines 121-158:
- Database data: Bind mount to `/mnt/docker/{project}/{service}`
- Named volumes: For cache/temporary data
- Config: Bind mount read-only

**Recommended normalization:** Standardize on bind mounts for persistent data with `/mnt/docker/` prefix.

---

## Positive Findings

| Pattern | Status | Evidence |
|---------|--------|----------|
| `restart: unless-stopped` | **Consistent** | All compose files use this |
| `container_name:` explicit | **Consistent** | All services have explicit names |
| `healthcheck:` present | **Consistent** | All services have healthchecks (pattern varies) |
| Infisical for secrets | **Implemented** | `deploy-api.sh` pulls from Infisical (lines 27-70) |
| Standards document exists | **Good** | `STANDARDS_DOCKER_STACK.md` is comprehensive (617 lines) |
| Cloudflare tunnel pattern | **Documented** | `tunnel_network: external: true` pattern established |

---

## Gap Summary

| Gap ID | Description | Severity | Effort |
|--------|-------------|----------|--------|
| G-L2-001 | Logging not applied to any compose file | CRITICAL | Low (add 1 line per service) |
| G-L2-002 | Resource limits not enforced | CRITICAL | Medium (measure, then apply) |
| G-L2-003 | Healthcheck patterns inconsistent | HIGH | Low (sed replacement) |
| G-L2-004 | Network naming varies | HIGH | Medium (requires coordination) |
| G-L2-005 | No CI/CD automation | HIGH | High (new infrastructure) |
| G-L2-006 | Port exposure varies | HIGH | Low (change binding) |
| G-L2-007 | Compose version mixed | MEDIUM | Low (delete lines) |
| G-L2-008 | Headers inconsistent | MEDIUM | Low (add comments) |
| G-L2-009 | Volume pattern varies | MEDIUM | High (migration required) |

---

## Recommended Normalization Order

1. **Quick wins (1-2 hours):**
   - G-L2-007: Remove `version:` fields
   - G-L2-008: Standardize headers
   - G-L2-003: Unify healthcheck syntax

2. **Safety improvements (2-4 hours):**
   - G-L2-001: Add logging to all services
   - G-L2-006: Bind internal ports to localhost

3. **Resource governance (4-8 hours):**
   - G-L2-002: Measure actual usage, apply limits

4. **Architecture alignment (8+ hours):**
   - G-L2-004: Unify network naming
   - G-L2-009: Standardize volume patterns
   - G-L2-005: Implement CI/CD workflows

---

## Files Audited

| File | Lines | Status |
|------|-------|--------|
| `/Users/ronnyworks/code/workbench/infra/templates/docker-compose.template.yml` | 130 | Reference standard |
| `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.yml` | 256 | Multiple deviations |
| `/Users/ronnyworks/code/workbench/infra/compose/mint-os/docker-compose.frontends.yml` | 184 | Multiple deviations |
| `/Users/ronnyworks/code/workbench/infra/compose/n8n/docker-compose.yml` | 135 | Some deviations |
| `/Users/ronnyworks/code/workbench/infra/compose/dashy/docker-compose.yml` | 31 | Minor deviations |
| `/Users/ronnyworks/code/workbench/infra/compose/storage/docker-compose.yml` | 47 | Minor deviations |
| `/Users/ronnyworks/code/workbench/infra/compose/mcpjungle/docker-compose.yml` | 67 | Multiple deviations |
| `/Users/ronnyworks/code/workbench/infra/cloudflare/tunnel/docker-compose.yml` | 49 | Reference copy |
| `/Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/STANDARDS_DOCKER_STACK.md` | 617 | Canonical standard |

---

## Coverage Checklist

- [x] Compose pattern consistency
- [x] Container lifecycle and health pattern consistency
- [x] Deployment runbook parity across domains
- [x] Cloudflare/external routing deployment standardization

---

*Audit completed: 2026-02-16*
*Lane: B (Runtime/Deployment/Container Normalization)*
*Agent: OpenCode Terminal B*
