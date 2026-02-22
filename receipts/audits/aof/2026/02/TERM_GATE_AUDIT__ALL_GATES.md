# TERM Gate Audit — All Gates

> **Audit Date:** 2026-02-16
> **Sources:**
> - `ops/bindings/gate.registry.yaml`
> - `ops/bindings/gate.execution.topology.yaml`
> - `ops/bindings/gate.domain.profiles.yaml`
> - `surfaces/verify/drift-gate.sh`
> **Scope:** Full inventory of D1-D128 with domain assignment, scope classification, and mint-relevance analysis.

---

## Summary

| Metric | Count |
|--------|-------|
| Total Gates | 128 |
| Active | 127 |
| Retired | 1 (D21) |
| Core Gates | 56 |
| Domain Gates | 71 |
| Release Sequence Domains | 14 |

---

## Gate Inventory

| gate_id | status | primary_domain | scope | one_line_purpose | why_it_blocks | mint_relevance |
|---------|--------|----------------|-------|------------------|---------------|----------------|
| D1 | active | core | core | Top-level directory policy (7 allowed dirs) | Extra dirs indicate repo drift from canonical structure | no |
| D2 | active | core | core | No runs/ directory (traces in receipts/sessions/) | Stray runs/ violates trace contract | no |
| D3 | active | core | core | bin/ops preflight must succeed (dedicated script) | Core entrypoint must be functional | no |
| D4 | active | core | core | LaunchAgent com.ronny.agent-inbox loaded and running | Warn-only; watcher not critical to ops | no |
| D5 | active | core | core | No ~/agent or $HOME/agent references in runtime scripts | Legacy coupling violates path hygiene | no |
| D6 | active | core | core | Latest 5 receipt dirs have receipt.md | Receipts are session evidence contract | no |
| D7 | active | core | core | Shell scripts only in bin/, ops/, surfaces/verify/ | Out-of-bounds scripts indicate drift | no |
| D8 | active | core | core | No .bak or fix_bak files in bin/ or ops/ | Backup clutter is repo pollution | no |
| D9 | active | core | core | Latest receipt has required fields (Run ID, Generated, Status, Model, Inputs, Outputs) | Receipt contract enforcement | no |
| D10 | active | core | core | No spurious $SPINE/logs directory (must be mailroom/logs) | Wrong log location violates path contract | no |
| D11 | active | core | core | ~/agent must be symlink to agentic-spine/mailroom (if exists) | Non-symlink violates home surface contract | no |
| D12 | active | core | core | docs/core/CORE_LOCK.md repo validity marker exists | Missing marker = invalid repo state | no |
| D13 | active | secrets | domain | API capability secrets preconditions enforced | API caps require secrets binding first | no |
| D14 | active | infra | domain | Cloudflare surface drift (no legacy smells) | Infra SSOT drift detection | no |
| D15 | active | infra | domain | GitHub Actions surface drift (no legacy smells, no leaked secrets) | CI/CD hygiene enforcement | no |
| D16 | active | core | core | No competing truth documents in docs/governance/ | Doc governance contract | no |
| D17 | active | core | core | No agents/, _imports/, or drift magnets at repo root | Root hygiene enforcement | no |
| D18 | active | infra | domain | Docker compose references match SSOT | Container infra parity | **yes** |
| D19 | active | infra | domain | Backup surface inventory, no legacy smells, no secret printing | Backup infra hygiene | no |
| D20 | active | secrets | domain | Secrets configuration drift (verbose subcheck) | Secrets hygiene (subcheck of D55) | no |
| D21 | retired | - | - | Retired — was agent-entry-surface-lock, merged into D56 | N/A (retired) | no |
| D22 | active | infra | domain | SSH node references match DEVICE_IDENTITY_SSOT | Node identity parity | **yes** |
| D23 | active | infra | domain | Service health endpoints match SERVICE_REGISTRY | Service infra health | **yes** |
| D24 | active | infra | domain | GitHub labels match governance | Label infra parity | no |
| D25 | active | secrets | domain | Infisical CLI only, no legacy vault patterns (verbose subcheck) | Secrets CLI contract (subcheck of D55) | no |
| D26 | active | core | core | Agent read surfaces (AGENTS.md, CLAUDE.md) not stale (verbose subcheck) | Agent surface hygiene (subcheck of D56) | no |
| D27 | active | core | core | No raw IPs/ports in no-fact docs | Doc fact hygiene | no |
| D28 | active | core | core | Active legacy absolute paths + extraction queue contract | Path migration tracking | no |
| D29 | active | core | core | LaunchD/cron entries use ~/code/ paths, not legacy locations | Entrypoint path hygiene | no |
| D30 | active | core | core | No legacy config references or plaintext tokens in active configs | Config security hygiene | no |
| D31 | active | core | core | No log/out/err files at home root | Home output hygiene | no |
| D32 | active | core | core | AGENTS.md points to spine governance (verbose subcheck) | Agent instruction source (subcheck of D56) | no |
| D33 | active | core | core | Extraction must stay paused during stabilization | Extraction state contract | no |
| D34 | active | loop_gap | domain | Loop summary matches deduped counts | Loop ledger integrity | no |
| D35 | active | infra | domain | Cross-SSOT consistency for service relocations | Infra move parity | no |
| D36 | active | core | core | Stale/near-expiry legacy exceptions flagged | Exception hygiene | no |
| D37 | active | infra | domain | Infra placement matches governance policy (verbose subcheck) | VM placement policy (subcheck of D57) | no |
| D38 | active | core | core | EXTRACTION_PROTOCOL.md compliance | Extraction process contract | no |
| D39 | active | infra | domain | Hypervisor identity entries match live infrastructure (verbose subcheck) | Hypervisor identity (subcheck of D57) | no |
| D40 | active | core | core | Maker tools binding validity and script hygiene | Tooling hygiene | no |
| D41 | active | core | core | Home-root hidden dir inventory + forbidden pattern enforcement | Hidden dir governance | no |
| D42 | active | core | core | Runtime scripts use lowercase ~/code/ (no ~/Code/) | Path case consistency | no |
| D43 | active | secrets | domain | Secrets namespace policy + capability wiring | Secrets governance | no |
| D44 | active | core | core | CLI tools inventory + cross-refs + probes | Tooling discovery | no |
| D45 | active | core | core | Cross-file identity surface verification | Naming consistency | no |
| D46 | active | core | core | ~/.claude/CLAUDE.md is redirect shim only (verbose subcheck) | Claude instruction source (subcheck of D56) | no |
| D47 | active | core | core | No legacy brain surface path in runtime scripts (must be docs/brain/) | Brain path contract | no |
| D48 | active | core | core | Detect stale/orphaned/detached/dirty worktrees and orphaned stashes | Git worktree hygiene | no |
| D49 | active | core | core | agents.registry.yaml + agent contracts valid | Agent discovery | no |
| D50 | active | infra | domain | CI workflow file references drift-gate.sh correctly | CI wiring | no |
| D51 | active | infra | domain | X-Forwarded-Proto on all Authentik upstreams in Caddy | Proxy config | no |
| D52 | active | infra | domain | Shop SSOT docs reference correct gateway network | Network infra | no |
| D53 | active | core | core | Change pack template + sequencing + companion files | Change pack integrity | no |
| D54 | active | infra | domain | Device identity ↔ shop server ↔ bindings IP consistency | SSOT IP parity | no |
| D55 | active | secrets | domain | Composite: secrets binding + CLI + auth readiness | Secrets runtime readiness | no |
| D56 | active | core | core | Composite: agent read surface + codex/claude instruction source | Agent entry surface | no |
| D57 | active | infra | domain | Composite: infra placement + hypervisor identity | Infra identity cohesion | no |
| D58 | active | infra | domain | last_reviewed/last_verified dates enforced (max 21 days) | SSOT freshness | no |
| D59 | active | infra | domain | Bidirectional host coverage between registries | Registry completeness | no |
| D60 | active | core | core | Known deprecated terms in governance docs | Deprecation hygiene | no |
| D61 | active | loop_gap | domain | Session closeout freshness (every 48h) | Session traceability | no |
| D62 | active | core | core | origin/main == github/main | Git remote parity | no |
| D63 | active | core | core | Registry integrity (API caps need touches_api + requires) | Capability metadata | no |
| D64 | active | core | core | Gitea is canonical, GitHub is mirror only | Git authority | no |
| D65 | active | core | core | AGENTS.md + CLAUDE.md governance brief matches canonical source | Agent briefing sync | no |
| D66 | active | core | core | Local MCP agents vs MCPJungle copies in sync | MCP parity | no |
| D67 | active | core | core | capability_map.yaml covers all entries in capabilities.yaml | Capability map coverage | no |
| D68 | active | rag | domain | RAG manifest excludes non-canonical paths | RAG doc hygiene | no |
| D69 | active | infra | domain | New VMs need SSH + SERVICE_REGISTRY + backup + health entries | VM creation governance | no |
| D70 | active | secrets | domain | Deprecated secret project write protection | Secrets alias hygiene | no |
| D71 | active | core | core | Workbench scripts vs deprecated reference allowlist | Deprecated ref governance | no |
| D72 | active | workbench | domain | Workbench launcher surfaces match spine MACBOOK_SSOT AUTO blocks | Launcher parity | no |
| D73 | active | workbench | domain | OpenCode config model/provider/launcher path correct | OpenCode entry | **yes** |
| D74 | active | workbench | domain | Background defaults + launchd template invariants | Billing lane contract | no |
| D75 | active | loop_gap | domain | operational.gaps.yaml mutated only via capabilities | Gap registry safety | no |
| D76 | active | workbench | domain | Home directory drift prevention | Home surface hygiene | no |
| D77 | active | workbench | domain | Plist/runtime/bare-exec enforcement | Workbench contract | no |
| D78 | active | workbench | domain | No uppercase /Code/ + no legacy repo name in workbench | Workbench path hygiene | no |
| D79 | active | workbench | domain | Governed workbench script surface | Script allowlist | **yes** |
| D80 | active | workbench | domain | Legacy naming violations in workbench | Naming authority | **yes** |
| D81 | active | core | core | New plugins must have tests or explicit exemption | Plugin test regression | no |
| D82 | active | core | core | Share publish allowlist/denylist + capability wiring | Publish governance | no |
| D83 | active | loop_gap | domain | Proposal manifest + fields + SLA + parity | Proposal queue health | no |
| D84 | active | core | core | Every governance .md registered in _index.yaml | Doc registration | no |
| D85 | active | core | core | gate.registry.yaml covers every gate in drift-gate.sh, all scripts exist | Gate registry parity | no |
| D86 | active | infra | domain | Every active VM in vm.lifecycle.yaml has a valid operating profile entry | VM profile parity | no |
| D87 | active | rag | domain | RAG workspace contract binding exists and is consistent with CLI defaults | RAG workspace contract | no |
| D88 | active | rag | domain | RAG remote reindex runner binding, scripts, capability wiring, and auth-token hygiene | RAG reindex governance | no |
| D89 | active | rag | domain | RAG reindex quality contract binding exists with required thresholds | RAG quality contract | no |
| D90 | active | rag | domain | RAG reindex runtime quality gate enforces clean completion | RAG runtime quality | no |
| D91 | active | aof | domain | AOF product docs, tenant bindings, policy presets, and tenant capabilities exist | AOF foundation | no |
| D92 | active | home | domain | HA config files extracted to workbench for version control | HA config VC | no |
| D93 | active | aof | domain | Tenant storage contract binding exists with all boundary declarations | Tenant storage | no |
| D94 | active | aof | domain | Policy runtime contract binding exists with all 10 knobs declared | Policy enforcement | no |
| D95 | active | aof | domain | Version compatibility matrix exists with valid source references | Version compat | no |
| D96 | active | aof | domain | Evidence retention policy exists with retention classes | Evidence retention | no |
| D97 | active | aof | domain | Surface readonly contract exists with all status surfaces declared | Readonly surface | no |
| D98 | active | home | domain | Z2M device registry exists, is non-empty, and fresh (<14 days) | Z2M device parity | no |
| D99 | active | home | domain | HA API token from Infisical returns HTTP 200 (not stale) | HA token freshness | no |
| D100 | active | infra | domain | vm.lifecycle.yaml LAN IPs match DEVICE_IDENTITY_SSOT.md and MINILAB_SSOT.md | VM IP parity | no |
| D101 | active | home | domain | HA add-on inventory exists, is non-empty, and fresh (<14 days) | HA addon parity | no |
| D102 | active | home | domain | HA device map exists, is non-empty, and fresh (<14 days) | HA device map | no |
| D103 | active | workbench | domain | Stream Deck HA controller config is tracked in workbench and valid JSON | StreamDeck config | no |
| D104 | active | home | domain | DHCP audit summary exists, has devices checked, and is fresh (<14 days) | DHCP audit | no |
| D105 | active | home | domain | HA MCP server has GOVERNED_TOOLS block, ha_call_service blocked, and policy doc | HA MCP governance | no |
| D106 | active | media | domain | No duplicate ports across media VMs (download-stack, streaming-stack) | Media port collision | no |
| D107 | active | media | domain | Both media VMs can reach pve:/media with correct mount modes (RW/RO) | Media NFS mount | no |
| D108 | active | media | domain | Every active media service with health endpoint responds HTTP 200 | Media health | no |
| D109 | active | media | domain | Live containers match services declared in media.services.yaml | Media compose parity | no |
| D110 | active | media | domain | HA add-ons duplicating shop services are flagged for review | Media HA overlap | no |
| D111 | active | rag | domain | Recent successful smoke test required before full RAG reindex authorization | RAG smoke preflight | no |
| D112 | active | secrets | domain | All secret access uses canonical infisical-agent.sh (no CLI pattern, no inline auth) | Secrets access pattern | no |
| D113 | active | home | domain | Radio coordinator health (Z2M started, SLZB-06MU ethernet up, firmware versions logged) | Coordinator health | no |
| D114 | active | home | domain | HA automation count matches expected (27 automations) | HA automation stability | no |
| D115 | active | infra | domain | HA SSOT baseline exists, fresh (14d), sub-bindings on disk, unexpected unavailable below threshold | HA SSOT baseline | no |
| D116 | active | infra | domain | Bridge Cap-RPC consumer registry parity (allowlist + RBAC roles + docs + JSON contract caps) | Bridge consumer registry | no |
| D117 | active | home | domain | IoT device naming convention parity across registry, HA entities, and Tuya names | IoT naming parity | no |
| D118 | active | home | domain | Z2M device battery levels above 20%, staleness within 48h, bridge connected | Z2M device health | no |
| D119 | active | home | domain | Z2M naming parity across z2m.naming.yaml, z2m.devices.yaml, and ha.device.map.yaml | Z2M naming parity | no |
| D120 | active | home | domain | HA areas match SSOT binding ha.areas.yaml — names, icons, area count | HA area parity | no |
| D121 | active | aof | domain | Lean-spine boundary lock (plane metadata + active workbench agent implementation path policy) | Fabric boundary | no |
| D122 | active | aof | domain | Domain docs routing lock (spine pointer stubs + workbench target parity via domain.docs.routes.yaml) | Domain doc routing | no |
| D123 | active | aof | domain | Balanced policy lock with multi-session proposal safety enforcement | Policy safety | no |
| D124 | active | core | core | Startup contract block parity across AGENTS, CLAUDE, OPENCODE, and ~/.claude surfaces | Entry surface parity | no |
| D125 | active | workbench | domain | MCP runtime server registration parity across Codex, Claude Desktop, and OpenCode | MCP runtime parity | **yes** |
| D126 | active | workbench | domain | Domain-external capability implementation paths resolve to canonical workbench files/dirs | Impl path lock | no |
| D127 | active | aof | domain | Topology lock: all active gates must have primary_domain assignment; all domain refs defined; release sequence complete | Domain assignment | no |
| D128 | active | aof | domain | Gate registry/topology mutation lock: require governed capability provenance and clean contract files | Gate registration | no |

---

## MISSCOPED_GATES

Gates that can block **non-domain work** (especially mint) due to domain assignment mismatches between `gate.execution.topology.yaml` and `gate.domain.profiles.yaml`.

### Issue Summary

The `mint` domain is defined in `gate.domain.profiles.yaml` with 6 gates (D18, D22, D23, D79, D80, D125), but none of these gates have `primary_domain: mint` in `gate.execution.topology.yaml`. Instead, they are assigned to other domains (infra, workbench) with secondary domain references that **exclude mint**.

### Potentially Blocking Gates for Mint Work

| gate_id | primary_domain | secondary_domains | mint_in_profile | mint_in_topology | issue |
|---------|----------------|-------------------|-----------------|------------------|-------|
| D18 | infra | [n8n] | yes | no | Docker compose drift check blocks mint if compose mismatch |
| D22 | infra | [n8n, finance] | yes | no | SSH node check could block mint if nodes not in n8n/finance scope |
| D23 | infra | [n8n, finance] | yes | no | Health endpoint check could block mint services |
| D73 | workbench | [n8n] | yes | no | OpenCode config check blocks mint workspaces |
| D79 | workbench | [n8n, finance, immich] | yes | no | Workbench script allowlist could block mint scripts |
| D80 | workbench | [n8n, finance, immich] | yes | no | Workbench authority check could block mint naming |
| D125 | workbench | [n8n, finance, immich, ms-graph] | yes | no | MCP runtime parity could block mint MCP servers |

### Exact File Paths

**Source of truth files:**

1. **Gate Registry:**
   `ops/bindings/gate.registry.yaml`

2. **Gate Execution Topology (domain assignments):**
   `ops/bindings/gate.execution.topology.yaml`
   - Lines 132-660: `gate_assignments` block

3. **Gate Domain Profiles (domain gate collections):**
   `ops/bindings/gate.domain.profiles.yaml`
   - Lines 306-322: `mint` domain definition

4. **Drift Gate Execution Script:**
   `surfaces/verify/drift-gate.sh`

### Recommended Actions

1. **Add mint to secondary_domains for affected gates:**
   - D18: add `mint` to secondary_domains
   - D22: add `mint` to secondary_domains
   - D23: add `mint` to secondary_domains
   - D73: add `mint` to secondary_domains
   - D79: add `mint` to secondary_domains
   - D80: add `mint` to secondary_domains
   - D125: add `mint` to secondary_domains

2. **OR promote mint gates to primary_domain:**
   If mint-specific gates are needed, create dedicated gates with `primary_domain: mint` rather than repurposing infra/workbench gates.

3. **Verify path_triggers alignment:**
   The `mint` domain profile declares:
   ```yaml
   path_triggers:
     - ops/plugins/mint/
     - ops/agents/mint-agent.contract.md
     - ops/bindings/agents.registry.yaml
     - /Users/ronnyworks/code/mint-modules/
   ```
   Ensure these paths are covered by the gate assignment strategy.

---

## Domain Coverage Analysis

| domain_id | gate_count | criticality | requires_runtime_sentinel |
|-----------|------------|-------------|---------------------------|
| core | 56 | standard | no |
| aof | 9 | standard | no |
| secrets | 7 | critical | no |
| infra | 19 | critical | yes |
| workbench | 11 | standard | no |
| loop_gap | 4 | standard | no |
| home | 14 | critical | yes |
| media | 5 | standard | no |
| immich | 0* | critical | yes |
| n8n | 0* | critical | yes |
| finance | 0* | critical | yes |
| mint | 0* | critical | yes |
| ms-graph | 0* | critical | yes |
| rag | 6 | standard | no |

*Note: immich, n8n, finance, mint, and ms-graph have 0 gates with `primary_domain` assignment but are included in `secondary_domains` of other gates. This is intentional per the domain dependency model — these domains inherit gates from their dependencies (infra, workbench, secrets).

---

## Core Mode Gate Limit

The `core_mode` configuration in `gate.execution.topology.yaml` declares:

```yaml
core_gate_ids:
  - D3
  - D48
  - D63
  - D67
  - D121
  - D124
  - D126
  - D127
core_count_limit: 8
```

**Current count: 8 gates (at limit)**

These are the gates that run in every verify lane (core, domain, release).

---

## Validation Rules Status

From `gate.execution.topology.yaml`:

| Rule | Status |
|------|--------|
| require_primary_domain_for_all_active_gates | PASS (all 127 active gates have primary_domain) |
| reject_undefined_domain_refs | PASS (all domain refs exist in domain_metadata) |
| require_release_sequence_coverage | PASS (14 domains in release_sequence match domain_metadata) |

---

## Audit Conclusion

**Overall Status: PASS with recommendations**

1. All 127 active gates have valid `primary_domain` assignments.
2. No undefined domain references.
3. Release sequence is complete.
4. **Recommendation:** Add `mint` to `secondary_domains` for D18, D22, D23, D73, D79, D80, D125 to align `gate.execution.topology.yaml` with `gate.domain.profiles.yaml` mint domain definition.

---

*Generated: 2026-02-16*
*Audit ID: TERM_GATE_AUDIT__ALL_GATES*
