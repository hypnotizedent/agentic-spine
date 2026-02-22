---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: ronny-ops-domain-docs-diff
parent_loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
lane: LANE-C
---

# L3: Domain Docs / Runbook Diff

> Compares legacy `ronny-ops` domain documentation and runbooks against current
> `workbench/docs/**` and `agentic-spine/docs/**` to identify missing high-value
> operational knowledge still stranded in the legacy repo.
>
> Date: 2026-02-17

---

## 1. Methodology

| Step | Description |
|------|-------------|
| Census | Full recursive inventory of all three doc surfaces (~1,642 legacy, ~177 workbench, ~313 spine) |
| Classification | Every legacy doc categorized by domain, value tier, and extraction status |
| Deep read | 55+ high-value legacy files read and assessed for unique operational knowledge |
| Cross-reference | Each legacy doc checked against workbench brain-lessons, spine governance, and domain docs |

**Value tiers:**
- **P0-EXTRACT** — Unique operational knowledge not present anywhere in code/; hard to reconstruct
- **P1-PARTIAL** — Core knowledge extracted but specific details missing (configs, IDs, gotchas)
- **P2-COVERED** — Adequately represented in current docs (may need freshness check)
- **DROP** — Superseded, deprecated, or auto-regenerable

---

## 2. Summary Scorecard

| Domain | Legacy Files | P0-EXTRACT | P1-PARTIAL | P2-COVERED | DROP |
|--------|-------------|------------|------------|------------|------|
| Home Assistant | ~213 | 7 | 4 | 3 | ~199 |
| Media Stack | ~158 | 6 | 4 | 3 | ~145 |
| Finance | ~57 | 5 | 2 | 2 | ~48 |
| Infrastructure (governance) | ~101 | 5 | 3 | 4 | ~89 |
| Infrastructure (services) | ~384 | 4 | 3 | 2 | ~375 |
| Immich | ~134 | 3 | 1 | 1 | ~129 |
| Mint-OS | ~14,606 | 0 | 0 | 0 | ~14,606 |
| **Totals** | **~15,653** | **30** | **17** | **15** | **~15,591** |

> 30 files contain unique high-value knowledge not present in current docs.
> 17 files are partially extracted with specific details still stranded.

---

## 3. Per-Domain Diff

### 3.1 Home Assistant

#### P0-EXTRACT (missing entirely from workbench + spine)

| Legacy File | Knowledge | Why It Matters |
|-------------|-----------|----------------|
| `home-assistant/docs/Runbooks/ZIGBEE_RECOVERY.md` | Zigbee2MQTT `options.json` Docker cache fix; SLZB-06 adapter mode config (USB disabled, Ethernet enabled, TCP port 6638 not 6053); exact container ID path | Prevents hours of debugging on next Zigbee failure |
| `home-assistant/docs/Runbooks/RUNBOOK_CALDAV_APPLE.md` | Apple CalDAV endpoint (`caldav.icloud.com`), app-specific password format, entity names (`calendar.lilbabymarium_n_ronron`, `calendar.work`), HACS cards needed, Infisical credential keys | Only runbook for calendar integration; credentials would need rediscovery |
| `home-assistant/docs/Runbooks/RUNBOOK_TV_WAKE_ON_LAN.md` | Guest Room LG MAC `24:E8:53:CE:22:66`, required TV settings ("TV On With Mobile" + "Quick Start+"), known HA 2025.11+ WoL bug, broadcast address `10.0.0.255` | Device-specific config not discoverable without physical access |
| `home-assistant/docs/reference/CLI_COOKBOOK.md` | Custom sidebar plugin config path, bubble-card critical gotcha (content cards are SIBLINGS not children), icon prefix system (`hue:`, `m3:`, `mdi:`), glass morphism CSS exact values, Ring camera snapshot entity naming, Zigbee button automation pattern with startup guard | Pattern library of tested solutions; hours of trial-and-error |
| `home-assistant/docs/reference/HA_INFRASTRUCTURE.md` | Area IDs with typo notes, per-room device inventory with tested status, integration status matrix, Zigbee device IEEE addresses (6 devices), URL registry, CLI Python scripts | Authoritative device registry with verified states |
| `home-assistant/configs/dashboards/DASHBOARD_PATTERNS.md` | HACS card prefix system, room color palette with RGBA values (King/Empress/Guest/Office), opacity guide by purpose, 5 ready-made pattern templates, popup troubleshooting matrix | Copy-paste reference for dashboard work |
| `home-assistant/docs/guides/DASHBOARD_STYLE_GUIDE.md` | Brand guide: "HACS over Default Always", icon pack rules (`hue:` for lights, `m3:` for actions), per-room RGB+Hex palette with 5 opacity levels, glass morphism CSS formula, card type selection matrix, NEVER-use list, bubble-card popup structure rules | Authoritative brand guidelines for all future dashboard work |

#### P1-PARTIAL (core extracted, details missing)

| Legacy File | What's Missing | Current Coverage |
|-------------|---------------|-----------------|
| `home-assistant/docs/Runbooks/DEPLOY_CHECKLIST.md` | HACS card prerequisites, reload endpoint path, entity mappings for dashboards | Spine has `HASS_OPERATIONAL_RUNBOOK.md` but lacks dashboard deploy specifics |
| `home-assistant/docs/Runbooks/HA_RESYNC.md` | Ring 2FA re-auth procedure, iOS Background App Refresh requirement, symptom→action mappings | Workbench `HOME_ASSISTANT_LESSONS.md` covers architecture but not troubleshooting |
| `home-assistant/docs/reference/NETWORK_MAP.md` | Subnet layout, critical IPs (HA, SLZB-06, NAS, Immich) | Spine `DEVICE_IDENTITY_SSOT.md` covers Tailscale IPs but not LAN topology |
| `home-assistant/configs/streamdeck/` | Stream Deck button mappings and HA service call configs | Not present in either repo |

#### P2-COVERED

| Legacy File | Current Coverage |
|-------------|-----------------|
| `home-assistant/docs/reference/REF_AUTOMATIONS.md` | Auto-generated snapshot; regenerable via HA API |
| `home-assistant/docs/reference/REF_INTEGRATIONS.md` | Auto-generated snapshot; regenerable via HA API |
| `home-assistant/docs/devices/DEVICES.md` | DEPRECATED in legacy; replaced by HA_INFRASTRUCTURE.md |

#### DROP (~199 files)

Session notes (30+), archived docs (100+), future project sketches (ESP32, Frigate), plans superseded by spine loops.

---

### 3.2 Media Stack

#### P0-EXTRACT

| Legacy File | Knowledge | Why It Matters |
|-------------|-----------|----------------|
| `media-stack/docs/reference/REF_CRITICAL_RULES.md` | 6 production-incident-driven rules: never bulk-search >3000 movies (VM I/O freeze), trickplay permanently disabled (187+ load average), chapter image extraction disabled (NFS ffmpeg buffering); file permission locks, automated guards | Prevents VM crashes; workbench `MEDIA_CRITICAL_RULES.md` has summary but lacks Rule 5/6 detail |
| `media-stack/docs/reference/REF_MEDIA_PIPELINE.md` | 15+ container port mappings, Jellyfin plugin roster, n8n workflow IDs (`CdDYpm9Uxbm5LfsJ`, `BZiUwJP9aYWKAg0m`), Navidrome Spotify/Last.fm env vars, boot dependency chain, NFS mount points, hardware transcoding assessment, Radarr TMDb keyword IDs (MCU: 180547, DCEU: 229266) | Architectural reference needed for disaster recovery and service restoration |
| `media-stack/RUNBOOK_TDARR.md` | NFS-safe settings (`scannerThreadCount: 1`, `folderWatchScanInterval: 300s`), 2026-01-30 incident (1009 simultaneous NFS reads froze VM), worker stall detector config, API recovery procedures, table reference mapping, codec distribution analysis | Prevents production outages from NFS saturation |
| `media-stack/RUNBOOK_RECOVER.md` | Container startup order (Prowlarr -> *arr -> SABnzbd -> Bazarr -> Jellyfin -> Jellyseerr), NFS mount dependency on Tailscale, Cloudflare tunnel restart, health check verification points, Proxmox hard reset command (`qm reset 201`) | Critical incident response playbook |
| `media-stack/docs/reference/REF_DOWNLOAD_ARCHITECTURE.md` | Dual-path strategy (Shop 160Mbps passive vs Home 1Gbps turbo), Huntarr rates (5 movies/15min, 1 episode/15min, 1 album/15min), gradual movie search cron path, SABnzbd bandwidth settings (`bandwidth_max=50M`), encrypted file handling | Operational patterns for bandwidth management |
| `media-stack/docs/reference/REF_NAVIDROME.md` | Spotify API integration env vars (`ND_SPOTIFY_ID`, `ND_SPOTIFY_SECRET`), Last.fm scrobbling config, client recommendations (Feishin macOS, Substreamer iOS/CarPlay), transcoding format (`opus`), Subsonic API endpoint, Substreamer macOS crash workaround | Only reference for music streaming integration |

#### P1-PARTIAL

| Legacy File | What's Missing | Current Coverage |
|-------------|---------------|-----------------|
| `media-stack/docs/reference/REF_QUALITY_PROFILES.md` | Recyclarr sync command, BR-DISK scoring (-10000), profile hierarchy | Workbench has architecture but not quality profile specifics |
| `media-stack/docs/reference/REF_HOME_DOWNLOADER.md` | LXC 103 setup, SABnzbd API key, Synology staging mount paths, transfer script path | Workbench `DOWNLOAD_HOME_NOTES.md` has quick reference but not full detail |
| `media-stack/RUNBOOK_SUBGEN.md` | AI subtitle hardware constraints (CPU ~10min/hr, GPU ~1min/hr), model sizes, Jellyfin webhook config, device setting for R730XD | Not present in current docs |
| `media-stack/RUNBOOK_DECYPHARR.md` | Real-Debrid API key storage, port mappings (8282/8283), symlink paths, rclone mount requirement | Not present in current docs |

#### P2-COVERED

| Legacy File | Current Coverage |
|-------------|-----------------|
| `media-stack/docs/reference/REF_MEDIA_INVENTORY.md` | Point-in-time snapshot; regenerable via Jellyfin/Radarr APIs |
| `media-stack/docs/reference/REF_SERVICES_MATRIX.md` | Container inventory; regenerable and rapidly stale |
| `media-stack/config/recyclarr/README.md` | Generic Recyclarr docs; rediscoverable |

---

### 3.3 Finance

#### P0-EXTRACT

| Legacy File | Knowledge | Why It Matters |
|-------------|-----------|----------------|
| `finance/docs/reference/REF_ACCOUNT_REGISTRY.md` | 17 financial accounts (3 Chase, 8 AmEx, 4 Citi/CapOne) with last-4 digits and Firefly IDs; fixed assets inventory (heat press $374.49, screen press $15,000); payment processor accounts; equity accounts | Financial backbone; weeks to reconstruct from bank statements |
| `finance/docs/reference/REF_CATEGORY_MAPPING.md` | QuickBooks→Firefly category mappings (8 revenue, 8 COGS, 22 operating expense); QB codes 4000-9000; 27 blank apparel vendor auto-match patterns; shipping/software/print supply vendor patterns; Tax Schedule C line mappings; auto-categorization regex | Business-specific categorization; days to rebuild from scratch |
| `finance/docs/reference/REF_IMPORT_CONFIGS.md` | Bank-specific CSV column mappings for Chase, AmEx, Citi, Capital One, Square; date format conventions per bank; amount sign conventions; duplicate detection logic; saved config file paths | Tedious to rediscover per-bank export format quirks |
| `finance/docs/runbooks/RUNBOOK_FIREFLY_MINTOS_SYNC.md` | Bidirectional sync architecture; Firefly webhook ID 2; n8n workflow ID `upgFmdx32jnsW30J`; Postgres connection details; 25 syncable categories with auto-link logic; vendor ID mapping (8 vendors); idempotency constraint; backfill script | Complex bidirectional integration with specific IDs |
| `finance/docs/guides/SOP_RECEIPT_SCANNING.md` | Complete scanning workflow (mobile, email, digital); Paperless-ngx tag structure; correspondence vendor list; custom field `firefly_transaction_id`; retention policy by doc type (7yr tax, 1yr personal); monthly reconciliation procedure | Human workflow procedure; not captured elsewhere |

#### P1-PARTIAL

| Legacy File | What's Missing | Current Coverage |
|-------------|---------------|-----------------|
| `finance/docs/reference/REF_SIMPLEFIN_MAPPING.md` | SimpleFIN→Firefly account UUID mappings for 15 accounts; accounts NOT in SimpleFIN; Data Importer SSH tunnel setup | Workbench `FINANCE_SIMPLEFIN_PIPELINE.md` covers flow but not account UUIDs |
| `finance/docs/troubleshooting/TRB_FINANCE_STACK.md` | SimpleFIN cron log location, Paperless OCR quality issues (thermal receipt blur), n8n workflow activation toggle, Data Importer SSH tunnel command | Workbench `FINANCE_TROUBLESHOOTING.md` covers quick diagnostics but not all edge cases |

#### P2-COVERED

| Legacy File | Current Coverage |
|-------------|-----------------|
| `finance/docs/reference/REF_FIREFLY_SETUP.md` | Workbench `FINANCE_STACK_ARCHITECTURE.md` |
| `finance/docs/guides/SOP_FIREFLY_CONFIGURATION.md` | Workbench `FINANCE_DEPLOY_RUNBOOK.md` |

---

### 3.4 Infrastructure (Governance & Cross-Domain)

#### P0-EXTRACT

| Legacy File | Knowledge | Why It Matters |
|-------------|-----------|----------------|
| `docs/runbooks/BACKUP_GOVERNANCE.md` | Asset tier classification (Critical/Important/Rebuildable/Snapshot/Cold); vzdump job name and schedule (02:00, zstd, maxfiles=2); backup sizes per VM (docker-host ~207GB, media ~23GB); offsite policy (Tier 1 weekly to Synology, 4 copies); big data strategy (Immich 1.15TB ZFS snapshots, media 7.66TB rebuildable); restore drill cadence | Spine has `BACKUP_GOVERNANCE.md` but lacks legacy-specific vzdump details and asset classification |
| `docs/runbooks/SERVICE_UPDATES_GOVERNANCE.md` | 5-tier update schedule (Proxmox quarterly, Ubuntu monthly 1st Sat, Core apps monthly 2nd Sat, App containers auto via Watchtower 4AM, Mint OS CI/CD); version pinning rules (postgres:16.1, redis:7.2.4, n8n:1.24.1); Watchtower scope (media-stack only); emergency CVE override process | No equivalent in current docs; prevents uncoordinated updates |
| `docs/runbooks/REBOOT_HEALTH_GATE.md` | HARD STOP conditions (ZFS degraded, backup running, VM migrating, disk <10%); SOFT WARN conditions; pre/post-reboot validation checklist; autostart config check command; script path `reboot_gate.sh` | Spine has `REBOOT_HEALTH_GATE.md` but should be compared for content parity |
| `infrastructure/cloudflare/CLOUDFLARE_GOVERNANCE.md` | Dual auth methods (Global API Key vs API Token); API Token scopes; Zone IDs (mintprints.co `8455a175...`, ronny.works `6d3f8f90...`); Tunnel ID `ae7d4462...`; Pages projects; CNAME gotcha (DNS-only not proxied or 522); cache purge CLI | Spine has `CLOUD_FLARE_BINDING.md` but not the governance rules or gotchas |
| `infrastructure/docs/INCIDENTS_LOG.md` | 4+ production incidents: tdarr NFS saturation (2026-01-30), MinIO Cloudflare upload failure (2026-01-27), Tailscale DNS blocking Wrangler (2026-01-22, fix: `--accept-dns=false --reset`), HA Radarr connectivity Docker binding issue (2026-01-19) | Historical incident patterns prevent repeat failures |

#### P1-PARTIAL

| Legacy File | What's Missing | Current Coverage |
|-------------|---------------|-----------------|
| `infrastructure/SERVICE_REGISTRY.md` | Tailscale IP topology, RAG stack location, MinIO bucket inventory (8 buckets, 83,992 objects, 162 GiB), per-service port mappings, health/drift items | Spine `ops/bindings/` has machine-readable SSOTs but may lack some detail |
| `docs/governance/SSOT_REGISTRY.yaml` | 35+ SSOTs with tier classification (1-4), conflict resolution rules, artwork module lock, data inventory list | Spine has its own SSOT governance but should be compared for missing entries |
| `infrastructure/mcpjungle/RECOVERY_RUNBOOK.md` | MCPJungle DB persistence fix (volume mount), 11 expected servers, `.env` generation script, 19 Infisical credentials, re-registration bash loop | No MCPJungle recovery docs in current repos |

#### P2-COVERED

| Legacy File | Current Coverage |
|-------------|-----------------|
| `docs/governance/SECRETS_POLICY.md` | Spine `SECRETS_POLICY.md` + `SECRETS_BINDING.md` |
| `docs/governance/COMPOSE_AUTHORITY.md` | Spine `COMPOSE_AUTHORITY.md` |
| `infrastructure/domains/DOMAIN_REGISTRY.md` | Workbench `docs/legacy/infrastructure/reference/domains/` |
| `infrastructure/microsoft/runbooks/OUTLOOK_V1_SPAM_TRIAGE.md` | Spine `docs/governance/GRAPH_RUNBOOK.md` (partially) |

---

### 3.5 Immich

#### P0-EXTRACT

| Legacy File | Knowledge | Why It Matters |
|-------------|-----------|----------------|
| `immich/docs/reference/PHOTO_IMPORT_RULES.md` | "KEEPER = Most EXIF + Oldest DateTimeOriginal" philosophy; known camera issues (NIKON D50 clock resets to 2005, FUJIFILM X100 ~8yr behind, GoPro variable); pre-import workflow (manifest -> pHash group -> flag -> human review -> upload); human-in-the-loop principle | Prevents automated data loss; philosophy not captured elsewhere |
| `immich/IMMICH_CONTEXT.md` | VMID 203, 139,234 files at 13% copied, corrupt SanDisk SSD status, ML settings needed, backup script path and schedule (03:00 daily, offsite 04:30), EXIF extraction script | Current state reference for ongoing migration |
| `infrastructure/home-services/nas/DAKOTA_EMBROIDERY_PROJECT.md` | 93,562 `.dst` production files, 287,806->106,439 cleanup, 127 `.emb` Wilcom masters (VALUABLE), ~15K-20K unique designs, folder breakdown by brand (Anita Goodesign 9.1GB, Dakota Collectibles 6.4GB), R730XD target path, catalog indexing approach | Major business asset library; unique inventory data |

#### P1-PARTIAL

| Legacy File | What's Missing | Current Coverage |
|-------------|---------------|-----------------|
| `immich/docs/guides/INSTALL_IMMICH_R730XD.md` | Local storage mounting options (USB passthrough vs NFS), `.env` template | Workbench `IMMICH_BACKUP_RESTORE.md` + `IMMICH_OPERATIONS_LESSONS.md` cover operations but not install |

---

### 3.6 Legacy Brain / Session Memory

#### P0-EXTRACT

| Legacy File | Knowledge | Why It Matters |
|-------------|-----------|----------------|
| `.brain/memory.md` | Jan 22-25 operational learnings: RAG useless without enforcement, rsync timeout in foreground SSH (use `nohup`), file count vs disk size mismatch (sparse files), MinIO `mc alias` inside container, NFS hard vs soft mount for DBs, Printavo rename 50% complete (~16,799 files need renaming, ~37,539 orphans), merge-gate pattern (file count + guardrail + scope) | Accumulated operational wisdom from 4 sprint days |

---

### 3.7 Mint-OS

**Disposition: ARCHIVE WHOLESALE**

The `mint-os/` directory (14,606 files) is a complete T3/pnpm monorepo (8 apps, packages, tools). This is application source code, not operational documentation. It should be archived as a standalone repo or tarball. No operational knowledge extraction needed — the business logic lives in the code, not in docs that agents would consume.

The only docs of note are:
- `docs/SCHEMA_TRUTH.md` — Database schema SSOT (useful if Mint-OS development resumes)
- `docs/QUOTE_SINGLE_SOURCE_OF_TRUTH.md` — Quote creation flow
- `docs/API_GOVERNANCE.md` — API standards

These are application-layer docs, not infrastructure/operations docs. They belong with the application code, not in the spine.

---

## 4. Gap Map: High-Value Knowledge Not in Current Docs

### 4.1 Runbooks (Operational Procedures)

| # | Domain | Missing Runbook | Severity | Target |
|---|--------|----------------|----------|--------|
| R1 | HA | Zigbee recovery (options.json fix, SLZB-06 config) | HIGH | `workbench/docs/brain-lessons/` |
| R2 | HA | CalDAV/Apple calendar integration | HIGH | `workbench/docs/brain-lessons/` |
| R3 | HA | TV Wake-on-LAN (device MACs, TV settings) | MEDIUM | `workbench/docs/brain-lessons/` |
| R4 | Media | Tdarr NFS-safe configuration | HIGH | `workbench/docs/brain-lessons/` |
| R5 | Media | Service recovery (startup order, NFS deps) | HIGH | `workbench/docs/brain-lessons/` |
| R6 | Media | Navidrome music streaming integration | MEDIUM | `workbench/docs/brain-lessons/` |
| R7 | Finance | Receipt scanning SOP | HIGH | `workbench/docs/brain-lessons/` |
| R8 | Finance | Firefly-Mint bidirectional sync | HIGH | `workbench/docs/brain-lessons/` |
| R9 | Infra | MCPJungle recovery (DB persistence, re-registration) | MEDIUM | `workbench/docs/brain-lessons/` |
| R10 | Infra | Service update tiers and schedule | HIGH | `workbench/docs/brain-lessons/` |

### 4.2 Reference Data (Configuration Knowledge)

| # | Domain | Missing Reference | Severity | Target |
|---|--------|------------------|----------|--------|
| D1 | HA | Dashboard style guide + patterns (brand, colors, CSS) | HIGH | `workbench/docs/brain-lessons/` |
| D2 | HA | Device registry with verified states + IEEE addresses | HIGH | `workbench/docs/brain-lessons/` |
| D3 | Media | Pipeline architecture (ports, plugins, workflow IDs, boot chain) | HIGH | `workbench/docs/brain-lessons/` |
| D4 | Media | Critical rules (6 incident-driven production rules) | MEDIUM | Merge into existing `MEDIA_CRITICAL_RULES.md` |
| D5 | Media | Download architecture (dual-path, Huntarr rates, bandwidth) | MEDIUM | Merge into existing `MEDIA_DOWNLOAD_ARCHITECTURE.md` |
| D6 | Finance | Account registry (17 accounts, fixed assets) | HIGH | `workbench/docs/brain-lessons/` |
| D7 | Finance | Category mappings (QB codes, vendor patterns, tax lines) | HIGH | `workbench/docs/brain-lessons/` |
| D8 | Finance | Bank CSV import configs (column maps, date/sign conventions) | HIGH | `workbench/docs/brain-lessons/` |
| D9 | Infra | Cloudflare governance (dual auth, zone IDs, tunnel ID, gotchas) | HIGH | `workbench/docs/brain-lessons/` |
| D10 | Infra | Incidents log (4+ production incidents with root causes) | HIGH | `workbench/docs/brain-lessons/` |
| D11 | Immich | Photo import rules (KEEPER philosophy, camera anomalies) | HIGH | `workbench/docs/brain-lessons/` |
| D12 | Immich | Dakota embroidery library inventory (93K files, business model) | HIGH | `workbench/docs/brain-lessons/` |
| D13 | Brain | Session memory Jan 22-25 (rsync, MinIO, NFS learnings) | MEDIUM | Merge into spine session memory |

### 4.3 Already-Covered Content (Verify Freshness Only)

| Domain | Covered By | Verify |
|--------|-----------|--------|
| Finance stack architecture | `workbench/docs/brain-lessons/FINANCE_STACK_ARCHITECTURE.md` | OK |
| Finance deploy runbook | `workbench/docs/brain-lessons/FINANCE_DEPLOY_RUNBOOK.md` | OK |
| Finance n8n workflows | `workbench/docs/brain-lessons/FINANCE_N8N_WORKFLOWS.md` | OK |
| Finance SimpleFin pipeline | `workbench/docs/brain-lessons/FINANCE_SIMPLEFIN_PIPELINE.md` | Check UUIDs |
| Finance reconciliation | `workbench/docs/brain-lessons/FINANCE_RECONCILIATION.md` | OK |
| Finance backup/restore | `workbench/docs/brain-lessons/FINANCE_BACKUP_RESTORE.md` | OK |
| Finance troubleshooting | `workbench/docs/brain-lessons/FINANCE_TROUBLESHOOTING.md` | Check edge cases |
| Media critical rules | `workbench/docs/brain-lessons/MEDIA_CRITICAL_RULES.md` | Merge Rules 5-6 |
| Media download architecture | `workbench/docs/brain-lessons/MEDIA_DOWNLOAD_ARCHITECTURE.md` | Check Huntarr rates |
| Media pipeline | `workbench/docs/brain-lessons/MEDIA_PIPELINE_ARCHITECTURE.md` | Check workflow IDs |
| Media recovery | `workbench/docs/brain-lessons/MEDIA_RECOVERY_RUNBOOK.md` | Check startup order |
| Media stack lessons | `workbench/docs/brain-lessons/MEDIA_STACK_LESSONS.md` | OK |
| HA lessons | `workbench/docs/brain-lessons/HOME_ASSISTANT_LESSONS.md` | OK |
| Immich operations | `workbench/docs/brain-lessons/IMMICH_OPERATIONS_LESSONS.md` | OK |
| Immich backup | `workbench/docs/brain-lessons/IMMICH_BACKUP_RESTORE.md` | OK |
| VM lessons | `workbench/docs/brain-lessons/VM_INFRA_LESSONS.md` | OK |
| Vaultwarden | `workbench/docs/brain-lessons/VAULTWARDEN_HOME_RUNBOOK.md` | OK |
| Pi-hole | `workbench/docs/brain-lessons/PIHOLE_HOME_LESSONS.md` | OK |
| Backup governance | `spine/docs/governance/BACKUP_GOVERNANCE.md` | Compare vzdump details |
| Reboot health gate | `spine/docs/governance/REBOOT_HEALTH_GATE.md` | Compare STOP conditions |
| Secrets policy | `spine/docs/governance/SECRETS_POLICY.md` | OK |
| Network policies | `spine/docs/governance/NETWORK_POLICIES.md` | OK |
| DR runbook | `spine/docs/governance/DR_RUNBOOK.md` | OK |

---

## 5. Extraction Priority Queue

### Tier 1 — Extract Immediately (unique, high-value, no current equivalent)

| # | Action | Source | Target | Est. Size |
|---|--------|--------|--------|-----------|
| 1 | Extract HA dashboard brand guide | `home-assistant/docs/guides/DASHBOARD_STYLE_GUIDE.md` + `configs/dashboards/DASHBOARD_PATTERNS.md` | `workbench/docs/brain-lessons/HA_DASHBOARD_BRAND.md` | ~400 lines |
| 2 | Extract HA device registry | `home-assistant/docs/reference/HA_INFRASTRUCTURE.md` | `workbench/docs/brain-lessons/HA_DEVICE_REGISTRY.md` | ~300 lines |
| 3 | Extract HA runbooks (Zigbee, CalDAV, WoL) | 3 files in `home-assistant/docs/Runbooks/` | `workbench/docs/brain-lessons/HA_RUNBOOKS.md` | ~250 lines |
| 4 | Extract HA CLI cookbook | `home-assistant/docs/reference/CLI_COOKBOOK.md` | `workbench/docs/brain-lessons/HA_CLI_PATTERNS.md` | ~200 lines |
| 5 | Extract finance account registry + category mappings | 2 files in `finance/docs/reference/` | `workbench/docs/brain-lessons/FINANCE_ACCOUNT_TOPOLOGY.md` (merge) | ~400 lines |
| 6 | Extract finance import configs | `finance/docs/reference/REF_IMPORT_CONFIGS.md` | `workbench/docs/brain-lessons/FINANCE_IMPORT_CONFIGS.md` | ~150 lines |
| 7 | Extract finance receipt scanning SOP | `finance/docs/guides/SOP_RECEIPT_SCANNING.md` | `workbench/docs/brain-lessons/FINANCE_RECEIPT_SCANNING.md` | ~120 lines |
| 8 | Extract finance Firefly-Mint sync | `finance/docs/runbooks/RUNBOOK_FIREFLY_MINTOS_SYNC.md` | `workbench/docs/brain-lessons/FINANCE_MINT_SYNC.md` | ~200 lines |
| 9 | Extract media pipeline architecture | `media-stack/docs/reference/REF_MEDIA_PIPELINE.md` | `workbench/docs/brain-lessons/MEDIA_PIPELINE_ARCHITECTURE.md` (merge) | ~300 lines |
| 10 | Extract Tdarr NFS-safe runbook | `media-stack/RUNBOOK_TDARR.md` | `workbench/docs/brain-lessons/MEDIA_TDARR_RUNBOOK.md` | ~150 lines |

### Tier 2 — Extract Soon (high-value, partial coverage exists)

| # | Action | Source | Target |
|---|--------|--------|--------|
| 11 | Merge media critical rules (Rules 5-6) | `media-stack/docs/reference/REF_CRITICAL_RULES.md` | Merge into existing `MEDIA_CRITICAL_RULES.md` |
| 12 | Extract media recovery startup order | `media-stack/RUNBOOK_RECOVER.md` | Merge into existing `MEDIA_RECOVERY_RUNBOOK.md` |
| 13 | Extract Navidrome integration | `media-stack/docs/reference/REF_NAVIDROME.md` | `workbench/docs/brain-lessons/MEDIA_NAVIDROME.md` |
| 14 | Extract Cloudflare governance | `infrastructure/cloudflare/CLOUDFLARE_GOVERNANCE.md` | `workbench/docs/brain-lessons/CLOUDFLARE_GOVERNANCE.md` |
| 15 | Extract incidents log | `infrastructure/docs/INCIDENTS_LOG.md` | `workbench/docs/brain-lessons/INCIDENTS_LOG.md` |
| 16 | Extract service update tiers | `docs/runbooks/SERVICE_UPDATES_GOVERNANCE.md` | `workbench/docs/brain-lessons/SERVICE_UPDATE_TIERS.md` |
| 17 | Extract Immich photo import rules | `immich/docs/reference/PHOTO_IMPORT_RULES.md` | `workbench/docs/brain-lessons/IMMICH_PHOTO_RULES.md` |
| 18 | Extract Dakota embroidery inventory | `infrastructure/home-services/nas/DAKOTA_EMBROIDERY_PROJECT.md` | `workbench/docs/brain-lessons/EMBROIDERY_LIBRARY.md` |

### Tier 3 — Compare and Merge (existing docs may need updates)

| # | Action | Source | Target |
|---|--------|--------|--------|
| 19 | Compare backup governance vzdump details | Legacy `BACKUP_GOVERNANCE.md` | Spine `BACKUP_GOVERNANCE.md` |
| 20 | Compare reboot health gate STOP conditions | Legacy `REBOOT_HEALTH_GATE.md` | Spine `REBOOT_HEALTH_GATE.md` |
| 21 | Compare SSOT registry entries | Legacy `SSOT_REGISTRY.yaml` | Spine `ops/bindings/` coverage |
| 22 | Merge session memory learnings | Legacy `.brain/memory.md` | Spine `docs/brain/memory.md` |
| 23 | Extract MCPJungle recovery | Legacy `mcpjungle/RECOVERY_RUNBOOK.md` | `workbench/docs/brain-lessons/MCPJUNGLE_RECOVERY.md` |

---

## 6. Key Findings

1. **30 files contain unique high-value knowledge** not present anywhere in `code/`. The heaviest concentration is in Home Assistant (7 files) and Finance (5 files).

2. **Dashboard brand knowledge is the largest single gap.** Two legacy files (style guide + patterns) contain ~600 lines of tested CSS, color palettes, icon rules, and copy-paste templates with no equivalent in current repos.

3. **Finance account/category data is business-critical.** The account registry (17 accounts with IDs) and category mapping (QB codes, 27 vendor patterns, tax line mappings) would take days to reconstruct from bank statements and QuickBooks.

4. **Media stack has 6 missing runbooks/references** covering Tdarr safety, recovery procedures, pipeline architecture, download architecture, Navidrome, and critical production rules.

5. **Infrastructure governance gaps** include service update tiers (5-level schedule), Cloudflare dual-auth patterns with zone IDs, and a production incidents log with root cause analysis.

6. **99.8% of legacy files are DROP** (14,606 mint-os source code + ~985 superseded/archived docs). Only 47 files (30 P0 + 17 P1) warrant extraction action.

---

*End of L3 Domain Docs Diff*
