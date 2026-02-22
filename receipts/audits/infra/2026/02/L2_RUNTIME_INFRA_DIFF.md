# L2 Runtime/Infra/Compose Diff Report

> Agent: L2opencodeRUNTIME
> Loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
> Generated: 2026-02-17

## Scope

Compare legacy runtime/deploy/compose surfaces in:
- **Source**: `/Users/ronnyworks/ronny-ops`
- **Destination**: `/Users/ronnyworks/code/workbench/infra/**`

Report only material drift with destination repo/path targets.

---

## Summary

| Category | Missing in Workbench | Extraction Priority |
|----------|---------------------|---------------------|
| Docker Compose Stacks | 6 compose files | HIGH |
| Scripts (operational) | 50+ scripts | MEDIUM-HIGH |
| Configs (service) | 15+ config files | MEDIUM |
| Documentation (runbooks/contracts) | 8 documents | MEDIUM |
| Infrastructure Components | 5 services | LOW |

---

## 1. Docker Compose Stacks - MISSING

### 1.1 Media Stack (HIGH PRIORITY)

**Source**: `ronny-ops/media-stack/docker-compose.yml` (24,729 bytes)
**Destination**: NOT PRESENT in `workbench/infra/compose/`

Workbench has `compose/arr/` but contains only:
- `.env.example` (161 bytes)
- `DEFERRED.md` (221 bytes)

**Extraction Target**: `workbench/infra/compose/media-stack/docker-compose.yml`

### 1.2 Finance Stack (HIGH PRIORITY)

**Source**: `ronny-ops/finance/docker-compose.yml` (8,388 bytes)
**Source**: `ronny-ops/finance/mail-archiver/docker-compose.yml` (1,334 bytes)
**Destination**: NOT PRESENT in `workbench/infra/compose/`

**Extraction Target**: `workbench/infra/compose/finance/docker-compose.yml`

### 1.3 Mint-OS Monitoring Stack (MEDIUM PRIORITY)

**Source**: `ronny-ops/infrastructure/docker-host/mint-os/docker-compose.monitoring.yml` (4,094 bytes)
**Destination**: NOT PRESENT in `workbench/infra/compose/mint-os/`

Workbench mint-os has:
- `docker-compose.yml` (8,701 bytes) ✓
- `docker-compose.frontends.yml` (6,810 bytes) ✓

**Extraction Target**: `workbench/infra/compose/mint-os/docker-compose.monitoring.yml`

### 1.4 Pi-hole Stack (MEDIUM PRIORITY)

**Source**: `ronny-ops/infrastructure/pihole/docker-compose.yml` (1,180 bytes)
**Source**: `ronny-ops/infrastructure/pihole/.env.example` (198 bytes)
**Destination**: NOT PRESENT in `workbench/infra/compose/pihole/`

**Extraction Target**: `workbench/infra/compose/pihole/docker-compose.yml`

### 1.5 Files-API Module (LOW PRIORITY - Standalone Service)

**Source**: `ronny-ops/modules/files-api/docker-compose.yml` (2,104 bytes)
**Source**: `ronny-ops/modules/files-api/Dockerfile` (977 bytes)
**Destination**: NOT PRESENT

Full service with src/, migrations/, etc. Evaluate if actively used.

**Extraction Target**: `workbench/infra/compose/files-api/docker-compose.yml`

---

## 2. Scripts - MISSING

### 2.1 Media-Stack Scripts (28 scripts)

**Source**: `ronny-ops/media-stack/scripts/`
**Destination**: NOT PRESENT

| Script | Purpose |
|--------|---------|
| `backup-configs.sh` | Backup media service configs |
| `backup-huntarr.sh` | Huntarr backup |
| `backup-media-databases.sh` | Database backups |
| `check-sabnzbd.sh` | Sabnzbd health |
| `cleanup-common.sh` | Common cleanup utilities |
| `cleanup-royksopp.sh` | Music cleanup |
| `cleanup-stale-queue.sh` | Queue maintenance |
| `dedupe-music.sh` | Music deduplication |
| `fix-lidarr-profiles.sh` | Lidarr profile fixes |
| `fix-lidarr-queue.sh` | Lidarr queue fixes |
| `health-check-media-pipeline.sh` | Pipeline health |
| `media-deep-check.sh` | Deep media validation |
| `media-env.sh` | Environment setup |
| `media-health.sh` | Health check wrapper |
| `monitor-artwork-sync.sh` | Artwork sync monitoring |
| `organize-royksopp.sh` | Music organization |
| `sync-catalog.sh` | Catalog sync |
| `sync-jellyfin-collections.sh` | Jellyfin collections |
| `sync_from_home.sh` | Home sync |
| `sync_from_home_throttled.sh` | Throttled sync |
| `trickplay-guard.sh` | Trickplay protection |
| `trigger_manual_import.sh` | Manual import trigger |
| `verify-intro-skipper.sh` | Intro skipper verification |
| `watch-rsync.sh` | Rsync watcher |
| `janitor.py` | Python janitor |
| `mass-unmonitor.py` | Bulk unmonitor |
| `curation/generate_arabic_playlist.sh` | Playlist generation |
| `maintenance/*` | Lidarr rename scripts |

**Extraction Target**: `workbench/infra/compose/media-stack/scripts/`

### 2.2 N8N Credentials Script

**Source**: `ronny-ops/infrastructure/n8n/n8n-credentials.sh` (9,417 bytes)
**Destination**: NOT PRESENT in `workbench/infra/compose/n8n/`

Workbench n8n has `n8n-workflows.sh` but missing credentials CLI.

**Extraction Target**: `workbench/infra/compose/n8n/scripts/n8n-credentials.sh`

### 2.3 Infrastructure Utility Scripts

**Source**: `ronny-ops/infrastructure/scripts/`
**Destination**: NOT PRESENT

| Script | Purpose |
|--------|---------|
| `apply-missing-labels.sh` | Docker label management |
| `cleanup-repositories.sh` | Repo cleanup |

**Extraction Target**: `workbench/infra/scripts/`

### 2.4 Mint-OS Scripts (20+ scripts)

**Source**: `ronny-ops/mint-os/scripts/`
**Destination**: NOT PRESENT in workbench

| Script | Purpose |
|--------|---------|
| `create-quote.sh` | Quote creation |
| `deploy-mcp-mint-os.sh` | MCP deployment |
| `download-missing-pdfs.sh` | PDF downloads |
| `execute-rename-csv.sh` | Batch renames |
| `find-missing-artwork.sh` | Artwork discovery |
| `minio-rename*.sh` | MinIO operations |
| `recover-missing-artwork.sh` | Artwork recovery |
| `sync-customer-folders.sh` | Customer sync |
| `upload-pdfs-to-minio.sh` | PDF uploads |
| `validate-artwork-integrity.sh` | Artwork validation |

**Note**: These are domain-specific. Evaluate if needed in workbench or should stay in mint-os app repo.

---

## 3. Service Configs - MISSING

### 3.1 Media-Stack Configs

**Source**: `ronny-ops/media-stack/config/`
**Destination**: NOT PRESENT

| Config | Service |
|--------|---------|
| `janitorr/application.yml` | Janitorr |
| `kometa/config.yml` | Kometa |
| `kometa/collections/trending.yml` | Kometa collections |
| `recyclarr/recyclarr.yml` | Recyclarr |

**Extraction Target**: `workbench/infra/compose/media-stack/config/`

### 3.2 Home Assistant Configs

**Source**: `ronny-ops/home-assistant/configs/`
**Destination**: `workbench/infra/homeassistant/config/` (partial)

Workbench has:
- `automations.yaml` ✓
- `configuration.yaml` ✓
- `scripts.yaml` ✓
- `groups.yaml` ✓
- `scenes.yaml` ✓
- `customize_hidden_entities.yaml` ✓

**MISSING in Workbench**:

| Config | Status |
|--------|--------|
| `dashboards/` | Missing |
| `helpers/` | Missing |
| `packages/` | Missing |
| `themes/` | Missing |
| `www/` | Missing |
| `zigbee2mqtt/` | Missing |
| `zigbee2mqtt_fixed.yaml` | Missing |
| `zigbee_current.yaml` | Missing |
| `streamdeck/` | Missing |

**Extraction Target**: `workbench/infra/homeassistant/config/` (merge)

---

## 4. Documentation - MISSING

### 4.1 Runbooks/Contracts

| Document | Source | Destination Status |
|----------|--------|-------------------|
| `n8n/CONTRACT.md` | `ronny-ops/infrastructure/n8n/` (13,181 bytes) | MISSING |
| `n8n/QUICKSTART.md` | `ronny-ops/infrastructure/n8n/` (1,721 bytes) | MISSING |
| `mcpjungle/RECOVERY_RUNBOOK.md` | `ronny-ops/infrastructure/mcpjungle/` (7,592 bytes) | MISSING |
| `storage/MINIO_STANDALONE_SSOT.md` | `ronny-ops/infrastructure/storage/` (723 bytes) | MISSING |
| `cloudflare/CLOUDFLARE_GOVERNANCE.md` | `ronny-ops/infrastructure/cloudflare/` (13,781 bytes) | MISSING |

### 4.2 Context Documents

| Document | Source | Status |
|----------|--------|--------|
| `media-stack/MEDIA_STACK_CONTEXT.md` | 6,457 bytes | MISSING |
| `media-stack/BACKUP.md` | 7,732 bytes | MISSING |
| `finance/FINANCE_CONTEXT.md` | 8,291 bytes | MISSING |
| `finance/BACKUP.md` | 4,738 bytes | MISSING |
| `home-assistant/HOME_ASSISTANT_CONTEXT.md` | 14,243 bytes | MISSING |
| `home-assistant/BACKUP.md` | 3,513 bytes | MISSING |
| `immich/IMMICH_CONTEXT.md` | 4,791 bytes | MISSING |
| `immich/BACKUP.md` | 5,881 bytes | MISSING |

---

## 5. Infrastructure Components - MISSING/INCOMPLETE

### 5.1 Vaultwarden (README only)

**Source**: `ronny-ops/infrastructure/vaultwarden/README.md`
**Destination**: NOT PRESENT

No compose file - planning document only.

### 5.2 Shopify-MCP

**Source**: `ronny-ops/infrastructure/shopify-mcp/`
**Destination**: NOT PRESENT

| File | Size |
|------|------|
| `CLAUDE.md` | 565 bytes |
| `SHOPIFY_SSOT.md` | 7,315 bytes |
| `migrations/` | dir |

### 5.3 Home-Services/NAS

**Source**: `ronny-ops/infrastructure/home-services/nas/`
**Destination**: NOT PRESENT

Contains:
- Dakota embroidery project docs
- Thumbnail research
- R730XD migration docs
- `dakota-thumbnails/` scripts
- `scripts/` directory

### 5.4 Mint-OS-Vault

**Source**: `ronny-ops/infrastructure/mint-os-vault/`
**Destination**: NOT PRESENT

| File | Purpose |
|------|---------|
| `DATA_ARCHITECTURE.md` | 11,252 bytes |
| `migrations/` | Migration scripts |

### 5.5 Domains Registry

**Source**: `ronny-ops/infrastructure/domains/`
**Destination**: NOT PRESENT

| File | Purpose |
|------|---------|
| `DOMAIN_REGISTRY.md` | 5,246 bytes |
| `DOMAIN_STRATEGY.md` | 3,803 bytes |

### 5.6 Dotfiles

**Source**: `ronny-ops/infrastructure/dotfiles/`
**Destination**: NOT PRESENT

| Dir/File | Content |
|----------|---------|
| `git/` | Git configs |
| `macbook/` | Mac configs |
| `shell/` | Shell configs |
| `ssh/` | SSH configs |
| `install.sh` | Install script |

---

## 6. Files-Module (Full Service)

**Source**: `ronny-ops/modules/files-api/`
**Destination**: NOT PRESENT

Complete Node.js service:
- `src/` - Source code
- `migrations/` - DB migrations
- `cli/` - CLI tools
- `docker-compose.yml` - Container definition
- `Dockerfile` - Build definition
- Documentation: API.md, SCHEMA.md, WORKFLOW.md, etc.

**Evaluation Required**: Determine if actively deployed or archival.

---

## 7. Already Extracted (Present in Workbench)

The following have been successfully extracted to workbench:

| Component | Status |
|-----------|--------|
| `mcpjungle/` | ✓ Present (setup.sh, docker-compose.yml, servers/) |
| `n8n/` | ✓ Present (compose, workflows, email-templates) |
| `mint-os/` | ✓ Present (main + frontends compose) |
| `storage/` | ✓ Present (docker-compose.yml) |
| `dashy/` | ✓ Present (compose + config.yml) |
| `cloudflare/tunnel/` | ✓ Present |
| `templates/` | ✓ Present (Dockerfiles, compose template) |
| `homeassistant/config/` | ✓ Partial (core configs) |
| `ha-dashboards/` | ✓ Present (11 dashboards) |
| `data/` | ✓ Present (inventories + MCP/SERVICE registries) |

---

## 8. Archive Files (Do Not Extract)

These are intentionally archived:

| Path | Status |
|------|--------|
| `ronny-ops/mint-os/docs/.archive/` | Legacy 2025 - skip |
| `ronny-ops/immich/.archive/` | Full reset archive - skip |
| `ronny-ops/media-stack/scripts/.deprecated/` | Deprecated - skip |
| `ronny-ops/.archive/` | Root archive - skip |

---

## Extraction Recommendations

### Priority 1 - Active Services (Extract Now)

1. **Media Stack** - `workbench/infra/compose/media-stack/`
   - docker-compose.yml
   - config/ directory
   - scripts/ directory (operational)

2. **Finance Stack** - `workbench/infra/compose/finance/`
   - docker-compose.yml
   - mail-archiver/docker-compose.yml

### Priority 2 - Documentation/Runbooks (Extract Soon)

1. **N8N Contract** - `workbench/infra/compose/n8n/CONTRACT.md`
2. **MCPJungle Recovery** - `workbench/infra/compose/mcpjungle/RECOVERY_RUNBOOK.md`
3. **Cloudflare Governance** - `workbench/infra/cloudflare/CLOUDFLARE_GOVERNANCE.md`
4. **N8N Credentials Script** - `workbench/infra/compose/n8n/scripts/`

### Priority 3 - Future Services (Evaluate)

1. **Pi-hole** - If needed for DNS
2. **Files-API Module** - If actively used
3. **Mint-OS Monitoring** - If monitoring needed

### Priority 4 - Documentation Archive (Optional)

1. Context docs (MEDIA_STACK_CONTEXT.md, etc.)
2. Domain strategy docs
3. Home-services NAS docs

---

## File Count Summary

| Category | Legacy Count | Extracted | Remaining |
|----------|--------------|-----------|-----------|
| docker-compose.yml | 20 | 8 | 12 |
| Shell scripts | 60+ | 5 | 55+ |
| Python scripts | 5+ | 0 | 5+ |
| Config files (yaml) | 30+ | 8 | 22+ |
| Dockerfiles | 6 | 3 | 3 |
| Markdown docs | 40+ | 10 | 30+ |

---

## Next Actions

1. **Create gaps** in `ops/bindings/operational.gaps.yaml` for each extraction target
2. **Run extraction** via capability or manual copy
3. **Verify** each extraction with `verify.domain.run` for applicable domains
4. **Update** SERVICE_REGISTRY.yaml after extraction

---

*End of L2 Runtime/Infra/Compose Diff Report*
