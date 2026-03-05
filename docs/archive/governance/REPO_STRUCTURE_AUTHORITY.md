---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-24
scope: repository-structure
---

# REPO STRUCTURE AUTHORITY

> **SINGLE SOURCE OF TRUTH** for repository folder hierarchy.
> Last Updated: 2026-02-08
> Owner: Ronny
>
> **Registered in:** `docs/governance/SSOT_REGISTRY.yaml` (id: repo-structure)

> **Note:** This document was imported from the workbench monolith. The folder hierarchy below describes the workbench layout. For the spine's own folder rules, see [CONTRIBUTING.md](../CONTRIBUTING.md).
>
> **Legacy Policy:** See [LEGACY_DEPRECATION.md](LEGACY_DEPRECATION.md) for rules about promoting workbench content to spine authority.

## PURPOSE

This document is the ONLY authority for where folders and files belong in the workbench monolith (`~/code/workbench`, formerly `ronny-ops`). Any agent, script, or documentation referencing file placement MUST match these rules. Conflicts mean the other source is WRONG.

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
├── WORKBENCH_CONTRACT.md        # Canonical rules for this repo
├── agents/                      # Domain agent implementations
│   └── <domain>/                # Per-domain: tools, configs, playbooks, docs
├── bin/                         # Entry points (ops/mint/work helpers)
├── bootstrap/                   # Mac setup helpers
├── docs/                        # Documentation (core + legacy)
│   ├── governance/              # Workbench governance (reference)
│   ├── infrastructure/          # Core infra index (authoritative in workbench)
│   ├── legacy/                  # Quarantined reference (read-only)
│   └── receipts/                # Workbench session receipts
├── dotfiles/                    # Shell/editor configs
├── infra/                       # Canonical infra configs + inventories
│   ├── compose/                 # Docker compose stacks
│   ├── cloudflare/              # DNS/tunnel exports
│   ├── data/                    # Machine-readable inventories
│   ├── templates/               # Templates/scaffolds
│   ├── networking/              # Network configs
│   ├── storage/                 # Storage configs
│   └── backups/                 # Backup configs
├── scripts/                     # Operational scripts
└── .archive/                    # Archived content (out of scope)
```

> **Spine session entry:** [`docs/governance/SESSION_PROTOCOL.md`](SESSION_PROTOCOL.md).
> Legacy workbench session docs are archived and should not be used at runtime.

---

## LAYER DEFINITIONS

Think in 4 layers: **Docs → Infra → Tooling → Ops**

| Layer | Folder | Contains | Examples |
|-------|--------|----------|----------|
| **Docs** | `docs/` | Core index + quarantined reference | `docs/infrastructure/`, `docs/legacy/` |
| **Infra** | `infra/` | Canonical configs + inventories | `infra/compose/`, `infra/data/`, `infra/cloudflare/` |
| **Tooling** | `bin/`, `scripts/`, `dotfiles/`, `bootstrap/` | CLI + local setup | `bin/ops`, `scripts/root/` |
| **Ops** | `docs/legacy/infrastructure/runbooks/` | Runbooks (read-only) | Backup/incident guides |

---

## EXTERNAL PILLARS (NOT IN WORKBENCH)

The workbench is **tooling only**. Product pillars live in other repos.
If any of these folders appear in workbench, it is drift:

- `mint-os/`
- `media-stack/`
- `finance/`
- `home-assistant/`
- `immich/`
- `modules/`
- `artwork-module/`

---

## FORBIDDEN AT ROOT

**NEVER create these at repository root:**

| Forbidden | Why | Put It In |
|-----------|-----|-----------|
| `logs/` | Transient | `.gitignore` or pillar-specific |
| `temp/`, `tmp/` | Transient | Don't commit |
| `misc/`, `notes/` | Junk drawer | Archive or delete |
| `old/`, `backup/` | Dead weight | `.archive/` |
| Any new top-level folder | Unreviewed drift | Update this doc first |

---

## REPO ROOT CANON (LOCKED)

> **Hard rule:** No new top-level folders without updating this document first.

### Allowed Root Entries (Exact)

| Entry | Type | Purpose |
|-------|------|---------|
| `.archive/` | dir | Archived content (out of scope) |
| `.git/` | dir | Git metadata |
| `.DS_Store` | file | macOS metadata (gitignored) |
| `.gitignore` | file | Git exclusions |
| `README.md` | file | Repo overview |
| `WORKBENCH_CONTRACT.md` | file | Canonical rules for this repo |
| `bin/` | dir | Entry points (ops/mint/work helpers) |
| `bootstrap/` | dir | Mac setup helpers |
| `docs/` | dir | Core index + legacy reference |
| `dotfiles/` | dir | Shell/editor configs |
| `infra/` | dir | Canonical infra configs + inventories |
| `agents/` | dir | Domain agent implementations (tools, configs, playbooks) |
| `scripts/` | dir | Operational scripts |

### Drift Check Command

Run this to verify no unexpected root entries exist:

```bash
TS="$(date +%F_%H%M)"
R="$HOME/code/workbench"
OUT="$R/docs/receipts/repo_root_drift_${TS}.log"
mkdir -p "$R/docs/receipts"

cd "$R" || exit 1

# Allowlist regex (update ONLY via PR to this doc)
ALLOW='^(\.git|\.archive|\.DS_Store|\.gitignore|README\.md|WORKBENCH_CONTRACT\.md|agents|bin|bootstrap|docs|dotfiles|infra|scripts)$'

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
| `*_AUTHORITY.md` | `docs/infrastructure/` (core) or `docs/governance/` (policy) | `docs/infrastructure/AUTHORITY_INDEX.md` |
| `*_RULES.md` | `docs/governance/` | `docs/governance/RAG_INDEXING_RULES.md` |
| `*_SOP.md` | `docs/governance/` | `docs/governance/ISSUE_CLOSURE_SOP.md` |
| `REF_*.md` | `docs/legacy/infrastructure/reference/` | `docs/legacy/infrastructure/reference/REF_PIHOLE.md` |
| `PLAN_*.md` | `docs/legacy/infrastructure/reference/plans/` | `docs/legacy/infrastructure/reference/plans/PLAN_AGENTS_2026-01-25.md` |
| `*_RUNBOOK.md` | `docs/legacy/infrastructure/runbooks/` | `docs/legacy/infrastructure/runbooks/BACKUP_PROTOCOL.md` |
| `*_RECEIPT.md` | `docs/receipts/` | `docs/receipts/SESSION_20260204-154330__core-gap-sweep.md` |

---

## THE 7 RULES (Enforce These)

1. **No orphan docs** — Every doc linked from an INDEX or pillar README
2. **Service docs live with service** — README + runbook links in each pillar
3. **Decisions are ADRs** — `docs/architecture/decisions/ADR-####-title.md`
4. **Runbooks are step-by-step** — Symptoms → Checks → Fix → Verify → Rollback
5. **One canonical inventory** — `docs/governance/SERVICE_REGISTRY.yaml`
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
| `WORKBENCH_TOOLING_INDEX.md` | External tooling references (read-only) |
| `mint-os/docs/reference/INDEX.md` | Pillar-specific doc catalog |
| `.githooks/pre-commit` | Enforces structure rules on commit |
| `.github/workflows/documentation-lint.yml` | Enforces naming conventions on PR |
