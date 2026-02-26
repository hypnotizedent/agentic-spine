---
loop_id: LOOP-MEDIA-GOVERNANCE-NORMALIZATION-20260226
created: 2026-02-26
status: in-progress
owner: "@ronny"
scope: media
priority: high
objective: Normalize media domain governance to parity with communications/finance — canonical docs, registry/routing reconciliation, MCP registration, health classification, naming conventions.
---

# Loop Scope: LOOP-MEDIA-GOVERNANCE-NORMALIZATION-20260226

## Objective

Media domain audit revealed 15 inconsistencies across contracts, registries, MCP config, terminal roles, and naming conventions. This loop brings media governance to structural parity with mature domains (communications, finance) so agents can operate the media lane without hunting context.

## Provenance

Driven by comprehensive read-only audit (3 parallel agents) on 2026-02-26. Findings cross-referenced across agents.registry.yaml, routing.dispatch.yaml, capability.domain.catalog.yaml, terminal.role.contract.yaml, terminal.launcher.view.yaml, mcp.runtime.contract.yaml, service.onboarding.contract.yaml, and media-agent.contract.md.

## Linked Gaps

| Gap | Sev | Status | Description | Fixed In |
|-----|-----|--------|-------------|----------|
| GAP-OP-963 | medium | **OPEN** | 5 missing MCP tools (vpn, slskd, soularr, qbittorrent, pipeline) — deferred to workbench implementation | Workbench media-agent MCP |
| GAP-OP-964 | medium | **OPEN** | MCP dual-implementation parity (local vs MCPJungle) — needs pre-commit hook | Workbench parity hook |
| GAP-OP-965 | low | **OPEN** | Media MCP secrets pattern uses env fallback, not infisical-agent.sh | Workbench MCP refactor |
| GAP-OP-966 | low | **OPEN** | 4 inconsistent discovered_by values in historical gaps (572, 906, 907, 937, 939) — policy decision needed on backfill | Convention doc created |

## Deliverables

### Phase 1: Governance Documentation
- `docs/governance/MEDIA_DOMAIN_GOVERNANCE.md` — canonical naming map, authoritative files, invariants, operator flow

### Phase 2: Registry/Routing Normalization
- `media-agent.contract.md` — status "pending" → active
- `agents.registry.yaml` — capabilities list expanded, project_binding added
- `capability.domain.catalog.yaml` — 8 → 17 capabilities
- `terminal.role.contract.yaml` — 2 → 7 capabilities, description fixed, status active
- `terminal.launcher.view.yaml` — description, status, capability_count, health_url fixed
- `service.onboarding.contract.yaml` — deploy_stack_id corrected for download/streaming

### Phase 3: MCP Governance
- `mcp.runtime.contract.yaml` — media-agent registered as optional server
- Gaps filed for missing MCP tools and parity enforcement

### Phase 4: Health Governance
- `media.services.yaml` — health_reason field added for active+health:null services

### Phase 5: Naming Convention
- Convention documented in governance doc, future enforcement via gap review

## Completion Criteria

- [x] Loop registered
- [x] Governance doc created
- [x] All registry/routing files reconciled
- [x] MCP contract updated
- [x] Health governance classified
- [x] Naming convention documented
- [ ] verify.pack.run media PASS
- [x] Gaps filed for deferred items (963-966)
- [ ] Commit with governance-focused message
