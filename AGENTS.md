---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-22
scope: agent-runtime-contract
---

# AGENTS.md - Agentic Spine Runtime Contract

> Auto-loaded by local coding tools (Claude Code, Claude Desktop, Codex, etc.).
> Canonical runtime: `~/code/agentic-spine`
> Governance brief source: `docs/governance/AGENT_GOVERNANCE_BRIEF.md`

## Session Entry

1. Start in `~/code/agentic-spine`.
2. Read `docs/governance/SESSION_PROTOCOL.md`.
3. Run the Mandatory Startup Block below (fast startup by default).
4. Run `./bin/ops cap list` only when you need to discover a specific capability.
5. Execute work via `./bin/ops cap run <capability>`.

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

## Governance

Full governance contract: [`docs/governance/AGENT_GOVERNANCE_BRIEF.md`](docs/governance/AGENT_GOVERNANCE_BRIEF.md)

<!-- GOVERNANCE_BRIEF -->
<!-- Canonical source: docs/governance/AGENT_GOVERNANCE_BRIEF.md (D65) -->
<!-- /GOVERNANCE_BRIEF -->

## Canonical Terminal Roles

| ID | Type | Scope |
|----|------|-------|
| SPINE-CONTROL-01 | control-plane | bin/, ops/, surfaces/, docs/governance/, docs/core/, docs/product/, docs/brain/, mailroom/ |
| SPINE-AUDIT-01 | observation | receipts/, docs/governance/_audits/ |
| DOMAIN-HA-01 | domain-runtime | ops/plugins/ha/, ops/agents/home-assistant-agent.contract.md |
| RUNTIME-IMMICH-01 | domain-runtime | ops/plugins/immich/, ops/agents/immich-agent.contract.md |
| DEPLOY-MINT-01 | domain-runtime | ops/plugins/mint/, ops/agents/mint-agent.contract.md |

> Source: `ops/bindings/terminal.role.contract.yaml`
