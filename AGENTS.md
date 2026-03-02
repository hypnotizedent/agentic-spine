---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-28
scope: agent-runtime-contract
---

# AGENTS.md - Agentic Spine Runtime Contract

> Auto-loaded by local coding tools (Claude Code, Claude Desktop, Codex, etc.).
> Canonical runtime: `~/code/agentic-spine`
> Governance brief source: `docs/governance/AGENT_GOVERNANCE_BRIEF.md`
> canonical_boot_surface: `docs/governance/generated/BOOT_ENTRY_SURFACE.md`
> entry_surface_gate_metadata: projection
> projection_of: `ops/bindings/gate.registry.yaml`
<!-- ENTRY_SURFACE_GATE_METADATA_START -->
# ENTRY SURFACE GATE METADATA (generated)
source_registry: ops/bindings/gate.registry.yaml
registry_updated: 2026-03-02
gate_count_total: 319
gate_count_active: 318
gate_count_retired: 1
max_gate_id: D321
<!-- ENTRY_SURFACE_GATE_METADATA_END -->

## Session Entry

1. Start in `~/code/agentic-spine`.
2. Read `docs/governance/SESSION_PROTOCOL.md`.
3. Run the Mandatory Startup Block below (fast startup by default).
4. Run `./bin/ops cap show <capability>` when syntax/flags are uncertain.
5. Run `./bin/ops cap list` only when you need to discover a specific capability.
6. Execute work via `./bin/ops cap run <capability>`.

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

## Governance

Full governance contract: [`docs/governance/AGENT_GOVERNANCE_BRIEF.md`](docs/governance/AGENT_GOVERNANCE_BRIEF.md)

<!-- GOVERNANCE_BRIEF -->
<!-- Canonical source: docs/governance/AGENT_GOVERNANCE_BRIEF.md (D65) -->
<!-- /GOVERNANCE_BRIEF -->

## Canonical Terminal Roles

| ID | Type | Status | Scope |
|----|------|--------|-------|
| SPINE-CONTROL-01 | control-plane | active | bin/, ops/, surfaces/, docs/governance/, docs/core/, docs/product/, docs/brain/, mailroom/ |
| SPINE-EXECUTION-01 | control-plane | active | mailroom/, receipts/ |
| SPINE-AUDIT-01 | observation | active | receipts/, docs/governance/_audits/ |
| SPINE-WATCHER-01 | observation | active | mailroom/state/, receipts/ |
| DOMAIN-HA-01 | domain-runtime | active | ops/plugins/ha/, ops/agents/home-assistant-agent.contract.md |
| DOMAIN-COMMS-01 | domain-runtime | active | ops/plugins/communications/, ops/agents/communications-agent.contract.md |
| DOMAIN-MICROSOFT-01 | domain-runtime | planned | ops/plugins/microsoft/, ops/agents/microsoft-agent.contract.md |
| DOMAIN-N8N-01 | domain-runtime | planned | ops/plugins/n8n/, ops/agents/n8n-agent.contract.md |
| DOMAIN-MEDIA-01 | domain-runtime | active | ops/plugins/media/, ops/agents/media-agent.contract.md |
| DOMAIN-PAPERLESS-01 | domain-runtime | planned | ops/agents/paperless-agent.contract.md |
| DOMAIN-FINANCE-01 | domain-runtime | active | ops/agents/finance-agent.contract.md |
| DOMAIN-FIREFLY-01 | domain-runtime | planned | ops/agents/firefly-agent.contract.md |
| DOMAIN-OBSERVABILITY-01 | domain-runtime | active | ops/plugins/observability/ |
| RUNTIME-IMMICH-01 | domain-runtime | active | ops/plugins/immich/, ops/agents/immich-agent.contract.md |
| DEPLOY-MINT-01 | domain-runtime | active | ops/plugins/mint/, ops/agents/mint-agent.contract.md |
| DEPLOY-MINTOS-01 | domain-runtime | planned | ops/agents/mint-os-agent.contract.md |

> Source: `ops/bindings/terminal.role.contract.yaml`
