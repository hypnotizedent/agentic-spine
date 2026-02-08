# LOOP-MEDIA-AGENT-WORKBENCH-20260208

> **Status:** open
> **Blocked By:** _(none)_
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** medium

---

## Executive Summary

Design and build a dedicated media domain agent in the workbench repo with its own MCP tools, declarative configuration governance, and troubleshooting runbooks for the download-stack (VM 209) and streaming-stack (VM 210). The spine continues to own infrastructure (compose, health, routing, secrets); this agent owns the **application layer** (language profiles, quality settings, subtitle preferences, library hygiene).

---

## Rationale

### The Gap

The spine governs **where** media services run but not **how** they behave. Configuration like Radarr language profiles, Recyclarr custom formats, Bazarr subtitle languages, and Jellyfin metadata settings all live inside each app's database or config directory. There is:

- No declarative config tracked in version control
- No agent that understands media domain semantics (e.g., "this movie is in the wrong language")
- No tooling to inspect or modify media service state programmatically
- No governance over quality/language profiles across the *arr stack

### Why a Workbench Agent

| Principle | Rationale |
|-----------|-----------|
| Spine = infrastructure governance | Compose, health, routing, secrets stay in spine |
| Workbench = operational tooling | Domain-specific tools and agents belong here |
| Separation of concerns | Media config changes shouldn't require spine commits |
| Existing pattern | MCPJungle already has a `media-stack` MCP server (8 tools) — seed exists |
| WORKBENCH_CONTRACT compliance | Agent runs on-demand, no watchers/cron (spine invokes if needed) |

### Triggering Event

Jellyfin displaying "The Beach House" in a non-English audio track. Root cause: Radarr grabbed a non-English release because language profiles are unmanaged and invisible to governance.

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
├── tools/                      # MCP-compatible tools (API wrappers)
│   ├── radarr.py               # Search, grab, profile management
│   ├── sonarr.py               # Search, grab, profile management
│   ├── jellyfin.py             # Library, metadata, playback state
│   ├── bazarr.py               # Subtitle language management
│   ├── recyclarr.py            # Declarative profile sync
│   ├── prowlarr.py             # Indexer status
│   └── sabnzbd.py              # Download queue status
├── config/
│   └── recyclarr.yml           # Tracked quality/language profiles (SSOT)
├── playbooks/
│   ├── wrong-language.md       # Troubleshooting: movie/show wrong audio
│   ├── missing-subtitles.md    # Troubleshooting: no subs or wrong language
│   └── library-hygiene.md      # Orphaned files, duplicate detection
└── tests/
    └── api-connectivity.sh     # Smoke test: can tools reach both VMs?
```

### Relationship to MCPJungle

The existing `infra/compose/mcpjungle/servers/media-stack/` (8 tools, pointing at old VM 201) becomes a **downstream consumer**. The workbench agent's tools are the source; MCPJungle re-exposes a subset for Claude Mobile access. Update MCPJungle server to point at VM 209/210 endpoints.

---

## Phases

| Phase | Scope | Dependency | Status |
|-------|-------|------------|--------|
| P0 | Design: agent contract, tool inventory, config schema | — | PENDING |
| P1 | Pull current Recyclarr config from VM 209; audit language/quality profiles in Radarr/Sonarr | P0 | PENDING |
| P2 | Build core MCP tools (radarr, sonarr, jellyfin — read-only first) | P1 | PENDING |
| P3 | Add config governance (recyclarr.yml tracked, push-to-VM capability) | P2 | PENDING |
| P4 | Build troubleshooting playbooks + write tools (profile updates, re-search) | P3 | PENDING |
| P5 | Update MCPJungle media-stack server (VM 209/210 endpoints) | P2 | PENDING |
| P6 | Fix "The Beach House" — validate end-to-end with a real issue | P4 | PENDING |
| P7 | Verify + closeout | P6 | PENDING |

---

## Key Decisions (To Lock In P0)

| Decision | Options | Notes |
|----------|---------|-------|
| Tool language | Python / TypeScript / Bash | Python preferred (requests + good *arr API libraries) |
| MCP protocol | Standalone MCP server vs direct API scripts | MCP server enables Claude Code + MCPJungle reuse |
| Config push method | SSH + scp vs API-driven | Recyclarr can be API-driven via Radarr/Sonarr |
| Invocation model | Claude Code session / mailroom prompt / CLI | Must comply with WORKBENCH_CONTRACT (no watchers) |

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| Agent can query Radarr/Sonarr profiles | `tools/radarr.py list-profiles` returns language profiles |
| Agent can identify wrong-language media | Given a movie title, reports audio tracks + grab history |
| Recyclarr config tracked in workbench | `config/recyclarr.yml` exists, matches live VM state |
| MCPJungle updated for split VMs | Media tools resolve to 209/210, not 201 |
| "The Beach House" fixed | Correct English release in Jellyfin |

---

## Non-Goals

- Do NOT move compose/deploy governance out of spine
- Do NOT create schedulers or watchers (WORKBENCH_CONTRACT)
- Do NOT replace Radarr/Sonarr web UIs — agent is supplemental
- Do NOT handle Spotify OAuth flows (manual, browser-only)
- Do NOT govern NFS mounts or storage (spine owns this)

---

## Evidence

- Triggering issue: "The Beach House" non-English audio in Jellyfin
- Existing seed: `workbench/infra/compose/mcpjungle/servers/media-stack/` (8 tools)
- Spine bindings: `docker.compose.targets.yaml`, `services.health.yaml`, `ssh.targets.yaml`
- WORKBENCH_CONTRACT.md: agent must be on-demand, no runtime roots

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_
