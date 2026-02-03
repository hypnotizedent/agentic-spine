---
status: authoritative
owner: "@ronny"
last_verified: 2026-01-24
scope: governance-guide
github_issue: "#541"
---

# Governance Index

> **Purpose:** Human-readable guide to how governance works in ronny-ops.
> 
> This is the entry point for understanding rules, authority, and conflict resolution.

---

## Quick Start: The Entry Chain

Every agent session follows this path:

```
00_CLAUDE.md              ← START HERE: Session protocol
    ↓
.brain/rules.md           ← The 5 rules (auto-injected at startup)
    ↓
AGENTS.md / CLAUDE.md     ← Full agent instructions
    ↓
Pillar entrypoints        ← Domain-specific context
    ├── mint-os/AGENTS_START_HERE.md
    ├── infrastructure/SERVICE_REGISTRY.md
    ├── media-stack/MEDIA_STACK_CONTEXT.md
    └── (other pillars)/*_CONTEXT.md
```

**The 5 Rules:**
1. NO ISSUE = NO WORK → `gh issue list --state open`
2. NO GUESSING = RAG FIRST → `mint ask "question"`
3. NO INVENTING → match existing patterns
4. FIX ONE THING → verify before next
5. UPDATE MEMORY → Ctrl+9 when done

---

## What Documents Exist

### Governance (Cross-Pillar Rules)

| Document | Purpose |
|----------|---------|
| `SSOT_REGISTRY.yaml` | Machine-readable list of all SSOTs |
| `REPO_STRUCTURE_AUTHORITY.md` | Where folders/files belong |
| `COMPOSE_AUTHORITY.md` | Authoritative compose file per stack |
| `PORTABILITY_ASSUMPTIONS.md` | Environment coupling + mount/IP assumptions |
| `MD_SURFACE_AUDIT.md` | Markdown sprawl audit + cleanup candidates |
| `SEARCH_EXCLUSIONS.md` | What's excluded from search/RAG |
| `RAG_INDEXING_RULES.md` | What gets indexed to RAG |
| `ISSUE_CLOSURE_SOP.md` | How to close issues properly |
| `AGENT_BOUNDARIES.md` | What agents can/cannot do |
| `SUPERVISOR_CHECKLIST.md` | Verify work before shipping |

### Single Sources of Truth (by Domain)

| Domain | SSOT | Scope |
|--------|------|-------|
| Services/Topology | `infrastructure/SERVICE_REGISTRY.md` | What runs where |
| Database Schema | `mint-os/docs/SCHEMA_TRUTH.md` | Column names, tables |
| Quote System | `mint-os/docs/QUOTE_SINGLE_SOURCE_OF_TRUTH.md` | Quote creation flow |
| Shopify | `infrastructure/shopify-mcp/SHOPIFY_SSOT.md` | Shopify integration |
| Files/MinIO | `mint-os/docs/modules/files/SPEC.md` | File upload/storage |
| Incidents | `infrastructure/docs/INCIDENTS_LOG.md` | What failed before |
| Agents | `infrastructure/data/agents_inventory.json` | Agent scripts registry |
| Updates | `infrastructure/data/updates_inventory.json` | Update mechanisms registry |

For the complete list: `cat docs/governance/SSOT_REGISTRY.yaml`

---

## Resolving Conflicts

When two documents disagree, use this process:

### Step 1: Check SSOT_REGISTRY.yaml

```bash
# Find both documents in the registry
yq '.ssots[] | select(.path | contains("SERVICE_REGISTRY"))' docs/governance/SSOT_REGISTRY.yaml
yq '.ssots[] | select(.path | contains("SCHEMA_TRUTH"))' docs/governance/SSOT_REGISTRY.yaml
```

### Step 2: Compare Priority

Lower priority number wins:
- Priority 1 = Foundational (SERVICE_REGISTRY, SCHEMA_TRUTH, REPO_STRUCTURE)
- Priority 2 = Domain-specific (QUOTE_SSOT, SHOPIFY_SSOT, FILES_SPEC)
- Priority 3 = Operational (RAG rules, exclusions)
- Priority 4 = Index/pointers (AUTHORITY_INDEX, this doc)

### Step 3: Check Scope

Each SSOT has a defined scope. If question is outside the scope, defer to the other doc.

### Step 4: Check Dates

If same priority and overlapping scope, more recently reviewed doc is likely correct.

### Step 5: Escalate

If still unclear, create an issue and tag @ronny.

---

## Conflict Resolution Example

**Scenario:** Agent finds conflicting port numbers:
- `SERVICE_REGISTRY.md` says MinIO is on port 9000
- Some old doc says MinIO is on port 9005

**Resolution:**

1. Check registry:
   ```bash
   yq '.ssots[] | select(.id == "service-registry")' docs/governance/SSOT_REGISTRY.yaml
   # Returns: priority: 1, scope: services-topology
   ```

2. SERVICE_REGISTRY has priority 1 and scope includes "Where services run"

3. **Decision:** Port 9000 is correct. The old doc is wrong.

4. **Action:** Fix or archive the old doc.

---

## Search and RAG Exclusions

### What's Excluded

Defined in `docs/governance/SEARCH_EXCLUSIONS.md`:

| Pattern | Reason |
|---------|--------|
| `.worktrees/` | Git worktree duplicates (1,484+ md files) |
| `*/.archive/` | Deprecated content (559+ docs) |
| `node_modules/` | Dependencies |
| `.git/` | Git internals |

### Where Exclusions Are Configured

| System | Config |
|--------|--------|
| Git | `.gitignore` |
| RAG | `infrastructure/docs/rag/WORKSPACE_MANIFEST.json` |
| Scripts | Various `--exclude` flags |

### Verifying Exclusions Work

```bash
# Should return nothing (excluded from search)
find . -path "*/.worktrees/*" -name "*.md" 2>/dev/null | head -5

# Check RAG manifest
jq '.criticalPatterns.excludes' infrastructure/docs/rag/WORKSPACE_MANIFEST.json
```

---

## When in Doubt: Decision Tree

```
START: Agent has a question about "truth"
    │
    ├─▶ Is there a GitHub Issue for this?
    │       NO → Create issue first: `gh issue create`
    │      YES ↓
    │
    ├─▶ Does RAG have an answer?
    │       → `mint ask "your question"`
    │       YES → Follow RAG answer (check sources)
    │       NO ↓
    │
    ├─▶ Is there an SSOT for this domain?
    │       → Check SSOT_REGISTRY.yaml
    │       YES → That SSOT wins
    │       NO ↓
    │
    ├─▶ Is there an authoritative doc?
    │       → Check AUTHORITY_INDEX.md
    │       YES → Use that doc
    │       NO ↓
    │
    ├─▶ Check git history for most recent change
    │       → `git log --oneline -- <file>`
    │       FOUND → More recent is likely correct
    │       NO ↓
    │
    └─▶ Escalate: Create issue, tag @ronny
```

---

## SSOT Claims Guardrail

### What IS an SSOT Claim

An SSOT (Single Source of Truth) claim means a document asserts:
- "This is THE definitive source for X"
- Other documents on this topic defer to this one
- Conflicts are resolved in favor of this document

**Indicators of an SSOT claim:**
- Front-matter with `status: authoritative`
- Phrases like "single source of truth", "THE definitive", "this document wins"
- Document name contains `SSOT`, `TRUTH`, `AUTHORITY`, `REGISTRY`

### What is NOT an SSOT

| Type | Example | Why Not SSOT |
|------|---------|--------------|
| Reference doc | `docs/reference/api-examples.md` | Informational, not authoritative |
| Session handoff | `docs/sessions/2026-01-24.md` | Ephemeral, not canonical |
| Archive content | `*/.archive/*` | Historical, explicitly non-authoritative |
| README files | `module/README.md` | Entrypoint, not truth source |
| Index/pointer docs | `AUTHORITY_INDEX.md` | Points to SSOTs, is not itself one |

### Hard Rule: Register or Remove

> **If a document claims SSOT status, it MUST be in `docs/governance/SSOT_REGISTRY.yaml`.**
>
> Unregistered SSOT claims are invalid. Either:
> 1. Register the document in SSOT_REGISTRY.yaml, OR
> 2. Remove the SSOT claim from the document

### Before Declaring Authority (Checklist)

Before adding `status: authoritative` or claiming SSOT:

- [ ] **Scope defined?** — What specific questions does this document answer?
- [ ] **No overlap?** — Check `SSOT_REGISTRY.yaml` for existing SSOTs in this scope
- [ ] **Priority assigned?** — Tier 1 (foundational), 2 (domain), 3 (operational), or 4 (index)?
- [ ] **Owner identified?** — Who maintains this document?
- [ ] **Front-matter complete?** — `status`, `owner`, `last_verified`, `scope`, `github_issue`
- [ ] **Registered?** — Entry added to `SSOT_REGISTRY.yaml`
- [ ] **RAG indexed?** — Run `mint index` after adding

### Enforcement

**Manual (current):**
- Pre-commit hook warns on missing issue references (signals governance review)
- PR reviewers should check: "Does this introduce a new SSOT claim? Is it registered?"

**Recommended PR checklist item:**
```
- [ ] No new SSOT claims, OR new claims registered in SSOT_REGISTRY.yaml
```

### Related Documents

| Document | Purpose |
|----------|---------|
| [docs/DOC_MAP.md](../DOC_MAP.md) | Navigation SSOT (start here) |
| [SSOT_REGISTRY.yaml](SSOT_REGISTRY.yaml) | Machine-readable SSOT list |
| [ARCHIVE_POLICY.md](ARCHIVE_POLICY.md) | What archived means |
| [infrastructure/docs/AUTHORITY_INDEX.md](../../infrastructure/docs/AUTHORITY_INDEX.md) | Document registry |

---

## Maintaining Governance

### Adding a New SSOT

1. Create the document with proper front-matter:
   ```yaml
   ---
   status: authoritative
   owner: "@ronny"
   last_verified: YYYY-MM-DD
   scope: your-scope
   ---
   ```

2. Add entry to `SSOT_REGISTRY.yaml`

3. Update this index if needed

4. Re-index RAG: `mint index`

### Removing/Archiving an SSOT

1. Update `SSOT_REGISTRY.yaml`: set `archived: true`

2. Move doc to `.archive/` folder

3. Update any docs that reference it

4. Re-index RAG

### Monthly Review

- [ ] Check all SSOTs have `last_verified` within 60 days
- [ ] Run `./scripts/agents/doc-drift-check.sh` if it exists
- [ ] Update stale docs or archive them

---

## Related Documents

| Document | Relationship |
|----------|--------------|
| `SSOT_REGISTRY.yaml` | Machine-readable version of SSOT list |
| `AUTHORITY_INDEX.md` | Older doc registry (being superseded) |
| `REPO_STRUCTURE_AUTHORITY.md` | Where files belong |
| `SEARCH_EXCLUSIONS.md` | What's excluded from search |
| `00_CLAUDE.md` | Session entry point |

---

## Changelog

| Date | Change | Issue |
|------|--------|-------|
| 2026-01-24 | Added SSOT Claims Guardrail section | #541 |
| 2026-01-23 | Created as part of Agent Clarity epic | #541 |

<!-- AUTO: GOVERNANCE_DOC_INDEX_START -->

## Appendix: Governance document index (auto)

> This appendix is generated to ensure every governance doc is discoverable from the authority chain.
> The sections above remain the curated authority narrative; this list is an index only.

- `AGENT_BOUNDARIES.md`
- `ARCHIVE_POLICY.md`
- `CI_PORTABILITY.md`
- `CI_RUNNER_REQUIREMENTS.md`
- `COMPOSE_AUTHORITY.md`
- `COMPOSE_DUPES.md`
- `INFRASTRUCTURE_AUTHORITY.md`
- `INGRESS_AUTHORITY.md`
- `ISSUE_CLOSURE_SOP.md`
- `MD_SURFACE_AUDIT.md`
- `MINT_OS_COMPOSE_LAYERS.md`
- `PORTABILITY_ASSUMPTIONS.md`
- `RAG_INDEXING_RULES.md`
- `README.md`
- `REPO_STRUCTURE_AUTHORITY.md`
- `SCRIPTS_AUTHORITY.md`
- `SEARCH_EXCLUSIONS.md`
- `SECRETS_POLICY.md`
- `SPEC_REQUIRED_SOP.md`
- `STACK_AUTHORITY.md`

<!-- AUTO: GOVERNANCE_DOC_INDEX_END -->

