---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: ronny-ops-legacy-census
parent_loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
lane: LANE-A
---

# L1: Legacy Census — `/Users/ronnyworks/ronny-ops`

> Read-only discovery audit of the legacy `ronny-ops` repository.
> Produced by LANE-A for LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217.
> Date: 2026-02-17

---

## 1. Summary Statistics

| Metric | Value |
|--------|-------|
| Total files (excl `.git/`, `node_modules/`) | 15,964 |
| Total directories | 537 |
| Top-level entries | 16 dirs + 7 files |
| Docker-compose files | 20 |
| Shell scripts | ~200+ |
| `.env` / `.env.example` files | 12 |
| Last commit | 2026-02-11 (freeze state) |
| Git remote | `github.com:hypnotizedent/ronny-ops.git` |
| Active shell reference | `~/.zshrc: export LEGACY_ROOT="/Users/ronnyworks/ronny-ops"` |

---

## 2. Top-Level Tree

```
ronny-ops/
├── .agent/                    (1 file)     shell-profile.sh
├── .archive/                  (32 files)   shipping-simple app, artwork-module docs
├── .brain/                    (5 files)    rules.md, memory.md, generate-context.sh
├── .claude/                   (5 files)    slash commands (ctx, verify, ask, issue, incidents)
├── .external-repos/           (0 files)    empty stubs
├── .githooks/                 (3 files)    commit-msg, pre-push, pre-commit
├── .github/                   (22 files)   CI workflows, issue templates
├── .opencode/                 (3 files)    slash commands (verify, ctx, ask)
├── 00_CLAUDE.md                            agent protocol (legacy)
├── AGENTS.md                               agent instructions (legacy)
├── CLAUDE.md                               mirror of AGENTS.md (legacy)
├── README.md                               repo readme (legacy)
├── opencode.json                           OpenCode config (legacy)
├── .cursorrules                            Cursor IDE config
├── .claudeignore                           Claude ignore patterns
├── .gitignore                              git ignore patterns
├── .markdownlintignore                     lint config
├── artwork-module/            (1 file)     README.md stub only
├── docs/                      (101 files)  governance, audits, runbooks, sessions
├── finance/                   (57 files)   docker-compose, scripts, docs
├── home-assistant/            (213 files)  scripts, docs, archives
├── immich/                    (134 files)  plans, docs, scripts, archives
├── infrastructure/            (384 files)  docker configs, dotfiles, MCP, services
├── media-stack/               (158 files)  docker-compose (809 lines), scripts, configs
├── mint-os/                   (14,606 files) full T3/pnpm application monorepo
├── modules/                   (42 files)   files-api extraction (TypeScript)
└── scripts/                   (188 files)  agents, bootstrap, RAG, infra, deploy
```

**Dominance:** `mint-os/` contains 91.5% of all files — a complete T3-stack business application.

---

## 3. Per-Folder Disposition

### 3.1 Hidden/Config Directories

| Path | Files | Disposition | Rationale |
|------|-------|-------------|-----------|
| `.agent/` | 1 | **drop** | `shell-profile.sh` references `~/ronny-ops/` paths; superseded by spine infisical-agent pattern |
| `.archive/` | 32 | **archive** | `shipping-simple` (Vite app), artwork-module planning docs; historical reference only |
| `.brain/` | 5 | **extract** | `memory.md` (135 lines of operational learnings) has unique session knowledge not in spine; rest superseded |
| `.claude/` | 5 | **drop** | Slash commands fully superseded by agentic-spine `.claude/commands/` |
| `.external-repos/` | 0 | **drop** | Empty stubs for mint-prints repos |
| `.githooks/` | 3 | **archive** | commit-msg, pre-push, pre-commit hooks; may contain unique validation logic |
| `.github/` | 22 | **extract** | CI workflows (`deploy-api.yml`, `weekly-audit.yml`, `infrastructure.yml`) contain Mint OS deployment logic |
| `.opencode/` | 3 | **drop** | Slash commands superseded by spine |

### 3.2 Root Files

| Path | Disposition | Rationale |
|------|-------------|-----------|
| `00_CLAUDE.md` | **drop** | Agent protocol superseded by spine `AGENTS.md` + `SESSION_PROTOCOL.md` |
| `AGENTS.md` | **drop** | Agent instructions superseded; Z.AI/GLM section has some unique config notes |
| `CLAUDE.md` | **drop** | Mirror of AGENTS.md |
| `README.md` | **drop** | Repo overview superseded |
| `opencode.json` | **drop** | Superseded by `workbench/dotfiles/opencode/opencode.json` |
| `.cursorrules` | **drop** | IDE config, no unique value |
| `.claudeignore` | **drop** | Ignore patterns superseded |
| `.gitignore` | **archive** | May have unique patterns for mint-os development |
| `.markdownlintignore` | **drop** | Lint config |

### 3.3 Domain Directories

| Path | Files | Disposition | Rationale |
|------|-------|-------------|-----------|
| `artwork-module/` | 1 | **drop** | Stub README only; extracted to standalone `artwork-module` repo |
| `docs/` | 101 | **extract** | Governance docs, SSOT registry, audits, runbooks, secrets docs, session memory — unique operational knowledge |
| `finance/` | 57 | **extract** | Live `docker-compose.yml` (239 lines, 8 services), `simplefin-to-firefly.py`, deploy/backup scripts, Firefly reference docs |
| `home-assistant/` | 213 | **extract** | 19 HA scripts (`ha-cli.sh`, entity rename/delete/area tools), Stream Deck controller, runbooks, session docs |
| `immich/` | 134 | **archive** | Mostly historical reset/migration docs; `backup-immich-db.sh` and `extract_exif.sh` may have residual value |
| `infrastructure/` | 384 | **extract** | Critical: docker-compose files, dotfiles, MCP configs, n8n workflows, service registry, data inventories |
| `media-stack/` | 158 | **extract** | 809-line `docker-compose.yml` (30+ services), 27 scripts, Kometa/Recyclarr/Janitorr configs |
| `mint-os/` | 14,606 | **archive** | Full T3/pnpm monorepo (apps/api, admin, production, web, shipping, suppliers, artwork, job-estimator); should be its own repo or archived wholesale |
| `modules/` | 42 | **archive** | `files-api` TypeScript extraction; superseded by standalone `artwork-module` repo |
| `scripts/` | 188 | **extract** | Agent scripts, bootstrap templates, RAG tooling, infra verify scripts, deploy scripts, Firefly reconciliation |

---

## 4. Severity-Ranked Findings

### P0 — Critical (Runtime Authority / Active References)

| # | Finding | Absolute Path | Target Repo |
|---|---------|---------------|-------------|
| P0-1 | **Live docker-compose: media-stack** (809 lines, 30+ services incl. Jellyfin, Sonarr, Radarr, Lidarr, SABnzbd, Kometa, Navidrome, Unpackerr, Autopulse) | `/Users/ronnyworks/ronny-ops/media-stack/docker-compose.yml` | `workbench` |
| P0-2 | **Live docker-compose: finance** (239 lines, 8 services: Firefly, Ghostfolio, Paperless, Redis, Postgres, SimpleFIN, Data Importer) | `/Users/ronnyworks/ronny-ops/finance/docker-compose.yml` | `workbench` |
| P0-3 | **Live docker-compose: mint-os** on docker-host (255 lines: API, Postgres, MinIO, monitoring, frontends) | `/Users/ronnyworks/ronny-ops/infrastructure/docker-host/mint-os/docker-compose.yml` | `workbench` |
| P0-4 | **Machine-readable service registry** — host IPs, ports, Infisical project IDs | `/Users/ronnyworks/ronny-ops/infrastructure/SERVICE_REGISTRY.yaml` | `agentic-spine` (compare with `ops/bindings/`) |
| P0-5 | **Operational inventories** (6 JSON files: backup, secrets, monitoring, agents, updates, backup_calendar) | `/Users/ronnyworks/ronny-ops/infrastructure/data/*.json` | `agentic-spine` |
| P0-6 | **SSOT Registry** (729 lines, 35+ SSOTs with authority chains) | `/Users/ronnyworks/ronny-ops/docs/governance/SSOT_REGISTRY.yaml` | `agentic-spine` (compare/merge) |
| P0-7 | **Shell reference still active** — `~/.zshrc` exports `LEGACY_ROOT="/Users/ronnyworks/ronny-ops"` | `/Users/ronnyworks/.zshrc` (line referencing ronny-ops) | `workbench` (remove reference) |
| P0-8 | **Original infisical-agent.sh** — may differ from spine's canonical version | `/Users/ronnyworks/ronny-ops/scripts/agents/infisical-agent.sh` | compare with `agentic-spine/ops/tools/infisical-agent.sh` |
| P0-9 | **n8n workflow exports** (78+ JSON files, active automation workflows) | `/Users/ronnyworks/ronny-ops/infrastructure/n8n/workflows/*.json` | `workbench` |
| P0-10 | **Cloudflare tunnel compose + DNS exports** | `/Users/ronnyworks/ronny-ops/infrastructure/cloudflare/tunnel/docker-compose.yml` | `workbench` |

### P1 — Important (Unique Operational Knowledge)

| # | Finding | Absolute Path | Target Repo |
|---|---------|---------------|-------------|
| P1-1 | **HA operational scripts** (19 files: ha-cli.sh, entity rename/delete/area/health/backup/deploy tools) | `/Users/ronnyworks/ronny-ops/home-assistant/scripts/` | `workbench` |
| P1-2 | **Media-stack operational scripts** (27 files: media-health.sh, trickplay-guard.sh, backup scripts, curation tools) | `/Users/ronnyworks/ronny-ops/media-stack/scripts/` | `workbench` |
| P1-3 | **Finance scripts** (8 files: simplefin-to-firefly.py, deploy/backup/sync scripts) | `/Users/ronnyworks/ronny-ops/finance/scripts/` | `workbench` |
| P1-4 | **Bootstrap templates** (new-vm.sh, new-postgres-db.sh, new-lxc.sh, new-docker-stack.sh) | `/Users/ronnyworks/ronny-ops/scripts/bootstrap/` | `workbench` |
| P1-5 | **Infrastructure dotfiles** — SSH configs, shell aliases, macbook configs (partially migrated to workbench) | `/Users/ronnyworks/ronny-ops/infrastructure/dotfiles/` | compare with `workbench/dotfiles/` |
| P1-6 | **Pihole docker-compose + env** | `/Users/ronnyworks/ronny-ops/infrastructure/pihole/docker-compose.yml` | `workbench` |
| P1-7 | **Storage/MinIO standalone compose** | `/Users/ronnyworks/ronny-ops/infrastructure/storage/docker-compose.yml` | `workbench` |
| P1-8 | **Dashy dashboard config** | `/Users/ronnyworks/ronny-ops/infrastructure/dashy/config.yml` | `workbench` |
| P1-9 | **Hardware registry** — Dell R730XD specs, service tags, IPs, NAS details | `/Users/ronnyworks/ronny-ops/infrastructure/docs/hardware/HARDWARE_REGISTRY.md` | `workbench` |
| P1-10 | **Session memory** — 135 lines of operational learnings (2026-01-22 through 2026-01-24) | `/Users/ronnyworks/ronny-ops/.brain/memory.md` | `agentic-spine` (merge into session memory) |
| P1-11 | **Incidents log** — historical incident record | `/Users/ronnyworks/ronny-ops/infrastructure/docs/INCIDENTS_LOG.md` | `workbench` |
| P1-12 | **n8n email templates** (payment-needed, ready-for-pickup, shipped HTML) | `/Users/ronnyworks/ronny-ops/infrastructure/n8n/email-templates/` | `workbench` |
| P1-13 | **MCPJungle server configs** (15+ MCP server definitions: postgres, firefly, home-assistant, etc.) | `/Users/ronnyworks/ronny-ops/infrastructure/mcpjungle/servers/` | compare/archive |
| P1-14 | **CI workflows** (deploy-api, weekly-audit, infrastructure pipelines) | `/Users/ronnyworks/ronny-ops/.github/workflows/` | `workbench` or `mint-modules` |
| P1-15 | **Secrets docs** (Infisical restructure plan, secrets foundation deep dive) | `/Users/ronnyworks/ronny-ops/docs/secrets/` | `agentic-spine` |
| P1-16 | **Governance docs** (30+ governance documents, domain routing, compose authority, agent boundaries) | `/Users/ronnyworks/ronny-ops/docs/governance/` | compare with `agentic-spine/docs/governance/` |
| P1-17 | **RAG tooling scripts** (index.sh, health-check.sh, cleanup-duplicates.sh, quality-test.sh, full-resync.sh) | `/Users/ronnyworks/ronny-ops/scripts/rag/` | compare with spine RAG caps |
| P1-18 | **Agent scripts** (28 files: daily-jobs.sh, watchdog, health-check, domain-agent, cloudflare-agent, etc.) | `/Users/ronnyworks/ronny-ops/scripts/agents/` | compare with spine caps |
| P1-19 | **Shopify MCP integration** (SSOT, CLAUDE.md, migration SQL) | `/Users/ronnyworks/ronny-ops/infrastructure/shopify-mcp/` | `workbench` or `mint-modules` |
| P1-20 | **Mint-OS database migrations** (12 SQL migration files, 2025-2026) | `/Users/ronnyworks/ronny-ops/mint-os/migrations/` | `mint-modules` |

### P2 — Low (Historical / Superseded)

| # | Finding | Absolute Path | Target |
|---|---------|---------------|--------|
| P2-1 | **mint-os application monorepo** (14,606 files: 8 apps, packages, tools, stitch-estimator) | `/Users/ronnyworks/ronny-ops/mint-os/` | archive wholesale |
| P2-2 | **modules/files-api** (42 files: TypeScript files-api extraction) | `/Users/ronnyworks/ronny-ops/modules/` | archive (superseded by artwork-module repo) |
| P2-3 | **Archived shipping-simple app** (Vite SPA) | `/Users/ronnyworks/ronny-ops/.archive/shipping-simple-2026-01-21/` | drop |
| P2-4 | **Archived artwork-module planning docs** | `/Users/ronnyworks/ronny-ops/.archive/artwork-module/` | drop |
| P2-5 | **Immich archive** (reset/migration historical docs) | `/Users/ronnyworks/ronny-ops/immich/.archive/` | drop |
| P2-6 | **HA archive** (50+ historical session/plan/audit docs) | `/Users/ronnyworks/ronny-ops/home-assistant/.archive/` | drop |
| P2-7 | **n8n archived workflows** (35 legacy JSON workflow files) | `/Users/ronnyworks/ronny-ops/infrastructure/n8n/.archive/workflows/` | drop |
| P2-8 | **Legacy agent context docs** (mint-os CLAUDE.md, AGENTS_START_HERE.md, domain context files) | various pillar `*_CONTEXT.md` files | drop |
| P2-9 | **Skills templates** (4 SKILL.md files: session-protocol, debugging, brainstorming, writing-plans) | `/Users/ronnyworks/ronny-ops/infrastructure/skills/` | drop (superseded by spine skills) |
| P2-10 | **Vaultwarden** (README.md only) | `/Users/ronnyworks/ronny-ops/infrastructure/vaultwarden/` | drop |

---

## 5. Sensitive Content Patterns

All secret references use environment variable interpolation (`${VAR}`) or Infisical agent fetching — **no plaintext secrets detected in committed files**. Patterns found:

| Pattern | Locations | Risk |
|---------|-----------|------|
| `${POSTGRES_PASSWORD}` | finance, media-stack, n8n compose files | Low (env-var interpolated) |
| `${*_API_KEY}` / `${*_TOKEN}` | media-stack compose (Radarr, Sonarr, Lidarr, Jellyfin, Spotify) | Low (env-var) |
| `infisical-agent.sh get` | 15+ scripts across agents, finance, RAG, immich | Low (runtime fetch) |
| `${{ secrets.* }}` | `.github/workflows/*.yml` (CI secrets) | Low (GitHub secrets) |
| `${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET}` | `scripts/bootstrap-secrets.sh` | Low (env-var) |
| `mintfiles-mount.env` | `/Users/ronnyworks/ronny-ops/scripts/mounts/mintfiles-mount.env` | **Check** (may contain mount credentials) |

---

## 6. Docker-Compose Inventory

| Compose File | Lines | Services | Status |
|--------------|-------|----------|--------|
| `media-stack/docker-compose.yml` | 809 | ~30 (Jellyfin, *arr suite, SABnzbd, Kometa, Navidrome, Unpackerr, Huntarr, Autopulse, etc.) | **Live** |
| `finance/docker-compose.yml` | 239 | 8 (Firefly III, Data Importer, SimpleFIN, Ghostfolio, Paperless, Postgres, Redis x2) | **Live** |
| `infrastructure/docker-host/mint-os/docker-compose.yml` | 255 | Mint-OS API + DB + MinIO | **Live** |
| `infrastructure/n8n/docker-compose.yml` | — | n8n + Postgres | **Live** |
| `infrastructure/pihole/docker-compose.yml` | — | Pi-hole | **Live** |
| `infrastructure/storage/docker-compose.yml` | — | MinIO standalone | **Live** |
| `infrastructure/dashy/docker-compose.yml` | — | Dashy dashboard | **Live** |
| `infrastructure/cloudflare/tunnel/docker-compose.yml` | — | Cloudflare tunnel | **Live** |
| `infrastructure/mcpjungle/docker-compose.yml` | — | MCPJungle | **Superseded** |
| `finance/mail-archiver/docker-compose.yml` | — | Mail archiver | Unknown |
| `modules/files-api/docker-compose.yml` | — | Files API + Postgres | **Superseded** |
| `mint-os/docs/.archive/legacy-2025/mint-os-app-stack-v2/*.yml` | — | 5 legacy compose variants | **Dead** |
| `immich/.archive/2026-01-05-full-reset/configs/docker-compose.yml` | — | Immich (archived) | **Dead** |
| `infrastructure/templates/docker-compose.template.yml` | — | Template | Reference |

---

## 7. Cross-Reference: Already Migrated to Spine/Workbench

| Legacy Path | Migrated Counterpart | Status |
|-------------|---------------------|--------|
| `infrastructure/dotfiles/ssh/` | `workbench/dotfiles/ssh/` | Partially migrated |
| `infrastructure/dotfiles/macbook/hammerspoon/` | `workbench/dotfiles/hammerspoon/` | Migrated |
| `infrastructure/dotfiles/macbook/raycast-scripts/` | `workbench/dotfiles/raycast/` | Migrated |
| `scripts/agents/infisical-agent.sh` | `agentic-spine/ops/tools/infisical-agent.sh` | Migrated (canonical) |
| Agent protocol (`00_CLAUDE.md`, `AGENTS.md`) | `agentic-spine/AGENTS.md` + `docs/governance/` | Migrated |
| `.brain/` context system | `agentic-spine/docs/brain/` | Migrated |
| `.claude/commands/` | `agentic-spine/.claude/commands/` | Migrated |
| `docs/governance/` (many docs) | `agentic-spine/docs/governance/` | Partially migrated |

---

## 8. Extraction Priority Summary

| Priority | Action | File Count | Target |
|----------|--------|------------|--------|
| **P0** | Extract docker-compose files + service registry + data inventories | ~30 files | `workbench/infra/compose/` |
| **P0** | Remove `LEGACY_ROOT` from `~/.zshrc` | 1 reference | `workbench/dotfiles/zsh/` |
| **P1** | Extract operational scripts (HA, media, finance, bootstrap, RAG, agents) | ~120 files | `workbench/` |
| **P1** | Extract n8n workflows + email templates | ~90 files | `workbench/infra/` |
| **P1** | Compare/merge governance docs + SSOT registry | ~40 files | `agentic-spine` |
| **P1** | Extract hardware registry + incidents log | ~5 files | `workbench/docs/infrastructure/` |
| **P2** | Archive mint-os wholesale | 14,606 files | separate repo or archive |
| **P2** | Drop superseded configs (artwork-module, modules, .agent, .claude, .opencode) | ~50 files | drop |
| **P2** | Drop all `.archive/` contents | ~100+ files | drop |

---

*End of L1 Legacy Census*
