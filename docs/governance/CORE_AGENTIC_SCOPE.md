---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
scope: core-boundaries
---

# CORE Agentic Scope

**Version:** 1.0

---

## Core Invariants

Something is CORE if it strengthens at least one of these three invariants without introducing new runtime surface area:

### 1. Ingress
Mailroom/queue routing and processing:
- `SPINE_INBOX` → queued tasks
- `SPINE_OUTBOX` → completed work
- `SPINE_STATE` → ledger/locks/PIDs

### 2. Trace
Canonical audit trail per operation:
- Receipts per run (receipts/sessions/)
- Verifiable outputs (receipts can prove "what happened")
- Doctor/regression gate (surfaces/verify/)

### 3. Governance
Authoritative contracts, manifests, and SSOT:
- Authority definitions (docs/governance/AUTHORITY_INDEX.md)
- Service SSOT (docs/governance/SERVICE_REGISTRY.yaml)
- Governance manifest (docs/governance/manifest.yaml)
- Agent contracts (ops/agents/)
- Regression gate tests (`./bin/ops cap run spine.verify`)

---

## Core Requirements (ALL Must Be Met)

1. **Spine-Rooted**
   - All paths use SPINE_* environment variables:
     - `$SPINE_REPO` → `/Users/ronnyworks/code/agentic-spine`
     - `$SPINE_INBOX` → `$SPINE_REPO/mailroom/inbox`
     - `$SPINE_OUTBOX` → `$SPINE_REPO/mailroom/outbox`
     - `$SPINE_STATE` → `$SPINE_REPO/mailroom/state`
   - No hard-coded absolute paths like `~/ronny-ops`, `~/agent`, `/Users/ronnyworks/agent`

2. **Repo-Agnostic**
   - No runtime dependency on `ronny-ops` repo
   - No reference to `~/agent` legacy paths (documentation mentions OK)
   - No import of `mint-os` codepaths (service names OK)
   - Can operate independently of any other repository

3. **Auditable**
   - Has a contract, manifest, or receipt trail:
     - `CONTRACT.md` or `SKILL.md` (agent contracts)
     - YAML manifest with schema (governance)
     - Receipt showing why it was promoted (from `_imported/` → core)

---

## Core Directories (Authoritative)

These directories contain CORE assets that strengthen invariants:

### Operational Core
- `bin/` - Runtime commands (ops, doctor, verify)
- `ops/` - Operations library (scripts, utilities)
- `mailroom/` - Ingress routing (inbox/outbox/state)
- `receipts/` - Trace per run (canonical audit trail)

### Agent Core
- `ops/agents/` - Agent contracts (`<id>.contract.md`)
- `ops/bindings/agents.registry.yaml` - Agent catalog with routing rules
- Implementations live in workbench (`agents/<domain>/`) per AGENTS_LOCATION.md

### Verification Core
- `surfaces/verify/` - Verification surfaces (health checks, drift detection)

### Knowledge Core
- `docs/brain/` - Brain patterns (prompts, skills)
- `docs/governance/` - Authority, SSOT, contracts, runbooks

### Infrastructure Core
- `mcp/` - MCP servers (tool access layer, if proven to strengthen invariants)
- `infra/` - Infrastructure configs (if proven to strengthen invariants)

---

## Imported Reference (Non-Authoritative)

**Authority Rule (No Ambiguity):**
Only these locations can be authoritative:
- `docs/governance/`
- `docs/brain/`
- `ops/agents/`
- `surfaces/verify/`
- `bin/`
- `ops/`
- `ops/agents/`
- `receipts/`

Everything under `docs/**/_imported/` and `_imports/` is **never authoritative** (reference-only).

These directories contain reference materials that are NOT CORE yet:

### Knowledge Imports
- `docs/**/_imported/` - Reference docs from ronny-ops, mint-os, etc.
  - Example: `docs/governance/_imported/ronny-ops-infrastructure/`
  - These are read-only reference, not authoritative
  - May be promoted to core if they pass promotion tests
  - **Never referenced by runtime scripts except explicit doc pointers**

### Code Imports
- `_imports/` - Reference code from ronny-ops, etc.
  - Example: `_imports/ronny-ops-infrastructure/scripts/`
  - These are read-only reference, not executable
  - May be promoted to `ops/` or `ops/agents/` if they pass promotion tests
  - **No scripts run from `_imports/`**
  - **No PATH references to `_imports/`**
  - **No source calls from `_imports/`**

---

## Import Enforcement Rules

**Prevent Accidental Execution:**

### 1. `_imports/` is treated like an archive
- No scripts run from there
- No PATH references
- No source calls
- Anything executable must live in `bin/`, `ops/`, `ops/agents/`, `surfaces/verify/`, or `cli/bin/`

### 2. `docs/**/_imported/` is docs-only
- Never referenced by runtime scripts except explicit doc pointers (like brain table)
- Used for human or LLM reference only
- No executable code

### 3. Execution Boundary
Anything outside these paths is not runnable:
- `bin/` - Runtime commands
- `ops/` - Operations library
- `ops/agents/` - Active agents
- `surfaces/verify/` - Verification surfaces
- `cli/bin/` - CLI commands

---

## Promotion Rule

How something graduates from IMPORTED → CORE:

### Step 1: Coupling Scan (Must Pass)
```bash
cd $SPINE_REPO
rg -n "ronny-ops|~/agent|\$HOME/agent|/Users/ronnyworks/agent" _imports/ docs/**/_imported/
```
**Criteria:** Zero runtime dependencies (documentation mentions OK)

### Step 2: Invariant Strengthening (Must Pass)
**Question:** Does this asset improve at least one invariant?
- **Ingress:** Does it improve mailroom routing or queue processing?
- **Trace:** Does it improve receipt generation or audit trails?
- **Governance:** Does it improve doctor/regression gate, authority, or SSOT?

**Criteria:** At least one invariant must be strengthened

### Step 3: Spine-Rooted (Must Pass)
```bash
cd $SPINE_REPO
rg -n "^\s*~\/ronny-ops|^\s*\/Users\/ronnyworks\/ronny-ops" _imports/ docs/**/_imported/
```
**Criteria:** All paths use SPINE_REPO, SPINE_INBOX, SPINE_OUTBOX, SPINE_STATE

### Step 4: Auditable (Must Pass)
**Question:** Does the asset have a contract, manifest, or receipt trail?

**Criteria:** At least one of:
- CONTRACT.md or SKILL.md (agent contracts)
- YAML manifest with schema (governance)
- Receipt showing promotion rationale

### Step 5: Repo-Agnostic (Must Pass)
```bash
cd $SPINE_REPO
rg -n "hypnotizedent/ronny-ops" _imports/ docs/**/_imported/ | grep -v "Documentation mention"
```
**Criteria:** Zero runtime dependencies on ronny-ops repo (documentation mentions OK)

### Step 6: Receipt Creation
Create a receipt documenting the promotion:
- What was promoted
- Which invariant it strengthens
- Coupling scan results
- Path adaptations made
- Reason for promotion

### Step 7: Move to Core
```bash
# Example: Move from _imports/ to ops/
mv _imports/ronny-ops-infrastructure/scripts/my-script.sh ops/lib/scripts/
```

---

## Explicitly Forbidden

These are NEVER CORE and must NOT be imported:

### Domain Logic
- Mint OS business logic (quotes, customers, orders)
- N8N workflows for business automation
- Shopify/mint-os integration code

### Product Configs
- Dashboards (dashy/)
- Password manager (vaultwarden/)
- Storage (MinIO configs)
- DNS (PiHole configs)

### Personal Setup
- Shell aliases for personal use
- Hammerspoon configs
- Raycast scripts

### Historical Artifacts
- Audit reports
- Discovery sessions
- Export dumps

---

## Anti-Blackhole Policy

This document prevents "import everything" syndrome by requiring:

1. **Proof of Value:** Every promoted asset must strengthen an invariant
2. **No Hard Paths:** Everything must be spine-rooted
3. **No Dependencies:** Nothing can depend on ronny-ops or ~/agent
4. **Receipt Trail:** Every promotion must have a receipt showing why

**Result:** Spine remains focused on agentic CORE, not becoming a dumping ground for infrastructure configs.

---

## Core Readiness Checklist (Fast, Repeatable, Trust-Building)

Run this whenever you import anything, even docs:

### A) Gate Stays Green
```bash
cd ~/code/agentic-spine && ./surfaces/verify/foundation-gate.sh
```
**Criteria:** All checks pass (no failures or warnings)

### B) Confirm Imports Are Non-Executable
```bash
cd ~/code/agentic-spine
find _imports docs -path "*/_imported/*" -type f -name "*.sh" -print
```
**Criteria:** Should be empty OR explicitly understood as reference-only docs/scripts

### C) Coupling Scan for Imported Payload
```bash
cd ~/code/agentic-spine
rg -n "(~/agent|\\$HOME/agent|ronny-ops|\\$HOME/ronny-ops)" docs/governance/_imported _imports ops/agents/ || true
```
**Criteria:** Zero runtime dependencies (documentation mentions OK)

### D) Authority Boundary Check
```bash
cd ~/code/agentic-spine
ls -la docs/governance/_imported/
ls -la _imports/
```
**Criteria:** Only reference materials, no executable code paths

---

## Invariant Statement (Anchor)

**CORE is only what improves Ingress, Trace, or Governance and can be proven by a repeatable command that produces a receipt inside receipts/sessions/.**

This is spine's "immune system."

---

## Examples

### Example 1: Governance Doc (CORE NOW)
**Asset:** `docs/governance/AUTHORITY_INDEX.md`
**Why CORE:** Strengthens Governance invariant
**Checklist:**
- ✅ Spine-rooted (uses SPINE_INBOX/OUTBOX/STATE)
- ✅ Repo-agnostic (no ronny-ops dependency)
- ✅ Auditable (has clear contract)
- ✅ Strengthens Governance (defines authority)

---

### Example 2: SSH Config (IMPORT ONLY)
**Asset:** `dotfiles/ssh/config`
**Why IMPORT ONLY:** Does NOT strengthen invariants
**Checklist:**
- ✅ Spine-rooted (no hard paths)
- ✅ Repo-agnostic (SSH configs are generic)
- ✅ Auditable (has README)
- ❌ Does NOT strengthen Ingress/Trace/Governance

**Promotion Required:** Prove it helps Governance (SSH access for verification surfaces)

---

### Example 3: N8N Workflow (IGNORE)
**Asset:** `n8n/workflows/Mint_OS_-_New_Order_Alert.json`
**Why IGNORE:** Domain logic (mint-os business)
**Checklist:**
- ✅ Spine-rooted (no hard paths)
- ✅ Repo-agnostic (no ronny-ops dependency)
- ✅ Auditable (has JSON schema)
- ❌ Imports domain logic (mint-os business rules)
- ❌ Does NOT strengthen Ingress/Trace/Governance

**Decision:** Never import (belongs in ronny-ops, not spine)

---

## Reference Audit: ronny-ops/workbench Mentions

Audit of 120+ `ronny-ops` and `workbench` references across the docs tree
(performed 2026-02-04). Each reference was categorized and given a treatment:

| Category | Count | Treatment | Examples |
|----------|-------|-----------|----------|
| Constraints/guards | ~25 | KEEP | AGENT_CONTRACT, CORE_LOCK, D5 |
| Verification gates | ~32 | KEEP | d16, d18, docs-lint |
| Historical audit | ~34 | KEEP | _audits/\*, legacy/\* |
| Extraction tracking | ~22 | KEEP | AGENTIC_GAP_MAP, STACK_ALIGNMENT |
| Stale instructions | 7 | FIXED | AGENTS_GOVERNANCE, REPO_STRUCTURE_AUTHORITY, SCRIPTS_AUTHORITY, INFRASTRUCTURE_MAP, GOVERNANCE_INDEX, brain/README, issue.md |

**Decision:** Constraint declarations, verification gates, historical audits, and
extraction tracking references are intentional and remain as-is. Only the 7 docs
carrying actionable ronny-ops instructions were edited to add workbench callouts
or update scope references to `agentic-spine`.

---

## Version History

| Version | Date | Changes |
|---------|------|----------|
| 1.0 | 2026-02-01 | Initial version - defines CORE invariants and promotion rules |
| 1.1 | 2026-02-01 | Added authority rule, import enforcement, core-readiness checklist, invariant statement |
| 1.2 | 2026-02-04 | Added reference audit table for ronny-ops/workbench mentions |
| 1.3 | 2026-02-08 | GAP-OP-046: agents/active/ → ops/agents/, agents/contracts/ → ops/agents/. Implementations in workbench per AGENTS_LOCATION.md |
