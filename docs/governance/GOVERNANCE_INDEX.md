---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
scope: governance-guide
github_issue: "#541"
---

# Governance Index

> **Purpose:** Human-readable guide to how governance works in agentic-spine.
>
> This is the entry point for understanding rules, authority, and conflict resolution.
>
> **Stack governance:** `docs/governance/STACK_REGISTRY.yaml` is the spine's SSOT
> for stack inventory (what stacks exist, compose paths, owners, status).

---

## Quick Start: The Entry Chain

> **Spine root:** `/Users/ronnyworks/code/agentic-spine`  
> **Entry doc:** [`docs/governance/SESSION_PROTOCOL.md`](SESSION_PROTOCOL.md) is the session protocol for the spine. Read it before doing anything else in this repo.

Every agent session in the spine follows this path:

```
/Users/ronnyworks/code/agentic-spine/docs/governance/SESSION_PROTOCOL.md ← START HERE: Session protocol
    ↓
/Users/ronnyworks/code/agentic-spine/docs/brain/README.md     ← Brain rules, hotkeys, and context injection helpers
    ↓
/Users/ronnyworks/code/agentic-spine/docs/governance/GOVERNANCE_INDEX.md ← Governance overview + SSOT mapping
    ↓
Pillar entrypoints (per stack)
    ├── /Users/ronnyworks/code/agentic-spine/docs/governance/SSOT_REGISTRY.yaml
    ├── /Users/ronnyworks/code/agentic-spine/docs/governance/REPO_STRUCTURE_AUTHORITY.md
    ├── /Users/ronnyworks/code/agentic-spine/docs/governance/AGENTS_GOVERNANCE.md
    └── other SSOTs listed in `SSOT_REGISTRY.yaml`
```

Startup read surface (D26 lock):
- `docs/governance/SESSION_PROTOCOL.md`
- `docs/governance/AGENT_GOVERNANCE_BRIEF.md`

**The 5 Rules:**
1. NO OPEN LOOPS = NO WORK → `./bin/ops loops list --open`
2. NO GUESSING = SSOT FIRST → direct file read → `rag_query` (spine-rag MCP) → `rg` fallback
3. NO INVENTING → match existing patterns
4. FIX ONE THING → verify before next
5. WORK GENERATES RECEIPTS → `./bin/ops cap run <name>`

## Gate Domain Routing (Terminal-First)

Use domain packs to discover which drift gates apply before mutation work.

- Canonical map: `ops/bindings/gate.domain.profiles.yaml`
- Domains: `core`, `secrets`, `aof`, `home`, `media`, `rag`, `workbench`, `infra`, `loop_gap`
- Terminal default: `OPS_GATE_DOMAIN` unset → `core`

Commands:

```bash
./bin/ops cap run verify.drift_gates.certify --list-domains
./bin/ops cap run verify.drift_gates.certify --domain "${OPS_GATE_DOMAIN:-core}" --brief
```

---

## Infrastructure Canon (8 Required-Reading Docs)

> **⚠️ Read This Before Opening Any Infrastructure Doc**
>
> The workbench monolith contains **120+ infrastructure docs** copied from legacy repos.
> Most are historical captures with no spine-native meaning. **Do not read those docs
> unless you're auditing.**
>
> The **only execution-worthy infrastructure docs** are the 8 spine-native files below.
> Everything else is external reference—query the workbench directly if you need it.

| # | Spine-Native Doc | What It Governs |
|---|------------------|-----------------|
| 1 | [SESSION_PROTOCOL.md](SESSION_PROTOCOL.md) | Entry point/checklist for every agent session |
| 2 | [GOVERNANCE_INDEX.md](GOVERNANCE_INDEX.md) | Roadmap to SSOTs + legacy reference callout (this file) |
| 3 | [REPO_STRUCTURE_AUTHORITY.md](REPO_STRUCTURE_AUTHORITY.md) | Where files/folders belong |
| 4 | [LEGACY_DEPRECATION.md](LEGACY_DEPRECATION.md) | How legacy docs can be promoted to spine authority |
| 5 | [SSOT_REGISTRY.yaml](SSOT_REGISTRY.yaml) | Machine-readable authority registry |
| 6 | [MAILROOM_RUNBOOK.md](MAILROOM_RUNBOOK.md) | Queue operations, ledger, logs, health checks |
| 7 | [SECRETS_POLICY.md](SECRETS_POLICY.md) | Secrets management rules + Infisical binding |
| 8 | [SERVICE_REGISTRY.yaml](SERVICE_REGISTRY.yaml) | Services topology + health check definitions |

**For infrastructure details beyond these 8 docs:**
- Treat workbench as read-only reference and follow [WORKBENCH_TOOLING_INDEX.md](WORKBENCH_TOOLING_INDEX.md) (approved external paths + the canonical `rg` pattern)
- Or check the spine's bindings: `ops/bindings/*.yaml` (authoritative when used by runtime/gates)

---

## What Documents Exist

### Governance (Cross-Pillar Rules)

| Document | Purpose |
|----------|---------|
| `SSOT_REGISTRY.yaml` | Machine-readable list of all SSOTs |
| `REPO_STRUCTURE_AUTHORITY.md` | Where folders/files belong |
| `COMPOSE_AUTHORITY.md` | Authoritative compose file per stack |
| `PORTABILITY_ASSUMPTIONS.md` | Environment coupling + mount/IP assumptions |
| `SEARCH_EXCLUSIONS.md` | What's excluded from search/RAG |
| `RAG_INDEXING_RULES.md` | What gets indexed to RAG |
| `RAG_REINDEX_RUNBOOK.md` | Governed RAG reindex checklist and acceptance criteria |
| `RAG_PASSIVE_PIPELINE_PROTOCOL.md` | Passive RAG lifecycle contract: normalized metrics, auto-trigger, auto-closeout |
| `ISSUE_CLOSURE_SOP.md` | How to close issues properly |
| `GIT_REMOTE_AUTHORITY.md` | Canonical git authority (Gitea primary, GitHub mirror-only) |
| `OUTPUT_CONTRACTS.md` | Canonical schemas for loop scopes, gap filings, proposals, gate templates |
| `AGENT_GOVERNANCE_BRIEF.md` | Agent operational session rules (commits, capabilities, drift gates) |
| `AGENTS_GOVERNANCE.md` | Agent infrastructure governance (registry, contracts, discovery, verification) |
| `AGENT_BOUNDARIES.md` | Agent action boundary constraints (what agents can/cannot do) |
| `MAILROOM_RUNBOOK.md` | Queue operations, ledger, logs, health checks |
| `MAILROOM_BRIDGE.md` | Governed remote API bridge (read outbox/receipts, enqueue prompts) |
| `ORCHESTRATION_CAPABILITY.md` | Machine-enforced orchestration contract and strict terminal entry behavior |
| `TERMINAL_C_DAILY_RUNBOOK.md` | Control-plane orchestration runbook for multi-lane fan-out/fan-in |
| `WORKER_LANE_TEMPLATE_PACK.md` | Canonical worker lane prompt templates and handoff contract |
| `OPENCODE_GOVERNED_ENTRY.md` | Governed OpenCode launch/model/provider contract for entry consistency |
| `HOST_DRIFT_POLICY.md` | Host drift contract for `/Users/ronnyworks` stabilization |
| `POST_GAP_OPERATING_MODEL.md` | Canonical stabilization contract, lifecycle templates, ownership model, and 30/60/90 roadmap |
| `BUILD_MODE_CHECKLIST.md` | Operator stop-gated checklist for predictable build-mode execution |
| `ONBOARDING_PLAYBOOK.md` | Standard onboarding workflow for VM/agent/capability/tool/surface changes |
| `GAP_LIFECYCLE.md` | Gap registry lifecycle, mutation capabilities, claim semantics, D75 lock |
| `RUNWAY_TOOLING_PRODUCT_OPERATING_CONTRACT_V1.md` | Cross-repo operating contract for stable parallel execution across spine/workbench/mint-modules |
| `WORKBENCH_SHARE_PROTOCOL.md` | Governance for publishing curated workbench content to GitHub share channel |
| `ARCHIVE_POLICY.md` | Archive directory governance: retention, cleanup cadence, reader expectations |
| `AGENT_TERMINOLOGY_GLOSSARY.md` | Canonical definitions for overloaded "agent" terms in the spine |

### Share Channel Governance

| Document | Purpose |
|----------|---------|
| `WORKBENCH_SHARE_PROTOCOL.md` | One-way publish flow, security boundaries, roles for GitHub share channel |
| `ops/bindings/share.publish.allowlist.yaml` | Paths safe to publish to share channel |
| `ops/bindings/share.publish.denylist.yaml` | Patterns blocked from share channel (secrets, identity, infra) |

### Post-Gap Stabilization Governance

| Document | Purpose |
|----------|---------|
| `POST_GAP_OPERATING_MODEL.md` | Defines hardening pass/fail contract, ownership boundaries, lifecycle standards, and 30/60/90 execution plan |
| `BUILD_MODE_CHECKLIST.md` | Fast operator checklist with stop gates and definition-of-done by change shape |
| `ONBOARDING_PLAYBOOK.md` | Canonical onboarding flow and required evidence for VM/agent/capability/tool/surface additions |
| `ops/bindings/lifecycle.standards.yaml` | Enforceable lifecycle schema/defaults for onboarding work types |
| `ops/bindings/change.intake.policy.yaml` | Deterministic intake policy for `cap run` vs `run --inline` vs proposal flow |
| `ops/bindings/audit.suppressions.policy.yaml` | Time-bounded suppression policy for noise control without masking risk |
| `ops/bindings/proposals.lifecycle.yaml` | Proposal state machine, required fields per status, SLA thresholds, and archive rules |

### Backup & Recovery

| Document | Purpose | Status |
|----------|---------|--------|
| `BACKUP_GOVERNANCE.md` | Backup freshness rules and retention | authoritative |
| `AUTHENTIK_BACKUP_RESTORE.md` | Authentik app-level backup/restore procedure | authoritative |
| `GITEA_BACKUP_RESTORE.md` | Gitea app-level backup/restore procedure | authoritative |
| `INFISICAL_BACKUP_RESTORE.md` | Infisical app-level backup/restore procedure | authoritative |
| `INFISICAL_RESTORE_DRILL.md` | Quarterly restore drill to validate backup/restore runbook accuracy | authoritative |
| `DR_RUNBOOK.md` | Per-site failure scenarios, dependency map, recovery priority | authoritative |
| `RTO_RPO.md` | Recovery time/point objectives per service tier | authoritative |

### Policy Skeletons (Draft)

| Document | Covers | Status |
|----------|--------|--------|
| `SECURITY_POLICIES.md` | SSH hardening, firewall, NFS, access control, Tailscale audit, secrets rotation | draft |
| `NETWORK_POLICIES.md` | Tailscale ACLs, subnet registry, DNS strategy, WAN, segmentation | draft |
| `PATCH_CADENCE.md` | OS/container/firmware update schedules, version tracking | draft |

### Architecture (Derived)

| Document | Purpose | Status |
|----------|---------|--------|
| `SHOP_VM_ARCHITECTURE.md` | Single doc overview of post-`docker-host` decomposition (roles of infra-core/observability/dev-tools/AI/automation/media split) | authoritative (derived) |

### Single Sources of Truth (by Domain)

> **Spine-native SSOTs:** For the canonical registry of spine-governed SSOTs, see [SSOT_REGISTRY.yaml](SSOT_REGISTRY.yaml).

| Domain | SSOT | Scope |
|--------|------|-------|
| Session Entry | `docs/governance/SESSION_PROTOCOL.md` | Agent startup protocol |
| Repo Structure | `docs/governance/REPO_STRUCTURE_AUTHORITY.md` | Where files belong |
| Stacks | `docs/governance/STACK_REGISTRY.yaml` | Stack inventory |
| Device Identity | `docs/governance/DEVICE_IDENTITY_SSOT.md` | Device naming/IPs |
| Workstation | `docs/governance/MACBOOK_SSOT.md` | MacBook baseline (hardware + local services) |
| Workstation Bootstrap | `docs/governance/MACBOOK_BOOTSTRAP_CONTRACT.md` | Fresh-Mac bootstrap requirements + ownership |
| Home Minilab | `docs/governance/MINILAB_SSOT.md` | Home baseline (Beelink + NAS + home VMs/LXCs) |
| Shop Rack | `docs/governance/SHOP_SERVER_SSOT.md` | Shop baseline (R730XD + switch + NVR + UPS) |
| Shop Network (Target) | `docs/governance/SHOP_NETWORK_NORMALIZATION.md` | Normalized IP structure + anti-drift rules |
| Shop Network Audit | `docs/governance/SHOP_NETWORK_AUDIT_RUNBOOK.md` | Canonical audit + fix workflow (live truth + doc trace) |
| Secrets Policy | `docs/governance/SECRETS_POLICY.md` | Secrets management |
| Agent Boundaries | `docs/governance/AGENT_BOUNDARIES.md` | What agents can/cannot do |
| Scripts Registry | `docs/governance/SCRIPTS_REGISTRY.md` | Canonical scripts index |
| Workbench Share | `docs/governance/WORKBENCH_SHARE_PROTOCOL.md` | GitHub share channel governance |
| Post-Gap Stabilization | `docs/governance/POST_GAP_OPERATING_MODEL.md` | Hardened operating contract after gap closure |

For the complete list: `cat docs/governance/SSOT_REGISTRY.yaml`

### Shop Network Anti-Drift Entry Point

Before performing any shop network change, run:

```bash
./bin/ops cap run network.shop.audit.status
```

This enforces parity between:
- `ops/bindings/ssh.targets.yaml`
- `docs/governance/DEVICE_IDENTITY_SSOT.md`
- `docs/governance/SHOP_SERVER_SSOT.md`

It is also enforced during `spine.verify` by drift gate D54.

### Host Infrastructure Update Contract

When updating infrastructure facts, route changes through the smallest canonical surface:

- Host/location detail (hardware, storage, cron, capacity, topology): `MACBOOK_SSOT.md`, `MINILAB_SSOT.md`, `SHOP_SERVER_SSOT.md`
- Identity map (hostnames, tiers, Tailscale/LAN IPs): `DEVICE_IDENTITY_SSOT.md` only when identity facts change
- Service map (service name, host binding, port, health route): `SERVICE_REGISTRY.yaml` only when service facts change

Workflow reference: `SSOT_UPDATE_TEMPLATE.md`

---

## Legacy References (External — Read-Only)

> **⚠️ External Repository References (Read-Only)**
>
> The workbench monolith contains a large documentation tree (runbooks, audits,
> architecture docs, reference guides, historical captures). **These are NOT
> governed by the spine.**
>
> **Do not execute commands or act on external doc paths from within a spine session.**
> If you need infrastructure answers beyond the spine-native docs above, treat workbench
> as **read-only reference** and use the **path-scoped search pattern** documented in
> [WORKBENCH_TOOLING_INDEX.md](WORKBENCH_TOOLING_INDEX.md) (no RAG, no CWD change).
>
> If the result influences work, capture it as a receipt first:
> `./bin/ops run --inline "External reference consulted: <what> (paths + findings)"`.
>
> See [LEGACY_DEPRECATION.md](LEGACY_DEPRECATION.md) for the full policy.
>
> **Tooling Index:** External references are allowed only via
> [WORKBENCH_TOOLING_INDEX.md](WORKBENCH_TOOLING_INDEX.md).

**Allowed external tooling:** See [WORKBENCH_TOOLING_INDEX.md](WORKBENCH_TOOLING_INDEX.md) for the complete list of approved workbench entry points.

**Historical references:** Audit files under `docs/governance/_audits/` may contain paths
to the deprecated `ronny-ops` repository. These are point-in-time captures for historical
context only. See the disclaimer in each audit file.

---

## Resolving Conflicts

When two documents disagree, use this process:

### Step 1: Check SSOT_REGISTRY.yaml

```bash
# Find both documents in the registry
yq '.ssots[] | select(.id == "service-registry")' docs/governance/SSOT_REGISTRY.yaml
yq '.ssots[] | select(.id == "secrets-policy")' docs/governance/SSOT_REGISTRY.yaml
```

### Step 2: Compare Priority

Lower priority number wins:
- Priority 1 = Foundational (SERVICE_REGISTRY, REPO_STRUCTURE, SESSION_PROTOCOL)
- Priority 2 = Domain-specific (SECRETS_POLICY, MAILROOM_RUNBOOK, BACKUP_GOVERNANCE)
- Priority 3 = Operational (RAG rules, exclusions)
- Priority 4 = Index/pointers (this doc)

### Step 3: Check Scope

Each SSOT has a defined scope. If question is outside the scope, defer to the other doc.

### Step 4: Check Dates

If same priority and overlapping scope, more recently reviewed doc is likely correct.

### Step 5: Escalate

If still unclear, create an issue and tag @ronny.

---

## Conflict Resolution Example

**Scenario:** Agent finds conflicting service endpoint values:
- `SERVICE_REGISTRY.yaml` has one endpoint value
- Some old doc shows a different endpoint value

**Resolution:**

1. Check registry:
   ```bash
   yq '.ssots[] | select(.id == "service-registry")' docs/governance/SSOT_REGISTRY.yaml
   # Returns: priority: 1, scope: services-topology
   ```

2. SERVICE_REGISTRY has priority 1 and scope includes "Where services run"

3. **Decision:** `SERVICE_REGISTRY.yaml` is correct. The old doc is wrong.

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

| System | Config | Notes |
|--------|--------|-------|
| Git | `.gitignore` | Spine-native |
| RAG | `~/code/workbench/.../WORKSPACE_MANIFEST.json` | External (see Legacy References) |
| Scripts | Various `--exclude` flags | Per-script |

### Verifying Exclusions Work

```bash
# Should return nothing (excluded from search)
find . -path "*/.worktrees/*" -name "*.md" 2>/dev/null | head -5
```

> **Note:** RAG manifest lives in the workbench monolith. See the Legacy References
> section above for the external SSOT policy.

---

## When in Doubt: Decision Tree

```
START: Agent has a question about "truth"
    │
    ├─▶ Is there an open loop for this?
    │       NO → Create loop via `./bin/ops cap run loops.create`
    │      YES ↓
    │
    ├─▶ Can you answer via SSOT/docs/RAG/search?
    │       → Check SSOTs, then `rag_query`, then `rg -n "<query>" docs ops`
    │       YES → SSOT wins (verify with receipts/capabilities when relevant)
    │       NO ↓
    │
    ├─▶ Is there an SSOT for this domain?
    │       → Check SSOT_REGISTRY.yaml
    │       YES → That SSOT wins
    │       NO ↓
    │
    ├─▶ Is there an authoritative doc?
    │       → Check this GOVERNANCE_INDEX
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
| Index/pointer docs | `GOVERNANCE_INDEX.md` | Points to SSOTs, is not itself one |

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
| [SSOT_REGISTRY.yaml](SSOT_REGISTRY.yaml) | Machine-readable SSOT list |
| [LEGACY_DEPRECATION.md](LEGACY_DEPRECATION.md) | Legacy/external reference policy |

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
| `ACTIVE_DOCS_INDEX.md` | Merged into `_index.yaml` (tombstoned 2026-02-13) |
| `REPO_STRUCTURE_AUTHORITY.md` | Where files belong |
| `SEARCH_EXCLUSIONS.md` | What's excluded from search |
| `docs/governance/SESSION_PROTOCOL.md` | Session entry point |
| `docs/governance/POST_GAP_OPERATING_MODEL.md` | Post-gap stability contract and lifecycle governance |
| `docs/governance/BUILD_MODE_CHECKLIST.md` | Build-mode execution checklist with stop-gates |
| `docs/governance/ONBOARDING_PLAYBOOK.md` | Onboarding commands and completion criteria |
| `docs/governance/RUNWAY_TOOLING_PRODUCT_OPERATING_CONTRACT_V1.md` | Parallel execution contract across runway/tooling/product surfaces |
| `docs/product/AOF_PRODUCT_CONTRACT.md` | AOF product boundary, versioning, tenant model |
| `docs/product/AOF_DEPLOYMENT_PLAYBOOK.md` | AOF deployment guide |
| `docs/product/AOF_SUPPORT_SLO.md` | AOF support commitments |
| `docs/product/AOF_TENANT_STORAGE_MODEL.md` | AOF tenant isolation and storage boundary contract |
| `docs/product/AOF_POLICY_RUNTIME_ENFORCEMENT.md` | AOF policy knob enforcement at runtime |
| `docs/product/AOF_VERSION_COMPATIBILITY.md` | AOF version compatibility matrix |
| `docs/product/AOF_EVIDENCE_RETENTION_EXPORT.md` | AOF evidence retention and export contract |
| `docs/product/AOF_SURFACE_READONLY_CONTRACT.md` | AOF read-only surface endpoint contract |

---

## Changelog

| Date | Change | Issue |
|------|--------|-------|
| 2026-02-13 | Added Runway/Tooling/Product Operating Contract v1 and wired it into governance indexes | — |
| 2026-02-13 | Added post-gap operating model, build-mode checklist, onboarding playbook, and stabilization bindings | — |
| 2026-02-13 | Added Share Channel Governance section + WORKBENCH_SHARE_PROTOCOL.md | — |
| 2026-02-05 | Added Legacy References section; spine-native SSOTs table | — |
| 2026-01-24 | Added SSOT Claims Guardrail section | #541 |
| 2026-01-23 | Created as part of Agent Clarity epic | #541 |

<!-- AUTO: GOVERNANCE_DOC_INDEX_START -->

## Appendix: Governance document index (auto)

> This appendix is generated to ensure every governance doc is discoverable from the authority chain.
> The sections above remain the curated authority narrative; this list is an index only.
> Last regenerated: 2026-02-15 (78 docs).

- `AGENT_BOUNDARIES.md`
- `AGENT_GOVERNANCE_BRIEF.md`
- `AGENT_TERMINOLOGY_GLOSSARY.md`
- `AGENTS_GOVERNANCE.md`
- `AGENTS_LOCATION.md`
- `ARCHIVE_POLICY.md`
- `AUDIT_VERIFICATION.md`
- `AUTHENTIK_BACKUP_RESTORE.md`
- `BACKUP_CALENDAR.md`
- `BACKUP_GOVERNANCE.md`
- `BUILD_MODE_CHECKLIST.md`
- `CAMERA_SSOT.md`
- `CANONICAL.md`
- `CHANGE_PACK_TEMPLATE.md`
- `CLAUDE_ENTRYPOINT_SHIM.md`
- `COMPOSE_AUTHORITY.md`
- `CORE_AGENTIC_SCOPE.md`
- `DEVICE_IDENTITY_SSOT.md`
- `DR_RUNBOOK.md`
- `EXCLUDED_SURFACES.md`
- `FINANCE_LEGACY_EXTRACTION_MATRIX.md`
- `GAP_LIFECYCLE.md`
- `GIT_REMOTE_AUTHORITY.md`
- `GITEA_BACKUP_RESTORE.md`
- `GOVERNANCE_INDEX.md`
- `HASS_LEGACY_EXTRACTION_MATRIX.md`
- `HASS_OPERATIONAL_RUNBOOK.md`
- `HOME_BACKUP_STRATEGY.md`
- `HOME_NETWORK_AUDIT_RUNBOOK.md`
- `HOME_NETWORK_DEVICE_ONBOARDING.md`
- `HOST_DRIFT_POLICY.md`
- `IMMICH_LEGACY_EXTRACTION_MATRIX.md`
- `INFISICAL_BACKUP_RESTORE.md`
- `INFRA_RELOCATION_PROTOCOL.md`
- `INFRASTRUCTURE_AUTHORITY.md`
- `INFRASTRUCTURE_MAP.md`
- `INGRESS_AUTHORITY.md`
- `ISSUE_CLOSURE_SOP.md`
- `LEGACY_DEPRECATION.md`
- `MACBOOK_BOOTSTRAP_CONTRACT.md`
- `MACBOOK_SSOT.md`
- `MAILROOM_BRIDGE.md`
- `MAILROOM_RUNBOOK.md`
- `MAKER_TOOLS_GOVERNANCE.md`
- `MINILAB_SSOT.md`
- `MINT_PRODUCT_GOVERNANCE.md`
- `N8N_RECOVERY_RUNBOOK.md`
- `NETWORK_POLICIES.md`
- `NETWORK_RUNBOOK.md`
- `ONBOARDING_PLAYBOOK.md`
- `OPS_PATCH_HISTORY.md`
- `OUTPUT_CONTRACTS.md`
- `PATCH_CADENCE.md`
- `PHASE4_OBSERVABILITY_RUNBOOK.md`
- `PORTABILITY_ASSUMPTIONS.md`
- `POST_GAP_OPERATING_MODEL.md`
- `RAG_INDEXING_RULES.md`
- `RAG_REINDEX_RUNBOOK.md`
- `RAG_PASSIVE_PIPELINE_PROTOCOL.md`
- `REBOOT_HEALTH_GATE.md`
- `RELEASE_PROTOCOL.md`
- `REPO_STRUCTURE_AUTHORITY.md`
- `RUNWAY_TOOLING_PRODUCT_OPERATING_CONTRACT_V1.md`
- `RTO_RPO.md`
- `SCRIPTS_AUTHORITY.md`
- `SCRIPTS_REGISTRY.md`
- `SEARCH_EXCLUSIONS.md`
- `SECRETS_POLICY.md`
- `SECURITY_POLICIES.md`
- `SESSION_PROTOCOL.md`
- `SHOP_NETWORK_AUDIT_RUNBOOK.md`
- `SHOP_NETWORK_DEVICE_ONBOARDING.md`
- `SHOP_NETWORK_NORMALIZATION.md`
- `SHOP_SERVER_SSOT.md`
- `SHOP_VM_ARCHITECTURE.md`
- `SPINE_INDEX.md`
- `SSOT_UPDATE_TEMPLATE.md`
- `STACK_AUTHORITY.md`
- `VAULTWARDEN_BACKUP_RESTORE.md`
- `VERIFY_SURFACE_INDEX.md`
- `WORKBENCH_SHARE_PROTOCOL.md`
- `WORKBENCH_TOOLING_INDEX.md`

<!-- AUTO: GOVERNANCE_DOC_INDEX_END -->
