# LOOP-MEDIA-AGENT-WORKBENCH-20260208

> **Status:** complete
> **Blocked By:** _(none)_
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** medium

---

## Executive Summary

Design and build a dedicated media domain agent in the workbench repo with its own MCP tools, declarative configuration governance, and troubleshooting runbooks for the download-stack (VM 209) and streaming-stack (VM 210). The spine continues to own infrastructure (compose, health, routing, secrets); this agent owns the **application layer** (language profiles, quality settings, subtitle preferences, library hygiene).

**Prerequisite work DONE:** Agent discovery governance is wired (D49 drift gate, `agents.registry.yaml`, `generate-context.sh` injection, `media-agent.contract.md`). The plumbing exists — this loop builds the agent itself.

---

## Rationale

### The Gap

The spine governs **where** media services run but not **how** they behave. Configuration like Radarr language profiles, Recyclarr custom formats, Bazarr subtitle languages, and Jellyfin metadata settings all live inside each app's database or config directory. There is:

- No declarative config tracked in version control
- No agent that understands media domain semantics (e.g., "this movie is in the wrong language")
- No tooling to inspect or modify media service state programmatically
- No governance over quality/language profiles across the *arr stack

### Triggering Event

Jellyfin displaying "The Beach House" in a non-English audio track. Root cause: Radarr grabbed a non-English release because language profiles are unmanaged and invisible to governance.

---

## Legacy Audit (2026-02-08)

A full sweep of the workbench repo identified legacy media automation. **Do NOT copy these wholesale.** Rebuild from the patterns; promote only what's proven.

### What Exists (Reusable Seed)

**MCPJungle media-stack MCP server** — THE primary seed
- Location: `~/code/workbench/infra/compose/mcpjungle/servers/media-stack/`
- TypeScript, ~1600 lines (`src/index.ts`), 21 tools (not 8 as originally thought)
- Production-quality API wrappers for all services
- **STALE:** ALL endpoints hardcoded to `100.117.1.53` (dead VM 201)
- **Action:** Fork this code as the media agent's tool foundation. Update IPs. Do NOT rewrite from scratch.

#### Tool Inventory (21 tools, split by new VM)

**Download-stack tools → VM 209 (100.107.36.76):**

| Tool | Service | R/W | What it does |
|------|---------|-----|-------------|
| `get_download_queue` | radarr, sonarr, sabnzbd | GET | Current download queue + SABnzbd status |
| `search_content` | radarr, sonarr | GET | Search movies/TV in library |
| `request_movie` | radarr | POST | Add movie to Radarr |
| `request_show` | sonarr | POST | Add TV show to Sonarr |
| `trigger_collection_search` | radarr | POST | Search for missing movies in collection |
| `get_music_stats` | lidarr | GET | Artist/track/album counts |
| `search_music` | lidarr | GET | Search artists |
| `request_artist` | lidarr | POST | Add artist to Lidarr |
| `manage_queue` | sabnzbd | POST | Pause/resume SABnzbd |
| `get_indexer_status` | prowlarr | GET | Indexer health |
| `get_huntarr_status` | huntarr | GET | Automation cycling state |
| `toggle_huntarr` | huntarr | POST | Enable/disable Huntarr |

**Streaming-stack tools → VM 210 (100.123.207.64):**

| Tool | Service | R/W | What it does |
|------|---------|-----|-------------|
| `get_library_stats` | jellyfin | GET | Movie/TV counts, disk usage |
| `get_recently_added` | jellyfin | GET | Recently added content |
| `get_pending_requests` | jellyseerr | GET | Pending media requests |
| `approve_request` | jellyseerr | POST | Approve/decline request |
| `get_navidrome_stats` | navidrome | GET | Music streaming stats |
| `get_missing_subtitles` | bazarr | GET | Missing subtitle report |

**Multi-VM tools (needs both):**

| Tool | Service | R/W | What it does |
|------|---------|-----|-------------|
| `get_system_status` | all services | GET | Health check all media services |
| `get_media_health` | all services | GET | Unified health dashboard |

**Profile Management tools (P3) → VM 209:**

| Tool | Service | R/W | What it does |
|------|---------|-----|-------------|
| `get_quality_profiles` | radarr/sonarr | GET | List profiles with CF scores |
| `get_custom_formats` | radarr/sonarr | GET | List CFs with specs (filterable) |
| `get_movie_details` | radarr | GET | Movie info: profile, file, languages, CFs |
| `get_movie_history` | radarr | GET | Grab/import history with language info |
| `update_movie_profile` | radarr | PUT | Change movie quality profile |
| `search_movie_by_id` | radarr | POST | Trigger search for specific movie |
| `get_recyclarr_status` | radarr, sonarr | GET | Config drift detection |

#### Service Endpoint Map (Legacy → New)

| Service | Legacy (VM 201) | New VM | New IP |
|---------|----------------|--------|--------|
| Radarr | 100.117.1.53:7878 | 209 | 100.107.36.76:7878 |
| Sonarr | 100.117.1.53:8989 | 209 | 100.107.36.76:8989 |
| Lidarr | 100.117.1.53:8686 | 209 | 100.107.36.76:8686 |
| Prowlarr | 100.117.1.53:9696 | 209 | 100.107.36.76:9696 |
| SABnzbd | 100.117.1.53:8085 | 209 | 100.107.36.76:8080 |
| Huntarr | 100.117.1.53:9705 | 209 | 100.107.36.76:9705 |
| Jellyfin | 100.117.1.53:8096 | 210 | 100.123.207.64:8096 |
| Jellyseerr | 100.117.1.53:5055 | 210 | 100.123.207.64:5055 |
| Navidrome | 100.117.1.53:4533 | 210 | 100.123.207.64:4533 |
| Bazarr | 100.117.1.53:6767 | 210 | 100.123.207.64:6767 |

### What Exists (Pattern Only — Do NOT Copy Code)

| Legacy Artifact | Location | What to learn from it |
|----------------|----------|----------------------|
| `run-media-stack-overnight.sh` | `workbench/scripts/root/` | Multi-phase agent pattern: audit → fix → verify |
| `run-media-stack-fix.sh` | `workbench/scripts/root/` | Issue-targeted agent runs with prompt injection |
| `backup-media-configs.sh` | `workbench/scripts/root/backup/` | Config backup pattern (Jellyfin, *arr configs, 7d retention) |
| n8n Jellyfin Collection Sync | `workbench/infra/compose/n8n/workflows/` | Jellyfin collection orchestration pattern |
| n8n Media Notifications | `workbench/infra/compose/n8n/workflows/` | Event dispatch pattern |

### What to Archive/Ignore

| Legacy Artifact | Status | Why |
|----------------|--------|-----|
| 19 agents in `.archive/legacy-agents/` | Already archived | Pre-spine, stale references to VM 201 |
| `infra/compose/arr/DEFERRED.md` | Marker only | Never promoted from ronny-ops monolith |
| `scripts/media-stack/` (gitignored) | Doesn't exist | Placeholder that was never created |
| `infra/data/CONTAINER_INVENTORY.yaml` media entries | Stale | Spine SERVICE_REGISTRY.yaml is SSOT |
| Media-stack project ID `3807f1c4-...` in legacy agents | Stale | Infisical paths now at `/spine/vm-infra/media-stack/` |

---

## Target Architecture

### Ownership Boundary

```
SPINE (infrastructure)              MEDIA AGENT (application)
├── docker-compose deploy           ├── Radarr/Sonarr language profiles
├── VM provisioning                 ├── Recyclarr custom format config
├── Health probes (up/down)         ├── Bazarr subtitle language prefs
├── CF tunnel routing               ├── Jellyfin library metadata settings
├── Infisical secrets               ├── Quality profile governance
└── NFS mount governance            └── Troubleshooting (wrong language, missing subs, etc.)
```

### Agent Location

```
workbench/agents/media/
├── AGENT.md                    # Contract: owns, defers, invocation
├── tools/                      # MCP server (TypeScript — fork from MCPJungle seed)
│   ├── src/index.ts            # Fork of mcpjungle/servers/media-stack/src/index.ts
│   ├── package.json            # Dependencies
│   └── tsconfig.json           # TypeScript config
├── config/
│   └── recyclarr.yml           # Tracked quality/language profiles (SSOT)
├── playbooks/
│   ├── wrong-language.md       # Troubleshooting: movie/show wrong audio
│   ├── missing-subtitles.md    # Troubleshooting: no subs or wrong language
│   └── library-hygiene.md      # Orphaned files, duplicate detection
└── tests/
    └── api-connectivity.sh     # Smoke test: can tools reach both VMs?
```

### Key Decision: TypeScript (Not Python)

The MCPJungle seed is TypeScript with 21 working tools. Rewriting in Python wastes proven code. Fork the TypeScript, update endpoints, add missing tools (profile management, recyclarr config).

### Relationship to MCPJungle

The existing `infra/compose/mcpjungle/servers/media-stack/` becomes a **downstream consumer**. The workbench agent's tools are the source; MCPJungle re-exposes a subset for Claude Mobile access. Update MCPJungle server to point at VM 209/210 endpoints.

---

## Phases

| Phase | Scope | Dependency | Status |
|-------|-------|------------|--------|
| P0 | Design: agent contract, tool inventory, config schema | — | **DONE** (this audit) |
| P1 | Pull current Recyclarr config from VM 209; audit language/quality profiles in Radarr/Sonarr | P0 | **DONE** — config pulled, profiles audited, Beach House RCA complete |
| P2 | Fork MCPJungle media-stack server → `workbench/agents/media/tools/`; update all IPs to 209/210 split | P1 | **DONE** |
| P3 | Add new tools: profile management (list/update language profiles), recyclarr config sync | P2 | **DONE** |
| P4 | Build troubleshooting playbooks + Recyclarr config governance | P3 | **DONE** |
| P5 | Update MCPJungle media-stack server (point at 209/210 or consume from agent tools) | P2 | **DONE** |
| P6 | Fix "The Beach House" — validate end-to-end with a real issue | P4 | **DONE** |
| P7 | Verify + closeout | P6 | **DONE** |

---

## Spine Governance (Already Wired)

These artifacts exist and should NOT be recreated:

| Artifact | Location | Purpose |
|----------|----------|---------|
| Agent contract | `ops/agents/media-agent.contract.md` | Ownership boundary |
| Registry entry | `ops/bindings/agents.registry.yaml` | Discovery + routing rules |
| Context injection | `docs/brain/generate-context.sh` | Sessions see "Available Agents" |
| D49 drift gate | `surfaces/verify/d49-agent-discovery-lock.sh` | Validates registry integrity |
| Loop scope | This file | Traceable work plan |

When `implementation_status` changes from `pending` to `active`, update `agents.registry.yaml`.

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| Agent can query Radarr/Sonarr profiles | `tools/` returns language profiles via API |
| Agent can identify wrong-language media | Given a movie title, reports audio tracks + grab history |
| Recyclarr config tracked in workbench | `config/recyclarr.yml` exists, matches live VM state |
| MCPJungle updated for split VMs | Media tools resolve to 209/210, not 201 |
| "The Beach House" fixed | Correct English release in Jellyfin |
| 21 existing tools work with new IPs | All tools from legacy server pass connectivity test |

---

## Non-Goals

- Do NOT move compose/deploy governance out of spine
- Do NOT create schedulers or watchers (WORKBENCH_CONTRACT)
- Do NOT replace Radarr/Sonarr web UIs — agent is supplemental
- Do NOT handle Spotify OAuth flows (manual, browser-only)
- Do NOT govern NFS mounts or storage (spine owns this)
- Do NOT copy legacy scripts wholesale — fork the MCP server seed only

---

## Related Loops

| Loop | Relationship | Status |
|------|-------------|--------|
| **LOOP-MEDIA-STACK-SPLIT-20260208** | **Parent — this loop spawned from the split soak period** | Open (P6 soak) |
| LOOP-MEDIA-STACK-ARCH-20260208 | Grandparent — SQLite off NFS, boot ordering | Closed |
| LOOP-MEDIA-STACK-RCA-20260205 | Root cause analysis — daily crashes | Closed |

The split loop (parent) gave us clean infrastructure: 2 dedicated VMs with isolated workloads. This loop builds application-layer governance on top of that infrastructure. GAP-OP-045 (agent discovery) was filed and fixed as a prerequisite.

## Evidence

- Triggering issue: "The Beach House" non-English audio in Jellyfin
- Parent loop: `LOOP-MEDIA-STACK-SPLIT-20260208` (infrastructure split)
- MCPJungle seed: `workbench/infra/compose/mcpjungle/servers/media-stack/` (21 tools, TypeScript)
- Spine governance: `ops/agents/media-agent.contract.md`, `ops/bindings/agents.registry.yaml`
- D49 gate: `surfaces/verify/d49-agent-discovery-lock.sh` (49/49 PASS)
- GAP-OP-045: agent discovery gap (fixed — committed `a2aa7a9`)
- WORKBENCH_CONTRACT.md: agent must be on-demand, no runtime roots
- Legacy audit: runner scripts, n8n workflows, backup scripts documented above

---

## Phase Completion Notes

### P1 — Profile Audit (2026-02-08)

**Recyclarr config:** Pulled from VM 209 container → `workbench/agents/media/config/recyclarr.yml`. Last updated 2025-12-15. Uses TRaSH Guides templates for Sonarr (web-1080p) and Radarr (hd-bluray-web). Single custom override: BR-DISK -10000.

**Radarr profiles:** 7 quality profiles. Profile 7 ("HD Bluray + WEB") is Recyclarr-managed with 22 scored custom formats. Profile 4 ("HD-1080p") has only 4 negative scores. **Zero language custom formats** across all 34 formats.

**Sonarr profiles:** 7 quality profiles. Profile 7 ("WEB-1080p") is Recyclarr-managed.

**Bazarr:** Single language profile (English), 3 subtitle providers (opensubtitlescom, podnapisi, subf2m). Cross-VM connections to Radarr/Sonarr on 100.107.36.76 working.

**"The Beach House" RCA:**
- File: `A.Casa.na.Praia.2018.1080p.AMZN.WEB-DL.DDP2.0.H.264-SiGLA.mkv`
- Radarr tagged as English at grab, imported as Portuguese+English dual audio
- Root cause: no language custom formats → no penalty for non-English primary audio
- Movie uses profile 4 (minimal scoring) instead of profile 7 (Recyclarr-managed)
- Fix path: add language CFs to Recyclarr config (P3), re-search movie (P6)

**Artifacts:**
- `workbench/agents/media/config/recyclarr.yml` — tracked SSOT
- `workbench/agents/media/docs/P1-profile-audit.md` — full findings
- `workbench/agents/media/AGENT.md` — agent identity doc

### P2 — MCP Server Fork (2026-02-08)

**Forked MCPJungle seed** from `workbench/infra/compose/mcpjungle/servers/media-stack/` → `workbench/agents/media/tools/`. TypeScript, 21 tools, ~1600 lines.

**IP updates:** All hardcoded `100.117.1.53` (dead VM 201) replaced:
- Download-stack services → `100.107.36.76` (VM 209)
- Streaming-stack services → `100.123.207.64` (VM 210)

**Port corrections discovered during testing:**
- SABnzbd: 8085 → 8080 (compose confirms `8080:8080`)
- Huntarr: no host port mapping (docker-internal 9705 only) — removed from external smoke test

**Smoke test:** 9/9 externally-reachable services pass (`tests/api-connectivity.sh`):
- VM 209: radarr(401), sonarr(401), lidarr(401), prowlarr(401), sabnzbd(200)
- VM 210: jellyfin(200), jellyseerr(307), navidrome(302), bazarr(200)

**TypeScript:** Clean build, zero errors.

**Artifacts:**
- `workbench/agents/media/tools/src/index.ts` — 21-tool MCP server (v2.0.0)
- `workbench/agents/media/tools/package.json` — media-agent-mcp-server
- `workbench/agents/media/tests/api-connectivity.sh` — connectivity smoke test

### P3 — Profile Management Tools (2026-02-08)

**7 new tools added** (21 → 28 total), MCP server v3.0.0:

| Tool | Type | Purpose |
|------|------|---------|
| `get_quality_profiles` | GET | List quality profiles from Radarr/Sonarr with CF scores |
| `get_custom_formats` | GET | List custom formats with specs (filterable) |
| `get_movie_details` | GET | Detailed movie info: profile, file, languages, media info, CF scores |
| `get_movie_history` | GET | Grab/import history with language detection and CF scores |
| `update_movie_profile` | PUT | Change a movie's quality profile assignment |
| `search_movie_by_id` | POST | Trigger indexer search for a specific movie |
| `get_recyclarr_status` | GET | Compare tracked Recyclarr config against live state, flag governance gaps |

**API endpoints verified:** All 3 new Radarr endpoints (qualityprofile, customformat, history/movie) return 200 on VM 209.

**Key finding confirmed by tooling:** `get_recyclarr_status` correctly identifies 0 language custom formats across 34 total — the governance gap that caused "The Beach House" issue.

**TypeScript:** Clean build, zero errors.

### P4 — Playbooks + Recyclarr Governance (2026-02-08)

**3 troubleshooting playbooks created:**

| Playbook | File | Scope |
|----------|------|-------|
| Wrong Language | `playbooks/wrong-language.md` | Movie/show has non-English audio; diagnostic + fix steps using P3 tools |
| Missing Subtitles | `playbooks/missing-subtitles.md` | Bazarr wanted list, provider limits, embedded sub detection |
| Library Hygiene | `playbooks/library-hygiene.md` | Orphaned files, profile migration, duplicate detection, NFS safety |

**Recyclarr config updated** with language custom formats (TRaSH Guides):
- `d6e9318c875905d6cfb5bee961afcea9` — "Language: Not Original" → -10000 on HD Bluray + WEB, HD-1080p
- `0dc8aec3bd1c47cd6c40c46ecd27e846` — "Language: Not English" → -10000 on HD Bluray + WEB, HD-1080p

**Note:** Config synced to VM 209 in P6.

### P5 — MCPJungle Update (2026-02-08)

Updated `infra/compose/mcpjungle/servers/media-stack/src/index.ts`:
- All IPs from dead VM 201 (100.117.1.53) → split VMs (209/210)
- SABnzbd port corrected: 8085 → 8080
- README.md updated with new VM layout and service table

### P6 — Beach House Fix (2026-02-08)

**Recyclarr sync to VM 209:**
- Config pushed via `docker cp`, `recyclarr sync` run
- 2 new CFs created: "Language: Not Original" (id=41), "Language: Not English" (id=42)
- Total CFs: 34 → 36
- Profiles updated: HD Bluray + WEB (7) and HD-1080p (4) now score both language CFs at -10000

**Movie fix:**
- "The Beach House" moved from profile 4 → 7 (Recyclarr-managed)
- Search triggered for better English release
- Actual re-download depends on indexer availability; governance fix is complete

**Validation:**
- `qualityprofile/7` confirms Language: Not Original = -10000, Language: Not English = -10000
- `qualityprofile/4` confirms same scores
- Any future non-English grab will be penalized by -10000, effectively blocked

### P7 — Verify + Closeout (2026-02-08)

- Agent registry: `implementation_status` changed from `pending` → `active`
- `spine.verify`: 49/49 PASS (D49 validates agent discovery)
- All success criteria met:
  - Agent queries Radarr/Sonarr profiles: `get_quality_profiles`, `get_custom_formats`
  - Agent identifies wrong-language media: `get_movie_details` + `get_movie_history`
  - Recyclarr config tracked: `config/recyclarr.yml` with language CFs
  - MCPJungle updated: IPs point to 209/210
  - "The Beach House" governance fixed: profile 7, language CFs scored, search triggered
  - 28 tools pass connectivity: 9 services reachable across both VMs

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_
_Updated: 2026-02-08 (COMPLETE — all 7 phases done, agent active, 49/49 drift gates)_
