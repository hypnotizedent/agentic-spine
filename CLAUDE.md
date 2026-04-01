---
subordinate_of: AGENTS.md
scope: claude-session-entry
---

# Claude Entry Stub

Governance is injected by hook via `.claude/settings.json` and `.claude/hooks/session-entry-hook.sh`.
This file is a thin pointer only. Do not duplicate governance here.

- Shared governance core: [`ops/archive/pre-2026-04-01-spine/docs/governance/RONNY_SESSION_SKILL_CORE.md`](ops/archive/pre-2026-04-01-spine/docs/governance/RONNY_SESSION_SKILL_CORE.md)
- Operating contract: [`docs/governance/SPINE.md`](docs/governance/SPINE.md)
- Translator doctrine: [`docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`](docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md)
- Root authority: [`ops/bindings/root.authority.contract.yaml`](ops/bindings/root.authority.contract.yaml)

## Quick Reference
- Primary: `~/code/agentic-spine` | Workbench: `~/code/workbench`
- Query: direct read → `rag.anythingllm.ask` → `rag_query` MCP → `rg`
- Docker: `docker context show`
