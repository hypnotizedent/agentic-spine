---
status: authoritative
owner: "@ronny"
last_verified: 2026-01-26
scope: repository-structure
---

# REPO STRUCTURE AUTHORITY

> **SINGLE SOURCE OF TRUTH** for repository folder hierarchy.
> Last Updated: 2026-01-26
> Owner: Ronny
>
> **Registered in:** `docs/governance/SSOT_REGISTRY.yaml` (id: repo-structure)

> **Note:** This document was imported from the workbench monolith. The folder hierarchy below describes the workbench layout. For the spine's own folder rules, see [CONTRIBUTING.md](../CONTRIBUTING.md).
>
> **Legacy Policy:** See [LEGACY_DEPRECATION.md](LEGACY_DEPRECATION.md) for rules about promoting workbench content to spine authority.

## PURPOSE

This document is the ONLY authority for where folders and files belong in the workbench monolith (`~/Code/workbench`, formerly `ronny-ops`). Any agent, script, or documentation referencing file placement MUST match these rules. Conflicts mean the other source is WRONG.

> **⚠️ Workbench-Scoped Document**
>
> The folder hierarchy below describes the workbench monolith layout, not the spine.
> This document is maintained in the spine for reference continuity. Do not confuse
> workbench paths with spine paths. For spine structure, see [CONTRIBUTING.md](../CONTRIBUTING.md).

## CRITICAL RULE

**Before creating ANY new folder or moving files:**
1. Check this document FIRST
2. Follow the hierarchy EXACTLY
3. If this doc is wrong, UPDATE THIS DOC then make changes

---

## THE NORTHSTAR PRINCIPLE

```
ONE REPO = ONE MAP
Every important thing has exactly one "home"
Every doc is reachable from an index in 2 clicks
```

---

## CURRENT STRUCTURE (Authoritative)

```
workbench/
├── README.md                    # Repo overview
│
├── docs/                        # Cross-pillar documentation
│   └── governance/              # Authority docs, SOPs, rules
│
├── mint-os/                     # PILLAR: Print shop management (LEGACY)
├── modules/                     # PILLAR: Extracted microservices (NEW)
│   ├── README.md                # Module standards and index
│   ├── MODULE_EXTRACTION_GUIDE.md
│   └── files-api/               # LEGACY (extracted to github:hypnotizedent/artwork-module)
├── artwork-module/              # NOT IN THIS REPO - see github:hypnotizedent/artwork-module
├── media-stack/                 # PILLAR: Jellyfin, *arr stack
├── finance/                     # PILLAR: Firefly, Ghostfolio
├── home-assistant/              # PILLAR: Home automation
├── immich/                      # PILLAR: Photo management
│
├── infrastructure/              # DevOps, servers, shared infra
│   ├── docs/                    # Infra documentation
│   ├── mcps/                    # MCP servers
│   ├── skills/                  # Reusable agent skills
│   ├── cloudflare/              # Cloudflare IaC
│   ├── pihole/                  # Pi-hole configs
│   ├── n8n/                     # n8n workflows
│   └── ...                      # Other infra services
│
├── scripts/                     # Shared scripts (cross-pillar)
│   ├── agents/                  # Agent helper scripts
│   ├── backup/                  # Backup scripts
│   ├── rag/                     # RAG indexing scripts
│   └── ...
│
├── .archive/                    # Archived content (out of scope)
├── .github/                     # GitHub Actions, templates
└── .githooks/                   # Git hooks
```

> **Spine session entry:** [`docs/governance/SESSION_PROTOCOL.md`](SESSION_PROTOCOL.md). The old `workbench/00_CLAUDE.md` is archived and should not be used at runtime.

---

## LAYER DEFINITIONS

Think in 4 layers: **Product → Platform → Infra → Ops**

| Layer | Folder | Contains | Examples |
|-------|--------|----------|----------|
| **Product** | `mint-os/`, `media-stack/`, etc. | Business logic, apps | Mint OS API, Jellyfin configs |
| **Platform** | `infrastructure/mcps/`, `infrastructure/skills/` | Shared tooling | MCP servers, agent skills |
| **Infra** | `infrastructure/cloudflare/`, `infrastructure/pihole/` | IaC, desired state | Terraform, Docker configs |
| **Ops** | `infrastructure/docs/runbooks/` | Runtime procedures | Backup runbooks, incident docs |

---

## THE 8 PILLARS

Each pillar is a self-contained product area with its own docs:

| Pillar | Path | Purpose |
|--------|------|---------|
| **mint-os** | `mint-os/` | Print shop management system (LEGACY - being decomposed) |
| **modules** | `modules/` | LEGACY scaffolds - extracted modules live in own repos |
| **Artwork Module** | `github:hypnotizedent/artwork-module` | Files/artwork API (EXTRACTED) |
| **media-stack** | `media-stack/` | Jellyfin, Sonarr, Radarr, etc. |
| **finance** | `finance/` | Firefly III, Ghostfolio |
| **home-assistant** | `home-assistant/` | Home automation |
| **immich** | `immich/` | Photo/video management |
| **infrastructure** | `infrastructure/` | DevOps, servers, shared infra |

### Module Extraction Pattern

mint-os is being decomposed into standalone modules:

| Module | Status | Location |
|--------|--------|----------|
| **Artwork Module** | ✅ Extracted | `github:hypnotizedent/artwork-module` |
| `pricing-api` | Planned | TBD |
| `shipping-api` | Planned | TBD |

**Reference Implementation:** `github:hypnotizedent/artwork-module` demonstrates the module pattern.
**Extraction Guide:** `modules/MODULE_EXTRACTION_GUIDE.md`
**Legacy Path:** `modules/files-api/` is tombstoned - see `modules/files-api/LEGACY.md`

### Pillar Internal Structure

Each pillar SHOULD follow:

```
<pillar>/
├── README.md                    # Pillar overview
├── CLAUDE.md or *_CONTEXT.md    # Agent entry point
├── docs/
│   ├── reference/               # REF_* docs
│   ├── plans/                   # PLAN_* docs
│   ├── runbooks/                # RUNBOOK_* docs
│   ├── sessions/                # Session handoffs
│   └── architecture/            # Architecture docs
├── scripts/                     # Pillar-specific scripts
└── ...                          # Service-specific folders
```

---

## FORBIDDEN AT ROOT

**NEVER create these at repository root:**

| Forbidden | Why | Put It In |
|-----------|-----|-----------|
| `logs/` | Transient | `.gitignore` or pillar-specific |
| `temp/`, `tmp/` | Transient | Don't commit |
| `misc/`, `notes/` | Junk drawer | Archive or delete |
| `old/`, `backup/` | Dead weight | `.archive/` |
| `dotfiles/` | Belongs in infra | `infrastructure/dotfiles/` |
| Any new pillar | Without governance | Discuss first |

---

## REPO ROOT CANON (LOCKED)

> **Hard rule:** No new top-level folders without updating this document first.

### Allowed Root Entries (Exact)

| Entry | Type | Purpose |
|-------|------|---------|
| `modules/` | dir | Deployable microservices (preferred home for new code) |
| `infrastructure/` | dir | Platform, tooling, ops configs |
| `docs/` | dir | Cross-pillar documentation |
| `scripts/` | dir | Shared scripts |
| `receipts/` | dir | Execution proof (timestamped, gitignored) |
| `_evidence/` | dir | Stable artifacts supporting claims |
| `logs/` | dir | Local logs (gitignored, non-authoritative) |
| `.archive/` | dir | Archived content (out of scope) |
| `.github/` | dir | GitHub Actions, templates |
| `.githooks/` | dir | Git hooks |
| `.brain/` | dir | Local agent context (gitignored) |
| `.claude/` | dir | Claude Code settings |
| `.opencode/` | dir | OpenCode settings |
| `.agent/` | dir | Agent context |
| `.venv/` | dir | Python virtual environment |
| `.worktrees/` | dir | Git worktrees |
| `.external-repos/` | dir | External repo references |
| `.mcp.json` | file | MCP server config |
| `.cursorrules` | file | Cursor editor rules |
| `.DS_Store` | file | macOS metadata (gitignored) |
| `mint-os/` | dir | PILLAR: Print shop (legacy) |
| `media-stack/` | dir | PILLAR: Media services |
| `finance/` | dir | PILLAR: Financial tools |
| `home-assistant/` | dir | PILLAR: Home automation |
| `immich/` | dir | PILLAR: Photo management |
| `artwork-module/` | dir | LEGACY: Historical extraction notes |
| `README.md` | file | Repo overview |
| `AGENTS.md` | file | Agent routing |
| `CLAUDE.md` | file | Claude Code entry (mirrors AGENTS.md) |
| `opencode.json` | file | OpenCode config |
| `.claudeignore` | file | Claude Code exclusions |
| `.gitignore` | file | Git exclusions |

### Drift Check Command

Run this to verify no unexpected root entries exist:

```bash
TS="$(date +%F_%H%M)"
R="$HOME/Code/workbench"
OUT="$R/receipts/repo_root_drift_${TS}.log"
mkdir -p "$R/receipts"

cd "$R" || exit 1

# Allowlist regex (update ONLY via PR to this doc)
ALLOW='^(\.git|\.github|\.githooks|\.archive|\.brain|\.claude|\.opencode|\.agent|\.venv|\.worktrees|\.external-repos|\.mcp\.json|\.cursorrules|\.DS_Store|modules|infrastructure|docs|scripts|receipts|_evidence|logs|mint-os|media-stack|finance|home-assistant|immich|artwork-module|README\.md|AGENTS\.md|CLAUDE\.md|opencode\.json|\.claudeignore|\.gitignore)$'

{
  echo "=== REPO ROOT DRIFT CHECK @ $TS ==="
  echo "Repo: $R"
  echo
  echo "Root entries:"
  ls -1A | sed 's/^/  /'
  echo
  echo "Unexpected entries:"
  DRIFT=$(ls -1A | grep -Ev "$ALLOW" || true)
  if [ -n "$DRIFT" ]; then
    echo "$DRIFT" | sed 's/^/  ⚠️  /'
  else
    echo "  (none)"
  fi
} | tee "$OUT"

if [ -n "$DRIFT" ]; then
  echo "DRIFT DETECTED — update this doc or move files" >&2
  exit 2
fi
echo "PASS: repo root clean"
echo "WROTE: $OUT"
```

**PASS =** Only entries from the allowlist above. Any unexpected entry = drift.

---

## FILE PLACEMENT RULES

| File Pattern | MUST Go In | Example |
|--------------|------------|---------|
| `*_AUTHORITY.md` | `docs/governance/` or pillar `docs/` | `INFRASTRUCTURE_AUTHORITY.md` |
| `*_RULES.md` | `docs/governance/` | `RAG_INDEXING_RULES.md` |
| `*_SOP.md` | `docs/governance/` | `ISSUE_CLOSURE_SOP.md` |
| `REF_*.md` | `*/docs/reference/` | `mint-os/docs/reference/REF_API.md` |
| `PLAN_*.md` | `*/docs/plans/` | `mint-os/docs/plans/PLAN_SHOPIFY.md` |
| `RUNBOOK_*.md` | `*/docs/runbooks/` | `infrastructure/docs/runbooks/RUNBOOK_BACKUP.md` |
| `*-HANDOFF.md` | `*/docs/sessions/` | `mint-os/docs/sessions/2026-01-22-HANDOFF.md` |
| `SPEC.md` | `modules/<module>/` | `modules/files-api/SPEC.md` |

---

## THE 7 RULES (Enforce These)

1. **No orphan docs** — Every doc linked from an INDEX or pillar README
2. **Service docs live with service** — README + runbook links in each pillar
3. **Decisions are ADRs** — `docs/architecture/decisions/ADR-####-title.md`
4. **Runbooks are step-by-step** — Symptoms → Checks → Fix → Verify → Rollback
5. **One canonical inventory** — `infrastructure/SERVICE_REGISTRY.md`
6. **No misc/temp/old/notes** — Archive or delete
7. **Every category folder has a README** — Explains what's in it

---

## TRACEABILITY CHAIN

```
docs/governance/SESSION_PROTOCOL.md (session entry)
    ↓
docs/brain/README.md (rules + context helpers)
    ↓
docs/governance/GOVERNANCE_INDEX.md (rules, SSOT map)
    ↓
docs/governance/SSOT_REGISTRY.yaml (canonical authority list)
    ↓
<pillar>/*_CONTEXT.md or pillar READMEs (domain entry)
```

Every agent should be able to trace from `docs/governance/SESSION_PROTOCOL.md` to any authoritative doc in 2-3 hops.

---

## RAG INDEXING ALIGNMENT

This structure aligns with `RAG_INDEXING_RULES.md`:

| Indexed | Path Pattern |
|---------|--------------|
| ✅ YES | `docs/governance/*.md` |
| ✅ YES | `*_AUTHORITY.md` |
| ✅ YES | `*_RULES.md` |
| ✅ YES | `RUNBOOK_*.md` |
| ✅ YES | `*/docs/reference/*.md` |
| ❌ NO | `logs/`, `temp/`, `.archive/` |
| ❌ NO | `node_modules/`, `.venv/` |

---

## VIOLATIONS

If you find a file in the wrong place:

1. **DO NOT just move it**
2. Check if THIS document needs updating first
3. If structure is correct, move file to correct location
4. Update any INDEX files that reference it
5. Re-run `./scripts/agents/doc-drift-check.sh`

---

## UPDATE PROTOCOL

1. Any structure change MUST update this document FIRST
2. Then move files/folders
3. Update INDEX files
4. Re-index to RAG: `mint index`
5. Announce in session handoff

---

## GIT HOOKS & GITHUB ACTIONS (Enforcement)

Structure rules are **enforced automatically**. Commits that violate rules will be blocked.

### Pre-Commit Hook (`.githooks/pre-commit`)

**Blocks commits that:**
- Create `.md` files at repo root (except `00_*.md`, `README.md`)
- Create files in non-allowed directories
- Put `SESSION`/`HANDOFF` files outside `*/docs/sessions/`
- Put `REF_*` files outside `*/docs/reference/`
- Put `PLAN_*` files outside `*/docs/plans/`
- Create duplicate-prone filenames (`REALITY_MAP`, `OVERVIEW`, `SUMMARY`, etc.)

**Allowed root directories:**
```
mint-os | infrastructure | finance | media-stack | home-assistant | immich
modules | artwork-module | scripts | docs | .github | .archive | .githooks
.agent | .claude | .opencode
```

**Tool config directories (mandated by tools, not us):**
- `.claude/` — Claude Code slash commands and settings
- `.opencode/` — OpenCode slash commands and settings
- `.github/copilot-instructions.md` — GitHub Copilot context

**Emergency bypass (use sparingly):**
```bash
SKIP_DOC_CHECK=1 git commit -m "message"
```

### GitHub Actions (`.github/workflows/`)

| Workflow | Trigger | What It Does |
|----------|---------|--------------|
| `documentation-lint.yml` | PR with `.md` changes | Lints markdown, checks broken links, validates naming |
| `auto-label-issues.yml` | Issue created | Auto-labels by pillar/type |
| `deploy-*.yml` | Push to main | Deploys Mint OS apps |

### If Hook Blocks Your Commit

1. **Read the error message** — it tells you where to put the file
2. **Check this document** — is the file in the right place?
3. **Move the file** — to the correct location per rules above
4. **If rules are wrong** — update THIS doc first, then `.githooks/pre-commit`

### Modifying Hooks

If you need to change allowed directories or rules:

1. Update `docs/governance/REPO_STRUCTURE_AUTHORITY.md` (this file)
2. Update `.githooks/pre-commit` to match
3. Update `.github/workflows/documentation-lint.yml` if needed
4. Commit all three together

**Location:** `.githooks/pre-commit` line ~159 defines `ALLOWED_ROOT_DIRS`

---

## RELATED DOCS

| Doc | Relationship |
|-----|--------------|
| `docs/governance/SESSION_PROTOCOL.md` | References this for folder rules |
| `AGENTS.md` | Routes agents to correct pillars |
| `RAG_INDEXING_RULES.md` | Defines what gets indexed based on structure |
| `infrastructure/docs/INDEX.md` | Role-based entry point |
| `mint-os/docs/reference/INDEX.md` | Pillar-specific doc catalog |
| `.githooks/pre-commit` | Enforces structure rules on commit |
| `.github/workflows/documentation-lint.yml` | Enforces naming conventions on PR |
| `infrastructure/docs/locations/LAPTOP.md#home-contract` | Home folder zones + workspace rules |
