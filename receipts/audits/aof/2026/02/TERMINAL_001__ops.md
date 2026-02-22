---
audit_type: AOF_ALIGNMENT_INBOX
target_folder: /Users/ronnyworks/code/agentic-spine/ops
audit_date: 2026-02-16
auditor: sisyphus-agent
status: complete
total_files: 522
total_directories: 76
total_lines: 53228
---

# AOF Alignment Audit: ops/

> Audit of `/Users/ronnyworks/code/agentic-spine/ops` folder against AOF product boundary and governance authority.

## Summary

| Category | File Count | Directory Count | Classification |
|----------|------------|-----------------|----------------|
| KEEP_SPINE | ~500 | 73 | Core AOF runtime/governance |
| MOVE_WORKBENCH | 7 | 1 | Domain-specific tooling |
| RUNTIME_ONLY | 0 | 0 | None identified |
| UNKNOWN | 2 | 2 | Legacy imports needing review |

---

## KEEP_SPINE

Files and directories that are **core to AOF runtime and governance** per AOF_PRODUCT_CONTRACT.md and CORE_AGENTIC_SCOPE.md.

### Criteria
- Part of AOF product boundary (ops/, bindings, runtime, capabilities)
- Strengthens Ingress/Trace/Governance invariants
- Referenced by spine.verify drift gates

### Directories

| Path | File Count | Purpose |
|------|------------|---------|
| `/Users/ronnyworks/code/agentic-spine/ops/plugins/` | 32 scripts + 16 tests + MANIFEST.yaml | 44 capability plugins (core runtime) |
| `/Users/ronnyworks/code/agentic-spine/ops/bindings/` | 112 YAML files | SSOT configuration (governance) |
| `/Users/ronnyworks/code/agentic-spine/ops/commands/` | 14 scripts | CLI entry points (ops cap, ops status, etc.) |
| `/Users/ronnyworks/code/agentic-spine/ops/lib/` | 4 scripts + 2 tests | Shared libraries (resolve-policy, governance, registry) |
| `/Users/ronnyworks/code/agentic-spine/ops/hooks/` | 3 scripts | Git hooks and sync utilities |
| `/Users/ronnyworks/code/agentic-spine/ops/engine/` | 5 scripts | AI engine providers (zai, claude, openai, local_echo) |
| `/Users/ronnyworks/code/agentic-spine/ops/runtime/` | 2 scripts + inbox/ | Runtime scripts (HA baseline, inbox management) |
| `/Users/ronnyworks/code/agentic-spine/ops/runtime/inbox/` | 10 scripts | Agent inbox management (enqueue, status, watchdog) |
| `/Users/ronnyworks/code/agentic-spine/ops/agents/` | 11 contract files | Agent contracts (.contract.md) |
| `/Users/ronnyworks/code/agentic-spine/ops/profiles/` | 3 YAML files | Profile configurations (production, product, minimal) |
| `/Users/ronnyworks/code/agentic-spine/ops/staged/` | 53 files | VM-infra compose stacks (per COMPOSE_AUTHORITY.md) |

### Key Files

| Path | Purpose |
|------|---------|
| `/Users/ronnyworks/code/agentic-spine/ops/capabilities.yaml` | Capability registry (authoritative) |
| `/Users/ronnyworks/code/agentic-spine/ops/README.md` | ops CLI documentation |
| `/Users/ronnyworks/code/agentic-spine/ops/plugins/MANIFEST.yaml` | Plugin manifest |

### Staged Stacks (Spine-Owned per COMPOSE_AUTHORITY.md)

These compose stacks are explicitly declared as spine-owned in COMPOSE_AUTHORITY.md:

| Stack | Path |
|-------|------|
| cloudflared | `ops/staged/cloudflared/` |
| caddy-auth | `ops/staged/caddy-auth/` |
| pihole | `ops/staged/pihole/` |
| vaultwarden | `ops/staged/vaultwarden/` |
| secrets (Infisical) | `ops/staged/secrets/` |
| dev-tools (gitea) | `ops/staged/dev-tools/gitea/` |
| observability/* | `ops/staged/observability/{prometheus,grafana,loki,uptime-kuma,node-exporter}/` |
| download-stack | `ops/staged/download-stack/` |
| streaming-stack | `ops/staged/streaming-stack/` |
| ai-consolidation | `ops/staged/ai-consolidation/` |

**Note:** COMPOSE_AUTHORITY.md explicitly states: "VM-infra compose SSOT (sanitized) lives in this repo under `ops/staged/**`."

---

## MOVE_WORKBENCH

Files that are **domain-specific tooling** that should live in workbench per AGENTS_LOCATION.md and CORE_AGENTIC_SCOPE.md.

### Criteria
- Domain-specific automation (not core governance)
- Agent implementations (contracts stay in spine, implementations in workbench)
- External system interfaces not tied to spine invariants

### Files

| Path | Reason | Recommended Destination |
|------|--------|------------------------|
| `/Users/ronnyworks/code/agentic-spine/ops/tools/cloudflare-agent.sh` | Domain-specific Cloudflare automation | `~/code/workbench/agents/cloudflare/` |
| `/Users/ronnyworks/code/agentic-spine/ops/tools/infisical-agent.sh` | External secrets management tooling | `~/code/workbench/agents/secrets/` |
| `/Users/ronnyworks/code/agentic-spine/ops/tools/unifi-agent.sh` | UniFi network management | `~/code/workbench/agents/network/` |
| `/Users/ronnyworks/code/agentic-spine/ops/tools/unifi-home-agent.sh` | Home UniFi automation | `~/code/workbench/agents/home/` |
| `/Users/ronnyworks/code/agentic-spine/ops/tools/legacy-freeze.sh` | Legacy migration helper | `~/code/workbench/scripts/` |
| `/Users/ronnyworks/code/agentic-spine/ops/tools/legacy-thaw.sh` | Legacy migration helper | `~/code/workbench/scripts/` |

**Count:** 7 files, 1 directory

**Rationale:** Per CORE_AGENTIC_SCOPE.md:
- "Implementations live in workbench (`agents/<domain>/`) per AGENTS_LOCATION.md"
- These are operational tools that interface with external systems, not spine invariants
- Agent contracts (ops/agents/*.contract.md) stay in spine; implementations move to workbench

---

## RUNTIME_ONLY

Files that are **transient or generated** and should not be committed to the repository.

### Files

None identified. The ops/ folder does not contain transient runtime artifacts.

**Note:** Runtime artifacts (receipts, logs, temp files) are correctly placed in:
- `receipts/sessions/` (generated receipts)
- `mailroom/` (runtime state)

---

## UNKNOWN

Files that require **further investigation** to determine proper classification.

### Files

| Path | Reason | Investigation Needed |
|------|--------|---------------------|
| `/Users/ronnyworks/code/agentic-spine/ops/legacy/` | Legacy imports directory | Determine if should be promoted, archived, or deleted |
| `/Users/ronnyworks/code/agentic-spine/ops/legacy/agents/clerk-watcher.sh` | Legacy agent script | Check if still used, promote to ops/runtime/inbox/ or remove |

**Count:** 2 files, 2 directories

### Investigation Questions

1. **ops/legacy/agents/clerk-watcher.sh**
   - Is this script referenced by any active capability?
   - Does it use SPINE_* environment variables or hard-coded paths?
   - If unused: delete
   - If used but legacy: promote to ops/runtime/inbox/ with updated paths

2. **ops/legacy/ directory**
   - Per CORE_AGENTIC_SCOPE.md: "Everything under `docs/**/_imported/` and `_imports/` is never authoritative"
   - This ops/legacy/ directory should follow same rules
   - Consider: rename to ops/_imports/ for clarity, or delete if not referenced

---

## Top 10 Highest-Risk Mismatches

Files with highest risk of being in the wrong location based on governance authority.

| Rank | Path | Current | Risk | Recommendation |
|------|------|---------|------|----------------|
| 1 | `/Users/ronnyworks/code/agentic-spine/ops/legacy/agents/clerk-watcher.sh` | UNKNOWN | HIGH | Promote or delete - violates import enforcement |
| 2 | `/Users/ronnyworks/code/agentic-spine/ops/tools/unifi-home-agent.sh` | ops/tools/ | MEDIUM | Move to workbench - domain-specific |
| 3 | `/Users/ronnyworks/code/agentic-spine/ops/tools/cloudflare-agent.sh` | ops/tools/ | MEDIUM | Move to workbench - domain-specific |
| 4 | `/Users/ronnyworks/code/agentic-spine/ops/tools/infisical-agent.sh` | ops/tools/ | MEDIUM | Move to workbench - domain-specific |
| 5 | `/Users/ronnyworks/code/agentic-spine/ops/tools/unifi-agent.sh` | ops/tools/ | MEDIUM | Move to workbench - domain-specific |
| 6 | `/Users/ronnyworks/code/agentic-spine/ops/tools/legacy-freeze.sh` | ops/tools/ | LOW | Move to workbench scripts/ |
| 7 | `/Users/ronnyworks/code/agentic-spine/ops/tools/legacy-thaw.sh` | ops/tools/ | LOW | Move to workbench scripts/ |
| 8 | `/Users/ronnyworks/code/agentic-spine/ops/staged/evidence/` | ops/staged/ | LOW | Verify this is intentional (evidence folder in staged) |
| 9 | `/Users/ronnyworks/code/agentic-spine/ops/staged/*.md` | ops/staged/ | INFO | Execution playbooks - verify governance alignment |
| 10 | `/Users/ronnyworks/code/agentic-spine/ops/plugins/conflicts/` | ops/plugins/ | INFO | Check if conflicts plugin is still active |

---

## Governance References

| Document | Relevance |
|----------|-----------|
| `docs/product/AOF_PRODUCT_CONTRACT.md` | Defines ops/ as part of AOF product boundary |
| `docs/governance/CORE_AGENTIC_SCOPE.md` | Defines core invariants, import rules, agent locations |
| `docs/governance/COMPOSE_AUTHORITY.md` | Declares ops/staged/** as spine-owned |
| `docs/governance/REPO_STRUCTURE_AUTHORITY.md` | Defines folder hierarchy and layer model |
| `docs/governance/AGENT_BOUNDARIES.md` | Agent boundary constraints |

---

## Verification Commands

```bash
# Verify ops/ structure alignment
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run spine.verify

# Check for legacy references
rg -n "legacy|ronny-ops|~/agent" ops/

# Count files by classification
find ops/plugins -type f -name "*.sh" | wc -l    # Core plugins
find ops/bindings -type f -name "*.yaml" | wc -l  # SSOT bindings
find ops/tools -type f -name "*.sh" | wc -l       # Domain tooling
find ops/legacy -type f | wc -l                   # Legacy imports
```

---

## Next Steps

1. **MOVE_WORKBENCH items:** Create migration plan for ops/tools/ → workbench/agents/
2. **UNKNOWN items:** Investigate ops/legacy/ for promotion or deletion
3. **HIGH risk:** Resolve clerk-watcher.sh disposition
4. **Update governance:** If ops/tools/ should remain, update CORE_AGENTIC_SCOPE.md to justify

---

*Audit generated by sisyphus-agent on 2026-02-16*
