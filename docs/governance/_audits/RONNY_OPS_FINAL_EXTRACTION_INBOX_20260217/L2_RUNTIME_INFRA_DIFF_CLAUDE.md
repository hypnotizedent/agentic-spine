---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: ronny-ops-runtime-infra-diff-claude
parent_loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
lane: LANE-B (Claude Code)
---

# L2: Runtime / Infra / Compose Diff (Claude Code Terminal)

> Read-only discovery comparing legacy `ronny-ops` runtime/deploy/compose surfaces
> against `/Users/ronnyworks/code/workbench/infra/**` and `/Users/ronnyworks/code/agentic-spine/`.
> Produced by LANE-B (Claude Code) for LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217.
> Date: 2026-02-17

---

## 1. Summary

| Metric | Value |
|--------|-------|
| Docker-compose pairs compared | 13 |
| P0 findings (runtime authority risk) | 5 |
| P1 findings (extraction debt) | 18 |
| P2 findings (archive/drop) | 4 |
| Compose stacks legacy-only | 5 (finance, pihole, media, monitoring, mail-archiver) |
| Compose stacks workbench-authoritative | 7 (mcpjungle, mint-os, mint-os-frontends, n8n, storage, dashy, cloudflare) |
| Scripts completely un-migrated | 7 |
| LaunchAgents still pointing to legacy | 1 (works.ronny.paperless-sync) |
| GitHub Actions workflows legacy-only | 15 |
| MCP configs with plaintext secrets | 1 (postgres.json) |

---

## 2. Docker-Compose Stacks

### 2.1 P0 — Runtime Authority Risk

#### F-01: Finance Stack (legacy-only, live on VM 211)

- **Legacy:** `/Users/ronnyworks/ronny-ops/finance/docker-compose.yml`
- **Workbench:** No equivalent exists
- **Services:** postgres (16-alpine :5434), redis (7-alpine :6381), firefly-iii (:8090), importer (:8091), cron, ghostfolio (:3340), paperless-ngx (:8092)
- **Networks:** `finance-internal` (bridge) + `tunnel_network` (external)
- **Volumes:** `/mnt/data/finance/`
- **Risk:** Live 7-service production stack with SimpleFIN/Nordigen/Spectre integrations. Zero workbench representation. If legacy is deleted, no compose definition survives.
- **Target:** `workbench/infra/compose/finance/docker-compose.yml`

#### F-02: Finance Mail-Archiver (legacy-only, live on VM 211)

- **Legacy:** `/Users/ronnyworks/ronny-ops/finance/mail-archiver/docker-compose.yml`
- **Workbench:** No equivalent exists
- **Services:** mailarchive-app (s1t5/mailarchiver :5100), mail-archiver-db (postgres:17-alpine)
- **Confirmed live:** workbench cloudflare tunnel has `mail-archiver:100.76.153.100` in extra_hosts
- **Target:** `workbench/infra/compose/finance/mail-archiver/docker-compose.yml`

#### F-03: Cloudflare Tunnel (workbench authoritative, legacy dangerous)

- **Legacy:** `/Users/ronnyworks/ronny-ops/infrastructure/cloudflare/tunnel/docker-compose.yml`
- **Workbench:** `/Users/ronnyworks/code/workbench/infra/cloudflare/tunnel/docker-compose.yml`
- **Risk:** Legacy targets docker-host with Docker bridge networks and `TUNNEL_TOKEN`. Workbench targets infra-core (VM 204) with `network_mode: host`, `CLOUDFLARE_TUNNEL_TOKEN`, and complete service routing table (mint-os → 100.92.156.118, finance → 100.76.153.100, grafana → 100.120.163.70, mcpjungle → 100.98.70.70). Deploying legacy breaks tunnel routing for all services.
- **Action:** Archive/drop legacy. Workbench is authoritative.

### 2.2 P1 — Extraction Debt (Legacy-Only Stacks)

#### F-04: Media Stack (legacy-only, 28 services)

- **Legacy:** `/Users/ronnyworks/ronny-ops/media-stack/docker-compose.yml`
- **Workbench:** `infra/compose/arr/DEFERRED.md` (explicitly deferred)
- **Services (28):** jellyfin, prowlarr, sonarr, radarr, lidarr, bazarr, sabnzbd, qbittorrent, navidrome, slskd, soularr, spotisub, jellyseerr, recyclarr, huntarr, watchtower, homarr, wizarr, tdarr, posterizarr, flaresolverr, unpackerr, crosswatch, trailarr, swaparr-radarr, swaparr-sonarr, swaparr-lidarr, decypharr, crowdsec, node-exporter, autopulse, subgen
- **Note:** Legacy targets single host 100.117.1.53. MCPJungle workbench config shows media split to VM 209 (download) + VM 210 (streaming). Compose may itself be stale vs live.
- **Target:** `workbench/infra/compose/media-stack/docker-compose.yml` (validate against live VMs first)

#### F-05: Pi-hole (legacy-only)

- **Legacy:** `/Users/ronnyworks/ronny-ops/infrastructure/pihole/docker-compose.yml`
- **Workbench:** No equivalent
- **Services:** pihole (network_mode: host, DNS :53, DNSSEC, `NET_ADMIN` cap)
- **Note:** Legacy targets `192.168.12.191` (old docker-host IP). Live instance is on infra-core `100.92.91.128:8053`. Needs IP update during extraction.
- **Target:** `workbench/infra/compose/pihole/docker-compose.yml`

#### F-06: Monitoring Stack (legacy-only, 7 services)

- **Legacy:** `/Users/ronnyworks/ronny-ops/infrastructure/docker-host/mint-os/docker-compose.monitoring.yml`
- **Workbench:** No equivalent
- **Services:** prometheus (:9090), alertmanager (:9093), node-exporter (:9100), cadvisor (:8181), postgres-exporter (:9187), redis-exporter (:9121), grafana (:3000, URL: grafana.ronny.works)
- **Note:** Workbench cloudflare tunnel points grafana at `100.120.163.70` (VM 205), not docker-host. Monitoring may have moved to a dedicated VM.
- **Target:** `workbench/infra/compose/monitoring/docker-compose.yml` (validate host first)

### 2.3 P1 — Workbench Authoritative (Legacy Stale)

All following pairs show a consistent hardening delta in workbench: **localhost port binding**, **`x-logging` (json-file 10m/3)**, **`deploy.resources.limits`**, **`start_period` on healthchecks**. Legacy versions lack all four. Workbench is authoritative in every case.

| ID | Stack | Legacy Path | Workbench Path | Key Diff Beyond Hardening |
|----|-------|-------------|----------------|---------------------------|
| F-07 | MCPJungle | `infrastructure/mcpjungle/docker-compose.yml` | `infra/compose/mcpjungle/docker-compose.yml` | Legacy: single media IP, `tunnel_network`+`mint-data-network`. Workbench: split IPs (VM 209/210), 4 extra service env vars, networks removed. |
| F-08 | Mint OS | `infrastructure/docker-host/mint-os/docker-compose.yml` | `infra/compose/mint-os/docker-compose.yml` | Legacy: inline minio service (dupe of storage compose), `version: "3.8"`. Workbench: minio removed, modern compose. |
| F-09 | Mint OS Frontends | `infrastructure/docker-host/mint-os/docker-compose.frontends.yml` | `infra/compose/mint-os/docker-compose.frontends.yml` | Hardening only. Identical DB credentials and networks. |
| F-10 | N8N | `infrastructure/n8n/docker-compose.yml` | `infra/compose/n8n/docker-compose.yml` | Workbench adds ollama healthcheck, `service_healthy` depends_on, redis 5 retries. |
| F-11 | Storage | `infrastructure/storage/docker-compose.yml` | `infra/compose/storage/docker-compose.yml` | Hardening only. |
| F-12 | Dashy | `infrastructure/dashy/docker-compose.yml` | `infra/compose/dashy/docker-compose.yml` | Hardening only. |

### 2.4 P2 — Archive/Drop

| ID | Stack | Legacy Path | Reason |
|----|-------|-------------|--------|
| F-13 | Files API | `modules/files-api/docker-compose.yml` | Self-declared DEPRECATED. Superseded by `github:hypnotizedent/artwork-module`. |
| F-14 | Immich (archived) | `immich/.archive/2026-01-05-full-reset/configs/docker-compose.yml` | Already archived in legacy. |
| F-15 | Legacy Mint OS archive | `mint-os/docs/.archive/legacy-2025/mint-os-app-stack-v2/docker-compose.*.yml` (5 files) | Already archived in legacy. |

---

## 3. Scripts

### 3.1 P0 — Completely Un-Migrated (No Workbench Equivalent)

| ID | Legacy Script | Purpose |
|----|---------------|---------|
| S-01 | `/Users/ronnyworks/ronny-ops/media-stack/scripts/media-health.sh` | Media stack health check |
| S-02 | `/Users/ronnyworks/ronny-ops/media-stack/scripts/media-deep-check.sh` | Deep media diagnostics |
| S-03 | `/Users/ronnyworks/ronny-ops/home-assistant/scripts/deploy-home-assistant.sh` | HA deployment script |
| S-04 | `/Users/ronnyworks/ronny-ops/home-assistant/scripts/ha-health-check.sh` | HA health check |
| S-05 | `/Users/ronnyworks/ronny-ops/finance/scripts/deploy-finance-stack.sh` | Finance deployment (workbench archive only) |
| S-06 | `/Users/ronnyworks/ronny-ops/finance/scripts/scan-to-paperless.sh` | Scan-to-Paperless (workbench archive only, LaunchAgent depends — see L-01) |
| S-07 | `/Users/ronnyworks/ronny-ops/scripts/backup-all.sh` | Backup orchestrator (workbench archive only, no replacement) |

- **Target for S-01, S-02:** `workbench/scripts/root/media/` or spine capability
- **Target for S-03, S-04:** `workbench/scripts/root/ha/` or spine `ops/plugins/ha/`
- **Target for S-05, S-06:** `workbench/scripts/root/finance/`
- **Target for S-07:** evaluate if spine capabilities replace the orchestrator

### 3.2 P1 — Migrated Scripts with Functional Drift

| ID | Script | Drift | Impact |
|----|--------|-------|--------|
| S-08 | `mcpjungle/setup.sh` | Legacy uses `HA_TOKEN`; workbench uses `HA_API_TOKEN` | Running legacy looks up wrong Infisical secret name |
| S-09 | `n8n/setup-vm.sh` | Legacy scp path `~/ronny-ops/01_Infrastructure/` vs workbench `~/code/workbench/infra/` | Running legacy gives wrong copy instructions |
| S-10 | `n8n/scripts/sync_secrets.sh` | Legacy governance doc path stale | Cosmetic — no functional impact |
| S-11 | `bootstrap/new-docker-stack.sh` | Legacy doc references stale (secrets policy) | Cosmetic — no functional impact |

### 3.3 Successfully Migrated (No Action Needed)

Backup scripts (6: backup-finance, backup-media-configs, backup-mint-postgres, sync-to-synology, sync-ha-offsite, sync-vzdump-tier1-offsite), server lifecycle (2: server-startup, server-shutdown), health/monitoring (3: system-health, smoke-test, stack-drift-check), bootstrap (3: new-vm, new-lxc, new-postgres-db), simplefin-daily-sync — all have active workbench equivalents under `scripts/root/`.

---

## 4. LaunchAgent Plists

### 4.1 P0 — Live Legacy Dependency

| ID | Finding |
|----|---------|
| L-01 | **`works.ronny.paperless-sync.plist`** at `/Users/ronnyworks/ronny-ops/finance/launchagents/` triggers on WatchPaths `~/Documents/ScanSnap/receipts` and invokes `ronny-ops/finance/scripts/paperless-sync.sh`. NOT listed in workbench retirement doc (`LAUNCHD_RETIREMENT_2026-02-06.md`). Uses non-standard naming (`works.ronny.*` vs `com.ronny.*`). If still loaded, this is a live legacy dependency with no workbench replacement. |

### 4.2 Formally Retired (No Action)

7 plists (`com.ronny.backup-verify`, `com.ronny.ha-offsite-sync`, `com.ronny.macos-sync-critical`, `com.ronny.monitoring-verify`, `com.ronny.secrets-verify`, `com.ronny.vaultwarden-backup`, `com.ronny.vzdump-tier1-offsite`) — all formally retired per workbench `LAUNCHD_RETIREMENT_2026-02-06.md` and archived in `.archive/2026-02-06-ronny-ops-retired/`.

### 4.3 Shared Plist (Fully Rewritten)

`com.ronny.agent-inbox` — completely rewritten. Key changes:

| Attribute | Legacy | Workbench |
|-----------|--------|-----------|
| Script | `ronny-ops/scripts/agents/hot-folder-watcher.sh` | `agentic-spine/ops/runtime/inbox/hot-folder-watcher.sh` |
| WorkingDirectory | `/Users/ronnyworks/ronny-ops` | `/Users/ronnyworks/code/agentic-spine` |
| Env vars | `RONNY_OPS_REPO`, `AGENT_INBOX/OUTBOX/STATE` | `SPINE_REPO`, `SPINE_INBOX/OUTBOX/STATE/LOGS`, `SPINE_WATCHER_PROVIDER=zai`, `ZAI_MODEL=glm-5` |
| Log paths | `~/agent/logs/` | `agentic-spine/mailroom/logs/` |

Workbench is authoritative.

---

## 5. MCP Server Configs

13 JSON configs + 5 custom server subdirectories in both repos.

### Identical (No Action): 7 configs

`fetch.json`, `filesystem.json`, `github.json`, `infisical.json`, `memory.json`, `mint-os.json`, `n8n.json`

### Material Drift: 6 configs

| ID | Config | Drift | Severity |
|----|--------|-------|----------|
| M-01 | **postgres.json** | Legacy has **plaintext password** (`gPHLKbNIET3kN9qNhAmDDnJEYErCeR1T@mint-data-postgres:5432/mintprint_vault`). Workbench parameterized via `${POSTGRES_API_PASSWORD}`, `${POSTGRES_HOST}`, `${POSTGRES_PORT}`, DB name `mint_os`. | **P0** |
| M-02 | **media-stack.json** | Legacy: 6 services on single IP `100.117.1.53`. Workbench: 10 services (adds Jellyseerr, Bazarr, Navidrome, Huntarr), split across `100.123.207.64` (streaming) and `100.107.36.76` (download). | P1 |
| M-03 | **home-assistant.json** | Legacy: `HA_TOKEN`. Workbench: `HA_API_TOKEN`. | P1 |
| M-04 | **firefly.json** | Workbench: `"enabled": false`, superseded by finance-agent V1. Env key changed `FIREFLY_III_PAT` → `FIREFLY_PAT`. | P1 |
| M-05 | **paperless.json** | Workbench: `"enabled": false`, superseded by finance-agent V1. URL updated to `100.76.153.100` (VM 211). | P1 |
| M-06 | **microsoft-graph.json** | Legacy: hardcoded Azure tenant/client IDs inline. Workbench: `<GET_FROM_INFISICAL:...>` placeholders. | P1 |

---

## 6. Infrastructure Data Inventories

| ID | File | Key Drift | Severity |
|----|------|-----------|----------|
| D-01 | **Agents Inventory** | Legacy: 27 agents. Workbench: 2 agents (infisical-agent, cloudflare-agent). 25 superseded by spine capabilities. | P1 |
| D-02 | **Backup Inventory** | Legacy frozen pre-migration. Workbench: VM 201 decommissioned, VM 204 (infra-core) added, VM 211 (finance-stack) added, Infisical/Vaultwarden/Firefly migration notes. | P1 |
| D-03 | **Monitoring Inventory** | Legacy: 9 endpoints, Infisical on docker-host:8088. Workbench: 12 endpoints (adds vaultwarden, cloudflared, pihole), Infisical on infra-core:8080. Marked `"status": "historical"` — canonical authority is `ops/bindings/services.health.yaml` in spine. | P1 |
| D-04 | **Secrets Inventory** | Legacy: Infisical on docker-host, `HA_TOKEN`, 9 projects. Workbench: infra-core, `HA_API_TOKEN`, 8 projects, finance-stack deprecated, SPOF resolved. | P1 |
| D-05 | **Updates Inventory** | Legacy enables watchtower + CI/CD. Workbench disables both as out-of-scope. | P1 |
| D-06 | **Service Registry** | Legacy: 5 services. Workbench: **TOMBSTONED** (empty). Authority at `agentic-spine/docs/governance/SERVICE_REGISTRY.yaml`. | P1 |
| D-07 | **Backup Calendar** | Both empty templates. No drift. | — |

---

## 7. GitHub Actions Workflows

**15 workflows in legacy. 0 in workbench. 0 in spine.**

| Workflow | Scope | Severity |
|----------|-------|----------|
| `deploy-admin.yml` | Mint OS deploy | P2 (belongs in mint-os repo) |
| `deploy-api.yml` | Mint OS deploy | P2 |
| `deploy-customer.yml` | Mint OS deploy | P2 |
| `deploy-production.yml` | Mint OS deploy | P2 |
| `api-health-check.yml` | Runtime health | P1 (evaluate spine cap replacement) |
| `backup-verification.yml` | Backup ops | P1 |
| `infrastructure.yml` | Infra changes | P1 |
| `weekly-audit.yml` | Audit | P1 |
| `weekly-repo-audit.yml` | Audit | P1 |
| `kanban-sync.yml` | Business ops | P1 |
| `memory-sync.yml` | Knowledge sync | P1 |
| `auto-label-issues.yml` | Repo ops | P2 |
| `documentation-lint.yml` | Docs QA | P2 |
| `label-sync.yml` | Repo ops | P2 |
| `task-sync.yml.disabled` | Already disabled | P2 |

---

## 8. Dockerfiles

| ID | File | Status | Severity |
|----|------|--------|----------|
| DF-01 | `infrastructure/mcpjungle/docker/Dockerfile` | **Identical** in workbench | No action |
| DF-02 | `mint-os/apps/*/Dockerfile` (5 files) | Legacy-only | P2 (belong in mint-os app repo) |
| DF-03 | `modules/files-api/Dockerfile` | Legacy-only, superseded by artwork-module repo | P2 |

---

## 9. Home Assistant Configs

| Surface | Legacy | Workbench | Un-Migrated | Severity |
|---------|--------|-----------|-------------|----------|
| Core configs (yaml) | 14 items | 6 files | 10 (helpers, packages, themes, www, zigbee2mqtt configs, streamdeck, docker_addons.txt, scripts dir) | P1 |
| Dashboard YAML | 10 | 9 | 1 (`command-center-v2-stage.yaml`) | P1 |
| Dashboard reference docs | 9 | 0 | 9 markdown reference docs (AIR_PURIFIERS, BATTERIES, COMMAND_CENTER, DASHBOARD_PATTERNS, HOME_HUB, LIGHTS_POPUP, LISTS_CHORES, MEDIA_PAGE, WALL_CALENDAR) | P2 |

- **Target:** `workbench/infra/homeassistant/config/` for configs, `workbench/infra/ha-dashboards/` for dashboards

---

## 10. Media Stack Configs

| Config | Legacy Path | Workbench | Severity |
|--------|-------------|-----------|----------|
| Kometa | `media-stack/config/kometa/config.yml` + `collections/trending.yml` | None (DEFERRED.md) | P1 |
| Recyclarr | `media-stack/config/recyclarr/recyclarr.yml` + docs | None | P1 |
| Janitorr | `media-stack/config/janitorr/application.yml` | None | P1 |

- **Target:** `workbench/infra/compose/media-stack/config/` (after F-04 compose extraction)

---

## 11. N8N Workflows

30 of 34 legacy workflows present in workbench. 4 legacy-only:

| Workflow | Severity |
|----------|----------|
| `CB_metrics_sync.json` | P2 (likely stale) |
| `Jellyfin_Collection_Sync_5RqaiUC21RWDgD6H.json` | P1 |
| `Jellyfin_Collection_Sync_CdDYpm9Uxbm5LfsJ.json` | P1 |
| `Media_Stack_Notifications.json` | P1 |

Workbench has 1 workflow not in legacy: `Spine_-_Mailroom_Enqueue.json` (spine-native).

---

## 12. Governance YAMLs

All 4 legacy governance files migrated to spine with `status: authoritative`:

| File | Spine Path | Last Verified |
|------|-----------|---------------|
| `DOMAIN_ROUTING_REGISTRY.yaml` | `agentic-spine/docs/governance/DOMAIN_ROUTING_REGISTRY.yaml` | 2026-02-12 |
| `SSOT_REGISTRY.yaml` | `agentic-spine/docs/governance/SSOT_REGISTRY.yaml` | 2026-02-15 |
| `STACK_REGISTRY.yaml` | `agentic-spine/docs/governance/STACK_REGISTRY.yaml` | 2026-02-11 |
| `GOVERNANCE_MANIFEST.yaml` | `agentic-spine/docs/governance/GOVERNANCE_MANIFEST.yaml` | 2026-02-16 |

No action needed. Legacy copies superseded.

---

## 13. Dotfiles

Workbench dotfiles are a superset of legacy. 5 new tool configs added (codex, espanso, iterm2, opencode, superwhisper). Git, SSH, hammerspoon, raycast all migrated. No extraction needed.

---

## Consolidated P0 Findings

| ID | Finding | Source | Target |
|----|---------|--------|--------|
| **F-01** | Finance stack compose (7 services, live VM 211) | `ronny-ops/finance/docker-compose.yml` | `workbench/infra/compose/finance/docker-compose.yml` |
| **F-02** | Finance mail-archiver compose (2 services, VM 211) | `ronny-ops/finance/mail-archiver/docker-compose.yml` | `workbench/infra/compose/finance/mail-archiver/docker-compose.yml` |
| **F-03** | Cloudflare tunnel legacy dangerous if deployed | `ronny-ops/infrastructure/cloudflare/tunnel/docker-compose.yml` | Archive/drop (workbench authoritative) |
| **L-01** | Paperless-sync LaunchAgent not retired, points to legacy script | `ronny-ops/finance/launchagents/works.ronny.paperless-sync.plist` | Retire or extract to `workbench/dotfiles/macbook/launchd/` |
| **M-01** | postgres.json has plaintext DB password in legacy | `ronny-ops/infrastructure/mcpjungle/servers/postgres.json` | Ensure legacy copy is purged when repo archived |

---

## Extraction Priority Summary

### P0 — Extract Now (runtime authority at risk)

1. Finance stack compose + mail-archiver → `workbench/infra/compose/finance/`
2. Retire or migrate `works.ronny.paperless-sync` LaunchAgent
3. Purge/archive legacy cloudflare tunnel compose
4. Audit legacy postgres.json for credential exposure

### P1 — Extract Soon (operational debt)

5. Media stack compose + configs + scripts → `workbench/infra/compose/media-stack/`
6. Pi-hole compose → `workbench/infra/compose/pihole/` (update IPs)
7. Monitoring stack compose → `workbench/infra/compose/monitoring/` (validate host)
8. HA un-migrated configs (10 items) → `workbench/infra/homeassistant/config/`
9. Media health scripts (media-health.sh, media-deep-check.sh)
10. HA scripts (deploy-home-assistant.sh, ha-health-check.sh)
11. N8N legacy-only workflows (3 active)
12. GitHub Actions audit/health workflows (evaluate spine cap replacement)

### P2 — Archive/Drop

13. Files API compose + Dockerfile (self-deprecated)
14. Mint OS Dockerfiles (belong in mint-os app repo)
15. Mint OS deploy GitHub Actions (belong in mint-os repo)
16. HA dashboard reference docs (9 markdown files)
17. Legacy archived composes (immich, mint-os-v2)

---

*End of L2 Runtime/Infra/Compose Diff Report (Claude Code Terminal)*
