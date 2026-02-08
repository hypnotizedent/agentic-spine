---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
scope: agent-lifecycle
github_issue: "#634"
---

# Agents Governance (SSOT)

Tracks: #634

## Purpose
Define the lifecycle, discovery, and verification contract for domain-specific agents in the agentic-spine.

## Sources of Truth

> **Spine-native:** Agent governance lives inside this repo. Implementations may live in workbench; contracts and registry live here.

- **Registry (machine-readable):** `ops/bindings/agents.registry.yaml` — catalog of all domain agents with routing rules
- **Contracts:** `ops/agents/<agent-id>.contract.md` — per-agent ownership boundary (what it owns, what it defers)
- **Verification:** `surfaces/verify/agents_verify.sh` + D49 drift gate in `drift-gate.sh`
- Reference reports:
  - `docs/governance/AUDIT_VERIFICATION.md`
  - `docs/governance/_audits/AGENT_RUNTIME_AUDIT.md`
  - `docs/governance/CORE_AGENTIC_SCOPE.md`

## Agent Discovery

Every new Claude Code session receives agent discovery info via `generate-context.sh`:
- Section "Available Agents" lists registered agents with domains and descriptions
- Routing rules map problem keywords to the correct agent
- Agents consult `ops/bindings/agents.registry.yaml` for the full catalog

## Lifecycle
- **Register**: create `ops/agents/<id>.contract.md`, add entry to `agents.registry.yaml`, verify with `spine.verify`
- **Implement**: build agent tools in workbench (or other location per contract), update `implementation_status` in registry
- **Change**: update contract + registry entry, run `spine.verify`
- **Retire**: remove contract + registry entry, document rationale in session handoff

## Safety Rules
- No secrets in contracts or registry (names/paths only; never values)
- Verification output must not print secret content
- Agents must comply with WORKBENCH_CONTRACT (no watchers, no cron, no schedulers)
- Infrastructure concerns (compose, health, routing, secrets) stay in spine — agents own application layer only

## Verification
```bash
# Full drift gate suite (includes D49 agent discovery lock)
./bin/ops cap run spine.verify

# Agent-specific checks
./surfaces/verify/agents_verify.sh
```
Exit 0 = PASS, non-zero = FAIL
