# LOOP-MCPJUNGLE-RELOCATION-20260209

> **Status:** open
> **Owner:** @ronny
> **Created:** 2026-02-09
> **Severity:** medium

---

## Executive Summary

Move MCPJungle off `docker-host` (Mint OS production plane) onto `automation-stack` (tooling plane) to prevent app-runtime coupling and keep specialized agents/MCP servers out of the spine core.

**Key decision:** MCPJungle runs on `automation-stack`; public exposure (Cloudflare/Caddy) is separate and can be added later.

---

## Scope

In scope:
- Deploy MCPJungle to `automation-stack` under `~/stacks/mcpjungle`
- Stop MCPJungle on `docker-host`
- Update spine SSOT/bindings to reflect runtime placement

Out of scope (explicitly deferred):
- Finance stack governance
- Mail-archiver governance
- Public hostname routing for MCPJungle (CF tunnel / Authentik / Caddy)

---

## Phases

| Phase | Scope | Dependency | Status |
|------:|-------|------------|--------|
| P0 | Confirm current docker-host deploy + ports | None | TODO |
| P1 | Update workbench compose for host-agnostic bind + no external networks | None | DONE |
| P2 | Sync compose/build context to automation-stack | P1 | TODO |
| P3 | Copy `.env` secrets from docker-host to automation-stack (no secret printing) | P2 | TODO |
| P4 | Bring up MCPJungle on automation-stack + smoke health | P3 | TODO |
| P5 | Stop MCPJungle on docker-host | P4 | TODO |
| P6 | Update spine SSOT/bindings + verify receipts | P4 | TODO |

---

## Success Criteria

- `docker.compose.status` shows `mcpjungle` running under `automation-stack`
- `services.health.status` probe `mcpjungle` returns `200` from `http://100.98.70.70:8085/health`
- No MCPJungle stack remains running on `docker-host`

