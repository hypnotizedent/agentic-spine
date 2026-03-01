# Claude Code / Claude Desktop Instructions

> Project-level instruction surface for the agentic-spine repo.
> Loaded automatically by Claude Code and Claude Desktop.
> Governance brief source: `docs/governance/AGENT_GOVERNANCE_BRIEF.md`
> canonical_boot_surface: `docs/governance/generated/BOOT_ENTRY_SURFACE.md`
> entry_surface_gate_metadata: projection
> projection_of: `ops/bindings/gate.registry.yaml`
<!-- ENTRY_SURFACE_GATE_METADATA_START -->
# ENTRY SURFACE GATE METADATA (generated)
source_registry: ops/bindings/gate.registry.yaml
registry_updated: 2026-03-01
gate_count_total: 302
gate_count_active: 301
gate_count_retired: 1
max_gate_id: D304
<!-- ENTRY_SURFACE_GATE_METADATA_END -->

## Session Entry

1. Read `AGENTS.md` for the full runtime contract.
2. Run the Mandatory Startup Block below (fast startup by default).
3. Run `./bin/ops cap show <capability>` when syntax/flags are uncertain.
4. Run `./bin/ops cap list` only when you need to discover a specific capability.

<!-- SPINE_STARTUP_BLOCK -->
## Mandatory Startup Block

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.start
```
<!-- /SPINE_STARTUP_BLOCK -->

## Post-Work Verify (run after domain changes, before commit)

```bash
./bin/ops cap run verify.run -- fast                # canonical quick verify entry
./bin/ops cap run verify.run -- domain <domain>     # canonical domain verify entry
```

## Release Certification (nightly / release only)

```bash
./bin/ops cap run verify.release.run              # full release certification suite (requires Tailscale)
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
