# Claude Code / Claude Desktop Instructions

> Project-level instruction surface for the agentic-spine repo.
> Loaded automatically by Claude Code and Claude Desktop.
> Governance brief source: `docs/governance/AGENT_GOVERNANCE_BRIEF.md`

## Session Entry

1. Read `AGENTS.md` for the full runtime contract.
2. Run the Mandatory Startup Block below (fast startup by default).
3. Run `./bin/ops cap list` only when you need to discover a specific capability.

<!-- SPINE_STARTUP_BLOCK -->
## Mandatory Startup Block

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.start
```
<!-- /SPINE_STARTUP_BLOCK -->

## Post-Work Verify (run after domain changes, before commit)

```bash
./bin/ops cap run verify.route.recommend          # tells you which domain pack to run
./bin/ops cap run verify.pack.run <domain>         # runs domain-specific gates
```

## Release Certification (nightly / release only)

```bash
./bin/ops cap run verify.release.run              # full 148-gate suite (requires Tailscale)
```

## Identity

- User: Ronny
- GitHub: hypnotizedent

## Governance

Full governance contract: [`docs/governance/AGENT_GOVERNANCE_BRIEF.md`](docs/governance/AGENT_GOVERNANCE_BRIEF.md)

<!-- GOVERNANCE_BRIEF -->
<!-- Canonical source: docs/governance/AGENT_GOVERNANCE_BRIEF.md (D65) -->
<!-- /GOVERNANCE_BRIEF -->

## Quick Reference

- Runtime Repo: `~/code/agentic-spine`
- Workbench Repo: `~/code/workbench`
- Query first: direct file read → `./bin/ops cap run rag.anythingllm.ask` → optional `rag_query` MCP → `rg` fallback.
- Docker context: check with `docker context show`
