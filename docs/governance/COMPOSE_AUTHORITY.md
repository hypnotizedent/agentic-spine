---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-05
scope: compose-locations
---

# Compose Authority Map

**Date:** 2026-01-24
**Scope:** Documentation only (no runtime changes)
**Policy:** Archived compose files under `.archive/` are **non-authoritative** per `docs/governance/ARCHIVE_POLICY.md`.

This map exists to prevent "compose guessing." If you need to run or modify a stack, start here and follow the authoritative compose location.

## Mint OS (production stack)

**Authoritative compose location (split by intent):**
- `infrastructure/docker-host/mint-os/docker-compose.yml`
  Owns: core deps + primary Mint OS apps/services (postgres, redis, minio, and app services)
- `infrastructure/docker-host/mint-os/docker-compose.frontends.yml`
  Owns: UI/frontends + related app web surfaces
- `infrastructure/docker-host/mint-os/docker-compose.monitoring.yml`
  Owns: monitoring stack (prometheus, grafana, exporters, alerting)
- `infrastructure/docker-host/mint-os/docker-compose.minio.yml`
  Owns: Mint OS MinIO (when split/isolated)

**Non-authoritative legacy duplicates (archived):**
- `mint-os/docs/.archive/legacy-2025/mint-os-app-stack-v2/*`

## Media Stack

**Authoritative:**
- `media-stack/docker-compose.yml`
  Owns: Jellyfin + ARR stack and related media tooling

**Archived legacy:**
- `mint-os/docs/.archive/legacy-2025/Historical_Docs/Reference_Plans/old_media_stack_compose.yml`

## Finance

**Authoritative:**
- `finance/docker-compose.yml`
  Owns: finance stack (Firefly III + dependencies + related apps)
- `finance/mail-archiver/docker-compose.yml`
  Owns: mail archiver sub-stack

## Pi-hole

**Authoritative:**
- `infrastructure/pihole/docker-compose.yml`

**Archived planned reference (non-authoritative):**
- `mint-os/docs/.archive/legacy-2025/Planned_Service_Configs/pihole-docker-compose.yml`

## Infisical (secrets)

**Authoritative:**
- `infrastructure/secrets/docker-compose.yml`
  Owns: Infisical + dependencies

## n8n

**Authoritative:**
- `infrastructure/n8n/docker-compose.yml`
  Owns: n8n stack (and any co-located deps explicitly defined there)

## Cloudflare Tunnel

**Authoritative:**
- `infrastructure/cloudflare/tunnel/docker-compose.yml`

## Dashy

**Authoritative:**
- `infrastructure/dashy/docker-compose.yml`

## MCP Jungle

**Authoritative:**
- `infrastructure/mcpjungle/docker-compose.yml`

## Files API (module extraction)

**Authoritative:**
- `modules/files-api/docker-compose.yml`

## Storage (standalone)

**Authoritative:**
- `infrastructure/storage/docker-compose.yml`
  Owns: storage-oriented stack components defined there (may include a standalone MinIO)

### Known overlap: MinIO (Mint OS vs Storage)
MinIO appears in:
- Mint OS context: `infrastructure/docker-host/mint-os/docker-compose.minio.yml`
- Storage context: `infrastructure/storage/docker-compose.yml`

**Guardrail:** Treat these as **different stacks** unless explicitly documented otherwise in an SSOT/registry.
If an operator needs "MinIO," first confirm which stack they are operating on (Mint OS vs Storage) and follow the authority chain in `docs/DOC_MAP.md`.

## Templates

**Not a running stack:**
- `infrastructure/templates/docker-compose.template.yml`
