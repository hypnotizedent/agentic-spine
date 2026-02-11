# LOOP-MCP-RUNTIME-GOVERNANCE-20260211

> **Status:** open
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Severity:** critical
> **Gap:** GAP-OP-095

---

## Executive Summary

MCPJungle and workbench MCP tool servers bypass the spine mailroom by making direct mutating API calls to external services. Multiple MCP servers have no spine contract or registry entry. One server contains a hardcoded API key. Local and MCPJungle copies of agent tools have no parity enforcement.

---

## Phases

| Phase | Scope | Dependency | Status |
|-------|-------|------------|--------|
| P0 | Gap registration + loop scope | None | **DONE** |
| P1 | Remove hardcoded SABnzbd API key from MCPJungle media-stack source | None | **DONE** |
| P2 | Block/route mutating MCP tools to spine-governed capability path only | P1 | **DONE** |
| P3 | Register all MCPJungle servers in agents.registry.yaml with contracts | P2 | OPEN |
| P4 | Add drift gate for local vs MCPJungle MCP server code parity | P3 | OPEN |
| P5 | Add spine capabilities (or explicit deny policy) for HA/Mint/Firefly/Paperless/Immich/MS Graph | P3 | OPEN |

---

## P0: Governance Artifacts

### Gap Registered

| Gap | Severity | Description |
|-----|----------|-------------|
| GAP-OP-095 | CRITICAL | Shadow runtime bypass — MCPJungle MCP servers make direct mutating API calls without mailroom gating |

---

## P1: Remove Hardcoded Secret

- **File:** `~/code/workbench/infra/compose/mcpjungle/servers/media-stack/src/index.ts`
- **Issue:** Line 49 contains hardcoded SABnzbd Home API key as fallback default
- **Fix:** Replace with empty string fallback (matches all other config entries)
- **Validates:** Secrets policy (no plaintext secrets in repo)

---

## P2: Block/Route Mutating MCP Tools

Mutating MCP tools (POST/PUT/DELETE to external APIs) in workbench must either:
- Route through `./bin/ops cap run <capability>` (receipted, gated), or
- Be removed from the MCP tool surface and replaced with a read-only stub that emits guidance to use spine

**Implementation:** Inserted a `GOVERNED_TOOLS` lookup gate at the top of each file's `CallToolRequestSchema` handler. Governed tools return a structured JSON response (`blocked: true`, tool name, loop/gap refs, and spine guidance). Read-only tools pass through unchanged. Existing handler code is preserved but unreachable for governed tools.

**Files modified (6):**
1. `infra/compose/mcpjungle/servers/media-stack/src/index.ts` — 8 tools blocked
2. `infra/compose/mcpjungle/servers/n8n/src/index.ts` — 6 tools blocked
3. `infra/compose/mcpjungle/servers/home-assistant/src/index.ts` — 1 tool blocked
4. `infra/compose/mcpjungle/servers/mint-os/src/index.ts` — 5 tools blocked
5. `agents/media/tools/src/index.ts` — 8 tools blocked (local copy, mirrors MCPJungle)
6. `agents/n8n/tools/src/index.ts` — 6 tools blocked (local copy, mirrors MCPJungle)

**Governed tools (actual, code-verified):**
- media-agent (MCPJungle): request_movie, request_show, request_artist, trigger_collection_search, approve_request, manage_queue, manage_queue_home, toggle_huntarr
- media-agent (local only): update_movie_profile, search_movie_by_id, update_show_profile
- n8n-agent: create_workflow, import_workflow, activate_workflow, deactivate_workflow, delete_workflow, execute_workflow
- home-assistant: ha_call_service
- mint-os: send_order_email, post_production_update, update_order_customer, ss_place_order, sanmar_place_order

**Note:** n8n tools with existing spine capabilities (create/import/activate/deactivate/delete) include the capability name in guidance. All others reference P5 for pending capability registration.

---

## P3: Register MCPJungle Servers

Add agent registry entries + spine contracts for:
- home-assistant-agent (domain: home-automation)
- mint-os-agent (domain: commerce)
- firefly-agent (domain: finance)
- paperless-agent (domain: documents)
- immich-agent (domain: photos)
- ms-graph-agent (domain: identity/email)

Each needs: `ops/agents/<id>.contract.md` + routing_rules entry in agents.registry.yaml.

---

## P4: Parity Drift Gate

New drift gate: compare file hashes between `agents/<domain>/tools/src/` and `infra/compose/mcpjungle/servers/<name>/src/` for each registered agent that has both surfaces. Fail spine.verify if they diverge without an explicit exception.

---

## P5: Missing Capabilities

For each newly registered agent domain, either:
- Create spine capabilities (read-only first, mutating later with proper safety/approval), or
- Add an explicit deny entry in capabilities.yaml documenting why the domain is not yet governed

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| No hardcoded secrets in workbench MCP servers | `rg` search for API key patterns |
| All MCPJungle MCP servers have spine contracts | agents.registry.yaml coverage check |
| Mutating MCP tools gated or removed | Code review of all POST/PUT/DELETE paths |
| Local vs MCPJungle parity gate exists | spine.verify PASS with new gate |
| spine.verify PASS | ops verify |

---

_Scope document created by: Cowork audit (Opus 4.6)_
_Created: 2026-02-11_
