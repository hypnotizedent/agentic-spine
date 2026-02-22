---
status: inbox
owner: "@ronny"
created: 2026-02-17
scope: legacy-domain-docs-diff
loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
lane: LANE-C (OpenCode)
---

# L3 Domain Docs Diff: Legacy vs Current

> **Source:** `/Users/ronnyworks/ronny-ops` (legacy)
> **Target:** `/Users/ronnyworks/code/workbench/docs/**` + `/Users/ronnyworks/code/agentic-spine/docs/**`
> **Priority:** Missing high-value operational knowledge

---

## Executive Summary

| Category | Count | Priority |
|----------|-------|----------|
| MISSING - Domain Context Files | 5 | P1 |
| MISSING - Backup Runbooks | 5 | P1 |
| MISSING - Mint OS Operational Knowledge | 4 | P1 |
| MISSING - Infrastructure SSOTs | 3 | P1 |
| MISSING - Session Handoffs | 50+ | P2 |
| MISSING - Reference Docs | 20+ | P2 |
| DRIFT - Capability Mapping Gaps | 4 | P2 |

---

## P1: MISSING Domain Context Files

These are critical operational entrypoints that exist in legacy but NOT in current spine/workbench:

### 1. `immich/IMMICH_CONTEXT.md` (204 lines)

**Legacy Location:** `/Users/ronnyworks/ronny-ops/immich/IMMICH_CONTEXT.md`

**High-Value Content:**
- Cross-pillar protocols (secrets, backups)
- Backup status with script paths
- Quick access URLs (Tailscale/LAN)
- User accounts and API keys mapping
- Infrastructure specs (VM ID, RAM, CPU, Docker version, Immich version)
- Container health status
- Import status tracking (rsync progress)
- THE RULE for photo deduplication
- Known camera issues (clock resets)
- Secrets (Infisical project ID)
- Key files reference

**Current State:** Spine has `docs/governance/domains/immich/CAPABILITIES.md` (17 lines) - **MISSING operational context**

**Recommendation:** Extract `IMMICH_CONTEXT.md` → `workbench/docs/brain-lessons/IMMICH_OPERATIONS_CONTEXT.md`

---

### 2. `mint-os/CLAUDE.md` (261 lines) + `mint-os/AGENTS_START_HERE.md` (564 lines)

**Legacy Locations:**
- `/Users/ronnyworks/ronny-ops/mint-os/CLAUDE.md`
- `/Users/ronnyworks/ronny-ops/mint-os/AGENTS_START_HERE.md`

**High-Value Content:**
- THE 60-SECOND SUMMARY (43,000 orders from Printavo)
- THE GOLDEN RULE: Printavo schema wins
- THE FOUR THINGS THAT BREAK EVERY SESSION:
  1. Manual deployment (never do this)
  2. Wrong column names (style_description, total_quantity, etc.)
  3. Missing imprint junction entries
  4. Wrong artwork table (4 tables, use right one)
- Visual ID format (1-13999 legacy, 30000+ new)
- Status values (dual columns)
- Complete flow diagram
- DO NOT list (critical prohibitions)
- RAG integration (`mint ask`)
- API token generation workflow
- Sources of truth table
- Session checklists

**Current State:** Spine has `docs/governance/domains/mint/CAPABILITIES.md` (20 lines) - **MISSING 825 lines of operational knowledge**

**Recommendation:** Extract combined context → `workbench/docs/brain-lessons/MINT_OPERATIONS_MASTER.md`

---

### 3. `home-assistant/HOME_ASSISTANT_CONTEXT.md` (393 lines)

**Legacy Location:** `/Users/ronnyworks/ronny-ops/home-assistant/HOME_ASSISTANT_CONTEXT.md`

**High-Value Content:**
- Radio coordinators inventory (Zigbee/Matter/Z-Wave)
  - SLZB-06 (10.0.0.51)
  - SLZB-06MU (10.0.0.52)
  - TubesZB Z-Wave PoE
- CLI & API access protocols (Supervisor vs Core)
- SSH access requirements (Protection Mode OFF)
- Troubleshooting "401 Unauthorized"
- Device inventory (as of Jan 20, 2026)
- MCP tools available
- Dashboard info (8 views, integrations, color palette)
- HACS inventory (12 integrations, 35 cards)
- Known issues & fixes:
  - "Login attempt failed" notifications
  - Token shell parsing errors
  - Lights toggle on HA restart (FIXED)
  - Tailscale userspace networking bug (FIXED)
- CLI tools (ha-cli.sh, ha-entity-rename.py)
- Key files reference

**Current State:** Spine has `docs/governance/domains/home-assistant/CAPABILITIES.md` (52 lines) + some HASS docs in `domains/home-assistant/` but **MISSING operational context**

**Recommendation:** Extract → `workbench/docs/brain-lessons/HASS_OPERATIONS_CONTEXT.md`

---

### 4. `media-stack/MEDIA_STACK_CONTEXT.md` (182 lines)

**Legacy Location:** `/Users/ronnyworks/ronny-ops/media-stack/MEDIA_STACK_CONTEXT.md`

**High-Value Content:**
- Cross-pillar protocols
- Reference documents table
- Current status dashboard (24 containers)
- Quick commands (health check, secrets, TRaSH sync, Tdarr)
- MCP tools (21 active)
- Day-to-day operations
- Critical workflows
- Agent handoff history with dates and completion status
- Infrastructure status (VM disk usage)
- Verification commands

**Current State:** Spine has `docs/governance/domains/media/CAPABILITIES.md` (23 lines) - **MISSING operational context**

**Recommendation:** Extract → `workbench/docs/brain-lessons/MEDIA_OPERATIONS_CONTEXT.md`

---

### 5. `finance/README.md` + `finance/BACKUP.md`

**Legacy Locations:**
- `/Users/ronnyworks/ronny-ops/finance/README.md`
- `/Users/ronnyworks/ronny-ops/finance/BACKUP.md`

**High-Value Content:**
- Component URLs (Firefly III, Paperless-ngx, Ghostfolio)
- Quick commands (health check, container status, secrets)
- Deployment commands
- Backup scripts with full implementation
- Restore procedures

**Current State:** Spine has `docs/governance/domains/finance/CAPABILITIES.md` (20 lines) - **MISSING operational context**

**Recommendation:** Extract → `workbench/docs/brain-lessons/FINANCE_OPERATIONS_CONTEXT.md`

---

## P1: MISSING Backup Runbooks

All legacy pillars have `BACKUP.md` files with full script implementations:

| Legacy File | Lines | Content |
|-------------|-------|---------|
| `immich/BACKUP.md` | 235 | PostgreSQL + photo library backup scripts |
| `finance/BACKUP.md` | 167 | Firefly III + Ghostfolio backup scripts |
| `home-assistant/BACKUP.md` | 153 | HA config backup script |
| `media-stack/BACKUP.md` | 263 | 18 container configs backup |
| `infrastructure/BACKUP.md` | - | Cross-pillar backup governance |

**Common Pattern in Each:**
- What gets backed up (table with paths, sizes, methods, destinations, frequencies)
- What does NOT get backed up (with reasons)
- Full script implementations (bash scripts)
- Verification commands
- Restore procedures
- Supersedes list (old scripts to delete)
- Cron entries
- Data paths reference

**Current State:** Spine has `docs/governance/BACKUP_GOVERNANCE.md` (high-level policy) + `domains/backup/BACKUP_GOVERNANCE.md` + `domains/backup/BACKUP_CALENDAR.md` but **MISSING domain-specific backup scripts and restore procedures**

**Recommendation:** Extract each pillar's `BACKUP.md` → `workbench/docs/brain-lessons/{DOMAIN}_BACKUP_RESTORE.md`

---

## P1: MISSING Mint OS Operational Knowledge

Critical operational patterns documented in legacy mint-os:

### 1. Column Name Mappings (`docs/SCHEMA_TRUTH.md`)

```
| YOU MIGHT WRITE | ACTUALLY USE | TABLE |
|-----------------|--------------|-------|
| description | style_description | line_items |
| quantity | total_quantity | line_items |
| unit_price | unit_cost | line_items |
| total_price | total_cost | line_items |
```

**Recommendation:** Extract to `workbench/docs/brain-lessons/MINT_SCHEMA_GOTCHAS.md`

### 2. Artwork Table Selection

```
| FILE TYPE | CORRECT TABLE |
|-----------|---------------|
| Customer sent us a file | customer_artwork |
| Product photo (SanMar CDN) | line_item_mockups |
| Decoration preview (stitch PNG) | imprint_mockups |
| Machine files (DST, EMB) | production_files |
```

**Recommendation:** Extract to `workbench/docs/brain-lessons/MINT_ARTWORK_TABLES.md`

### 3. DO NOT List (Critical Prohibitions)

```
- DO NOT create a `quotes` table (doesn't exist, by design)
- DO NOT use `sizes` JSONB on line_items (use size_s, size_m, etc.)
- DO NOT deploy frontend without Cloudflare cache purge
- DO NOT rsync/scp files to docker-host (use git push)
```

**Recommendation:** Extract to `workbench/docs/brain-lessons/MINT_DO_NOT_LIST.md`

### 4. Deployment Governance

Legacy has `docs/DEPLOYMENT_GOVERNANCE.md` with:
- GitHub Actions deployment flow
- Manual deployment prohibition
- Cloudflare cache purge requirement

**Recommendation:** Extract to `workbench/docs/brain-lessons/MINT_DEPLOY_GOVERNANCE.md`

---

## P1: MISSING Infrastructure SSOTs

### 1. `infrastructure/SERVICE_REGISTRY.md` (616 lines)

**Legacy Location:** `/Users/ronnyworks/ronny-ops/infrastructure/SERVICE_REGISTRY.md`

**Content:**
- Machine-readable YAML version reference
- Quick reference table (service → host → IP → port)
- Level 1: Physical hosts (MacBook, Beelink, Dell R730XD)
- Level 2: Services by host (detailed)
- Level 3: Network topology (ASCII diagram)
- Health issues table
- Drift to clean up
- Service placement rationale
- RAG operations runbook
- Changelog

**Current State:** Spine has `docs/governance/SERVICE_REGISTRY.yaml` (machine-readable) but **MISSING human-readable operational context**

**Recommendation:** Verify alignment or extract missing context

### 2. `infrastructure/RAG_ARCHITECTURE.md` (149 lines)

**Legacy Location:** `/Users/ronnyworks/ronny-ops/infrastructure/RAG_ARCHITECTURE.md`

**Content:**
- Architecture diagram
- Workspace definitions (ronny-ops, mint-os, media-stack, etc.)
- CLI interface (auto-scope, explicit scope)
- Indexing strategy
- Query routing
- Implementation phases
- Current state table
- Key files

**Current State:** Spine has `docs/governance/RAG_INDEXING_RULES.md` but **MISSING architecture overview**

**Recommendation:** Extract to `spine/docs/governance/RAG_ARCHITECTURE.md`

### 3. `docs/governance/DEVICE_IDENTITY_SSOT.md` (292 lines)

**Legacy Location:** `/Users/ronnyworks/ronny-ops/docs/governance/DEVICE_IDENTITY_SSOT.md`

**Content:**
- Naming rules (Tailscale hostnames, Proxmox VMID ranges, container naming)
- Device registry:
  - Tier 1: Critical infrastructure (4 devices)
  - Tier 2: Production services (3 devices)
  - Tier 3: Home services (5 devices)
  - Tier 4: Endpoints (4 devices)
- Verification commands
- Stream Deck integration
- Known unknowns table
- Change control procedures
- Decommissioned devices
- Quick reference card

**Current State:** Spine has `docs/governance/DEVICE_IDENTITY_SSOT.md` (needs verification for alignment)

**Recommendation:** Verify alignment with legacy

---

## P2: MISSING Session Handoffs

Legacy contains 50+ session handoff documents with operational history:

| Pillar | Session Docs | Location |
|--------|--------------|----------|
| home-assistant | 25+ | `home-assistant/docs/sessions/` |
| media-stack | 30+ | `media-stack/docs/sessions/` |
| infrastructure | 15+ | `infrastructure/docs/sessions/` |
| mint-os | Multiple | `mint-os/docs/sessions/` |

**Pattern:** `YYYY-MM-DD-SESSION-HANDOFF.md` or `YYYY-MM-DD-TOPIC.md`

**Value:** Historical context for recurring issues, fix patterns, architectural decisions

**Recommendation:** Extract index of key handoffs → `workbench/docs/legacy/SESSION_HANDOFF_INDEX.md`

---

## P2: MISSING Reference Docs

### Media Stack Reference Docs (100+ files)

| File | Content |
|------|---------|
| `docs/reference/REF_CRITICAL_RULES.md` | 5 rules to prevent VM crashes |
| `docs/reference/REF_SERVICES_MATRIX.md` | 24 containers with ports/URLs |
| `docs/reference/REF_DOWNLOAD_ARCHITECTURE.md` | Shop vs Home downloader philosophy |
| `docs/reference/REF_QUALITY_PROFILES.md` | Recyclarr, profiles, BR-DISK rules |
| `docs/reference/REF_SECRETS.md` | Infisical key mapping |
| `docs/troubleshooting/TRB_MEDIA_STACK.md` | Troubleshooting guide |

### Home Assistant Reference Docs

| File | Content |
|------|---------|
| `docs/Runbooks/RUNBOOK_TV_WAKE_ON_LAN.md` | TV Wake-on-LAN setup |
| `docs/Runbooks/ZIGBEE_RECOVERY.md` | Zigbee recovery procedures |
| `docs/Runbooks/RUNBOOK_CALDAV_APPLE.md` | iCloud calendar setup/recovery |
| `docs/Runbooks/DEPLOY_CHECKLIST.md` | Deployment procedures |
| `docs/guides/DASHBOARD_STYLE_GUIDE.md` | HACS rules, colors, icons |

### Infrastructure Reference Docs

| File | Content |
|------|---------|
| `docs/runbooks/AGENT_DISPATCH_PIPELINE.md` | Agent dispatch procedures |
| `docs/runbooks/SERVICE_UPDATES_GOVERNANCE.md` | Service update procedures |
| `docs/governance/SCRIPTS_REGISTRY.md` | Script inventory |
| `docs/governance/SECRETS_POLICY.md` | Secrets governance |

**Recommendation:** Extract index → `workbench/docs/legacy/REFERENCE_DOCS_INDEX.md`

---

## P2: DRIFT - Capability Mapping Gaps

Spine CAPABILITIES.md files are auto-generated stubs. Legacy has rich operational context that should inform capability implementations:

| Domain | Spine Caps | Legacy Context | Gap |
|--------|------------|----------------|-----|
| mint | 5 caps (20 lines) | 825 lines operational | No operational guidance |
| immich | 2 caps (17 lines) | 204 lines context | No operational guidance |
| home-assistant | 39 caps (52 lines) | 393 lines context | Partial coverage |
| media | 8 caps (23 lines) | 182 lines context | No operational guidance |
| finance | 5 caps (20 lines) | 212 lines context | No operational guidance |

**Recommendation:** Each CAPABILITIES.md should link to operational context in workbench

---

## P3: Files Verified as Extracted/Aligned

| Legacy File | Current Location | Status |
|-------------|------------------|--------|
| `infrastructure/SERVICE_REGISTRY.yaml` | `spine/docs/governance/SERVICE_REGISTRY.yaml` | ✅ Aligned |
| `docs/governance/DEVICE_IDENTITY_SSOT.md` | `spine/docs/governance/DEVICE_IDENTITY_SSOT.md` | ✅ Aligned |
| `docs/governance/BACKUP_GOVERNANCE.md` | `spine/docs/governance/BACKUP_GOVERNANCE.md` | ✅ Aligned |
| `docs/backups/BACKUPS_LAW_OF_LAND.md` | Merged into spine backup governance | ✅ Aligned |
| Finance brain-lessons | `workbench/docs/brain-lessons/FINANCE_*.md` | ✅ Extracted |
| Immich brain-lessons | `workbench/docs/brain-lessons/IMMICH_*.md` | ✅ Extracted |
| HA brain-lessons | `workbench/docs/brain-lessons/HOME_ASSISTANT_LESSONS.md` | ✅ Extracted |
| Shop domain docs | `spine/docs/governance/domains/shop/*` | ✅ Extracted |
| Network domain docs | `spine/docs/governance/domains/network/*` | ✅ Extracted |
| Backup domain docs | `spine/docs/governance/domains/backup/*` | ✅ Extracted |

---

## Recommended Extraction Order

### Phase 1: Domain Context Files (P1)
1. `IMMICH_CONTEXT.md` → `workbench/docs/brain-lessons/IMMICH_OPERATIONS_CONTEXT.md`
2. `MINT_OS_CONTEXT.md` + `AGENTS_START_HERE.md` → `workbench/docs/brain-lessons/MINT_OPERATIONS_MASTER.md`
3. `HOME_ASSISTANT_CONTEXT.md` → `workbench/docs/brain-lessons/HASS_OPERATIONS_CONTEXT.md`
4. `MEDIA_STACK_CONTEXT.md` → `workbench/docs/brain-lessons/MEDIA_OPERATIONS_CONTEXT.md`
5. `FINANCE_STACK_MASTER.md` → `workbench/docs/brain-lessons/FINANCE_OPERATIONS_CONTEXT.md`

### Phase 2: Backup Scripts (P1)
1. Extract all `BACKUP.md` files → `workbench/docs/brain-lessons/{DOMAIN}_BACKUP_RESTORE.md`
2. Verify scripts exist in workbench or create

### Phase 3: Reference Docs (P2)
1. Extract media stack reference docs → `workbench/docs/legacy/reference/media/`
2. Extract HA reference docs → `workbench/docs/legacy/reference/home-assistant/`
3. Extract infrastructure reference docs → `workbench/docs/legacy/reference/infrastructure/`

### Phase 4: Session Index (P2)
1. Create `workbench/docs/legacy/SESSION_HANDOFF_INDEX.md` with key handoffs

---

## Appendix: Legacy File Counts by Pillar

| Pillar | MD Files | Key Files |
|--------|----------|-----------|
| immich | 13 | IMMICH_CONTEXT.md, BACKUP.md |
| mint-os | 34+ | CLAUDE.md, AGENTS_START_HERE.md, INFRASTRUCTURE_MAP.md |
| home-assistant | 100+ | HOME_ASSISTANT_CONTEXT.md, BACKUP.md, docs/sessions/* |
| media-stack | 100+ | MEDIA_STACK_CONTEXT.md, BACKUP.md, docs/sessions/* |
| finance | 15+ | README.md, BACKUP.md |
| infrastructure | 100+ | SERVICE_REGISTRY.md, RAG_ARCHITECTURE.md, docs/** |
| docs/governance | 30+ | DEVICE_IDENTITY_SSOT.md, SCRIPTS_REGISTRY.md |
| docs/runbooks | 20+ | ARTWORK_FILES/*, RAG/* |
| docs/audits | 10+ | STATE_OF_THE_UNION, BACKUP_AUDIT |

---

*Generated by LANE-C (OpenCode) for LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217*
*Timestamp: 2026-02-17*
