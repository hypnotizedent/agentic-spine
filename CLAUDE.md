# Claude Entry Stub

Canonical governance: [`docs/governance/SPINE.md`](docs/governance/SPINE.md)
Translator doctrine: [`docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`](docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md)

<!-- SPINE_STARTUP_BLOCK -->
Session auto-attach runs at launch. Manual fallback:
```bash
cd ~/code/agentic-spine
./bin/ops cap run session.v3.attach -- --allow-no-loop
```
<!-- /SPINE_STARTUP_BLOCK -->

## Quick Reference
- Primary: `~/code/agentic-spine` | Workbench: `~/code/workbench`
- Query: direct read → `rag.anythingllm.ask` → `rag_query` MCP → `rg`
- Docker: `docker context show`
