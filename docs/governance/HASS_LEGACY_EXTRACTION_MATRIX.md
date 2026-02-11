---
status: proposed
owner: "@ronny"
last_verified: 2026-02-11
scope: hass-legacy-extraction-matrix
parent_loop: LOOP-HASS-SSOT-AUTOGRADE-20260210
legacy_commit: 1ea9dfa91f4cf5afbd56a1a946f0a733d3bd785c
---

# Home Assistant Legacy Extraction Matrix

> Audit of legacy `ronny-ops/home-assistant/` content vs spine coverage.
> Purpose: quantify what is lost if legacy source disappears, and decide what to extract.
> Evidence for LOOP-HASS-SSOT-AUTOGRADE-20260210 Phase P0.

---

## 1. Loss-If-Deleted Report (Severity-Ranked)

### CRITICAL (operational knowledge lost, not reconstructable from spine)

| Legacy Artifact | What Would Be Lost | Spine Coverage |
|---|---|---|
| `configs/automations.yaml` | 14 production automations with entity IDs, Zigbee IEEE addresses, Jinja2 templates, critical `not_from` fix history | **NONE** in spine (only REF_AUTOMATIONS name/date list in legacy) |
| `configs/configuration.yaml` | Full HA config: dashboard registrations, input_datetime helpers, chore tracker, counter, http/trusted_proxies, lovelace mode, packages, themes | **NONE** in spine |
| `HOME_ASSISTANT_CONTEXT.md` | Master operational context: CLI protocols, SSH access patterns, MCP tools, HACS inventory (12 integrations + 35 cards), API vs Supervisor token distinction, known fixes | **NONE** in spine (spine has infra-level only) |
| `docs/Runbooks/ZIGBEE_RECOVERY.md` | Zigbee IP change recovery: options.json docker injection, SLZB-06 mode config, split-brain fix | **NONE** in spine |
| `docs/Runbooks/RUNBOOK_CALDAV_APPLE.md` | iCloud CalDAV recovery: app-specific password procedure, entity names, HACS dependencies, dashboard wiring | **NONE** in spine |
| `scripts/backup-ha.sh` | HA CLI backup script (creates backup via `ha backups new`, syncs to NAS, cleanup) | **NONE** in spine (spine tracks backup *strategy* but not the script) |
| `scripts/backup/sync-ha-offsite.sh` | Offsite sync: HA SSH addon -> MacBook staging -> Synology NAS, receipted | **NONE** in spine |

### HIGH (significant operational value, partially reconstructable)

| Legacy Artifact | What Would Be Lost | Spine Coverage |
|---|---|---|
| `configs/zigbee2mqtt/configuration.yaml` | Z2M config (coordinator socket, MQTT settings, device config) | Spine has coordinator IPs in MINILAB_SSOT but not Z2M config |
| `configs/dashboards/*.yaml` (11 files) | All dashboard YAML: command-center (8 views), room dashboards, phone dashboards | **NONE** in spine (these are HA app config, not infra) |
| `configs/packages/streamdeck.yaml` | Stream Deck HA package (helpers, scripts for button actions) | **NONE** in spine |
| `docs/reference/REF_INTEGRATIONS.md` | API-extracted integration inventory (60 entries with domain/title/state) | **NONE** in spine |
| `docs/reference/REF_HELPERS.md` | Helper entity inventory (9 input_booleans/selects/datetimes) | **NONE** in spine |
| `docs/reference/REF_AUTOMATIONS.md` | Automation name/state/last-triggered snapshot | **NONE** in spine |
| `data/ha_entity_registry.json` | Full entity registry dump | **NONE** in spine |
| `data/area_assignments.json` | Area-to-entity mapping | **NONE** in spine |
| `scripts/ha-cli.sh` + `scripts/ha-cli/ha-cli` | CLI wrapper for HA API operations (entity list/rename/get, service call, health) | **NONE** in spine |
| `infrastructure/mcpjungle/servers/home-assistant/` | MCP server source (TypeScript, 4 tools: states/state/service/history) | **NONE** in spine (spine references MCP but doesn't host the source) |
| `infrastructure/dotfiles/macbook/launchd/com.ronny.ha-offsite-sync.plist` | macOS launchd schedule for weekly HA offsite sync (Sunday 04:30) | **NONE** in spine |

### MEDIUM (useful reference, reconstructable with effort)

| Legacy Artifact | What Would Be Lost | Spine Coverage |
|---|---|---|
| `docs/audits/2026-01-11-ZIGBEE-AUDIT.md` | Zigbee device audit post-SLZB-06M migration | Spine has device list in MINILAB_SSOT (6 devices) |
| `docs/audits/HA_INFRASTRUCTURE_AUDIT.md` | Detailed HA infra audit | Spine MINILAB_SSOT covers infra baseline |
| `docs/plans/*.md` (9 files) | Dashboard/radio/calendar/purifier planning docs | Historical planning, not operational |
| `docs/guides/DASHBOARD_STYLE_GUIDE.md` | Glass morphism styling rules, color palette, HACS card usage | Aesthetic reference only |
| `docs/reference/CLI_COOKBOOK.md` | Proven CLI patterns for HA operations | Reconstructable from HA docs + API |
| `docs/reference/REF_BUTTONS.md` | Zigbee button reference (IDs, battery, last seen) | Partially in MINILAB_SSOT device list |
| `docs/reference/NETWORK_MAP.md` | HA-centric network topology | Covered by MINILAB_SSOT + DEVICE_IDENTITY_SSOT |
| `docs/devices/DEVICES.md` + `STREAM_DECK.md` | Device inventory + Stream Deck config | Partially covered |
| `scripts/ha-entity-*.py` (4 scripts) | Entity rename/delete/assign-area Python scripts | Reconstructable from HA API docs |
| `scripts/ha-health-check.sh` | Health check script | Reconstructable |
| `configs/themes/ios-dark.yaml` | Custom theme | Aesthetic, reconstructable |

### LOW (archive/historical, minimal operational impact)

| Legacy Artifact | What Would Be Lost | Spine Coverage |
|---|---|---|
| `.archive/docs-2026-01-01/*` | Dec 2025 entity audit, Stream Deck plans, hardware recs | Historical snapshot |
| `.archive/docs-archive-pre-2026/*` | Pre-2026 session logs, dashboard plans, camera workstreams | Historical |
| `docs/sessions/*.md` (20+ files) | Session handoff logs from Jan 2026 | Historical session context |
| `docs/issues/ISSUE_20260106_CONNECTIVITY.md` | One-time connectivity troubleshooting | Resolved issue |
| `docs/reference/REF_UNAVAILABLE.md` | Unavailable entity snapshot | Point-in-time data |
| `docs/reference/ROADMAP.md` | Feature roadmap | Planning doc |
| `BACKUP.md` | Legacy backup doc (references old rsync path) | **Superseded** by spine HOME_BACKUP_STRATEGY |
| `configs/customize_hidden_entities.yaml` | Hidden entity customization | HA app config |
| `configs/zigbee_current.yaml` / `zigbee2mqtt_fixed.yaml` | Old Zigbee config snapshots | Historical |

---

## 2. Coverage Matrix: Spine vs Legacy

| Category | Spine Coverage | Legacy Source | Gap |
|---|---|---|---|
| **VM Identity (IP, RAM, disk)** | MINILAB_SSOT (full) | HOME.md, HOME_INFRASTRUCTURE_AUDIT.md | None |
| **Network topology** | MINILAB_SSOT + DEVICE_IDENTITY_SSOT | NETWORK_MAP.md, HOME.md | None |
| **SSH connectivity** | ssh.targets.yaml (ha: hassio@100.67.120.1) | HOME_ASSISTANT_CONTEXT.md | None |
| **Backup strategy** | HOME_BACKUP_STRATEGY.md + backup.inventory.yaml | BACKUP.md, backup-ha.sh, sync-ha-offsite.sh | **Scripts missing from spine** |
| **Secrets project** | secrets.inventory.yaml (project registered) | HOME_ASSISTANT_CONTEXT.md (token paths) | **Namespace mapping missing** |
| **Radio coordinators** | MINILAB_SSOT (IPs, models, protocols) | HOME_ASSISTANT_CONTEXT.md (firmware, MAC, modes) | **Firmware/MAC/mode detail missing** |
| **Integration inventory** | None | REF_INTEGRATIONS.md (60 entries) | **Full gap** |
| **Automation inventory** | None | automations.yaml (14), REF_AUTOMATIONS.md | **Full gap** |
| **Entity/helper inventory** | None | REF_HELPERS.md, entity_registry.json | **Full gap** |
| **Dashboard config** | None | 11 YAML files + style guide | **Full gap** (app-level, not infra) |
| **Recovery runbooks** | DR_RUNBOOK.md (stub: "HA down if proxmox-home offline") | ZIGBEE_RECOVERY.md, RUNBOOK_CALDAV_APPLE.md, HA_RESYNC.md | **App-level recovery missing** |
| **CLI/API tools** | None | ha-cli.sh, ha-entity-*.py, ha-health-check.sh | **Full gap** |
| **MCP server** | None | mcpjungle/servers/home-assistant/ (TypeScript) | **Full gap** |
| **HACS inventory** | None | HOME_ASSISTANT_CONTEXT.md (12+35 entries) | **Full gap** |
| **Known fixes/gotchas** | None | HOME_ASSISTANT_CONTEXT.md (5 documented fixes) | **Full gap** |
| **Offsite sync schedule** | None | launchd plist (Sunday 04:30) | **Full gap** |
| **Service registry** | OUT OF SCOPE (per LOOP-HOME-SERVICE-REGISTRY-SCOPE-DECISION) | N/A | By design |
| **Health probes** | OUT OF SCOPE (per scope decision) | N/A | By design |

---

## 3. Extraction Decision Matrix

| Legacy Artifact | Decision | Target Spine Path | Rationale |
|---|---|---|---|
| **HOME_ASSISTANT_CONTEXT.md** (operational context) | **extract_now** | `docs/governance/HASS_OPERATIONAL_RUNBOOK.md` | Core operational knowledge: CLI/API access, known fixes, HACS inventory, token management. Irreplaceable without live system audit. |
| **automations.yaml** | **extract_now** | `docs/governance/HASS_OPERATIONAL_RUNBOOK.md` (summary table) | Automation names, entity mappings, and critical `not_from` fix must be documented. Raw YAML stays in HA; spine gets the fact model. |
| **REF_INTEGRATIONS.md** + **REF_HELPERS.md** + **REF_AUTOMATIONS.md** | **extract_now** | `docs/governance/HASS_OPERATIONAL_RUNBOOK.md` (integration/helper/automation inventories) | These are the API field mappings needed for `ha.ssot.propose`. Defines what facts the capability must fetch. |
| **ZIGBEE_RECOVERY.md** | **extract_now** | `docs/governance/HASS_OPERATIONAL_RUNBOOK.md` (Zigbee recovery section) | Only source of docker-injection recovery procedure. Not reconstructable without trial-and-error. |
| **RUNBOOK_CALDAV_APPLE.md** | **extract_now** | `docs/governance/HASS_OPERATIONAL_RUNBOOK.md` (CalDAV recovery section) | Contains credential paths and app-specific password regeneration procedure. |
| **backup-ha.sh** + **sync-ha-offsite.sh** | **extract_now** | `docs/governance/HASS_OPERATIONAL_RUNBOOK.md` (backup/restore section) | Scripts document the actual backup procedure. Spine HOME_BACKUP_STRATEGY covers strategy but not mechanics. |
| **launchd plist** | **extract_now** | `docs/governance/HASS_OPERATIONAL_RUNBOOK.md` (schedule reference) | Documents the macOS cron-equivalent schedule for offsite sync. |
| **MCP server source** | **defer** | N/A (stays in workbench or is rebuilt) | MCP server is a runtime tool, not governance. Will be rebuilt when MCP integration is formalized in spine. |
| **ha-cli.sh** + utility scripts | **defer** | N/A | CLI tools are runtime utilities. May be ported to workbench later. Not governance-critical. |
| **Dashboard YAML files** | **reject** | N/A | App-level UI config. Managed by HA directly. Spine should not track dashboard YAML. |
| **Session logs** (20+ files) | **reject** | N/A | Historical, no ongoing operational value. |
| **Archive content** (.archive/) | **reject** | N/A | Already marked archived in legacy. Historical only. |
| **Plans** (docs/plans/) | **reject** | N/A | Planning documents, not operational. |
| **Themes** (ios-dark.yaml) | **reject** | N/A | Aesthetic. Managed in HA. |
| **BACKUP.md** | **superseded** | HOME_BACKUP_STRATEGY.md already exists | Spine doc is authoritative and more current. |
| **HOME.md** (location doc) | **superseded** | MINILAB_SSOT.md already exists | Spine doc is authoritative. |
| **home-services/README.md** | **superseded** | MINILAB_SSOT.md + DEVICE_IDENTITY_SSOT.md | Spine docs are authoritative and more current. |
| **HOME_INFRASTRUCTURE_AUDIT.md** | **superseded** | MINILAB_SSOT.md | Dec 2025 audit fully absorbed into spine SSOT. |
| **configs/configuration.yaml** | **defer** | N/A | HA app config. Spine should document *what* it contains (in runbook), not host the raw file. |
| **data/ha_entity_registry.json** + **area_assignments.json** | **defer** | N/A | Raw API dumps. Will be generated by `ha.ssot.propose` capability. |

---

## 4. Proposed Minimum Spine Doc Set

### New: `docs/governance/HASS_OPERATIONAL_RUNBOOK.md`

One authoritative doc combining operational knowledge from 7+ legacy sources:

**Sections:**
1. **Quick Reference** - Host IPs, access URLs, API token path, SSH access
2. **Integration Inventory Policy** - How integrations are tracked (API extraction, not manual), current count and key entries
3. **Automation Inventory** - Current automation list with entity mappings and critical fix notes
4. **Helper/Input Entity Inventory** - Input helpers used by chore tracker, Stream Deck, house mode
5. **HACS Inventory** - Custom integrations (12) and Lovelace cards (35) with purpose tags
6. **Radio Coordinator Details** - Firmware versions, MAC addresses, mode configuration (extends MINILAB_SSOT)
7. **Backup & Restore Procedure** - HA CLI backup, offsite sync mechanics, restore steps, schedule
8. **Recovery Runbooks** - Zigbee IP change recovery, CalDAV rebuild, Tailscale userspace fix
9. **Known Fixes & Gotchas** - `not_from` automation guard, token parsing, login notification suppression
10. **API Field Mapping** - Fields needed by `ha.ssot.propose` (entities, automations, helpers, integrations)

### No Other New Docs Required

- Infrastructure is fully covered by existing MINILAB_SSOT
- Backup strategy is covered by HOME_BACKUP_STRATEGY.md
- Device identity is covered by DEVICE_IDENTITY_SSOT.md
- SSH target is covered by ssh.targets.yaml

---

## 5. Summary Statistics

| Metric | Count |
|---|---|
| Total legacy HA files inventoried | 95 |
| Non-archive operational files | 61 |
| **extract_now** | 7 artifacts -> 1 spine doc |
| **defer** | 5 artifacts (runtime tools, MCP server, raw configs) |
| **reject** | 5 categories (~40 files: sessions, plans, archive, themes, dashboards) |
| **superseded** | 4 artifacts (already covered by spine SSOTs) |
| Critical knowledge at risk | 7 items (automations, config, context, runbooks, backup scripts) |
| Irreplaceable if deleted | 3 items (automation entity mappings + fix history, Zigbee recovery procedure, CalDAV credentials procedure) |
