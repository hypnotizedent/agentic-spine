---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-05
scope: spine-minimal-operating-contract
---

# SPINE.md - Minimal Operating Contract

This is the single canonical governance doc for daily single-operator use.
All other governance docs should either be generated artifacts or scoped deep-dive references.

## Startup

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.start
```

## Daily Workflow

```bash
# Commit on main (intentional only)
OPS_GOVERNED_MAIN_OVERRIDE=1 git commit -m "..."

# Push on main (intentional only)
OPS_GOVERNED_MAIN_OVERRIDE=1 git push origin main
```

## Verify

```bash
./bin/ops cap run verify.run -- fast
./bin/ops cap run verify.run -- domain <domain>
```

## Minimality Rules

1. One doc per concern: add sections to an existing canonical doc before creating a new file.
2. One script per concern: extend existing scripts with flags/subcommands instead of creating near-duplicates.
3. Delete legacy: `.legacy` copies are migration debt and must be removed once active scripts are in place.
4. One override path: use `OPS_GOVERNED_MAIN_OVERRIDE=1`; do not require multi-var metadata ceremony for routine local work.
5. One daily remote: `origin` is canonical for day-to-day workflow.

## Mailroom Boundary

`mailroom/state/` is governance-only state: loops, plans, proposals, sessions, orchestration, alerts, gaps, friction, locks, verify evidence.
Domain runtime data must live in domain runtime roots/services, not in `mailroom/state/`.

## First-Class Governance Features

### Session Entry Hook (Agent Admission Control)
**Path**: `.claude/hooks/session-entry-hook.sh` (372 lines)

Every agent that starts a Claude Code session in this repo is automatically enrolled in the governance system before executing a single command. The hook enforces:
- Worktree isolation (D140): rejects unidentified worktree sessions
- Terminal role validation: establishes agent role context
- Multi-agent detection: blocks conflicts (4-hour TTL)
- Dynamic governance brief: delivers current governance context
- Proposal queue gating: alerts if >5 pending proposals

This is the **first line of agent governance**. See: `docs/governance/DREAM_SYSTEM.md` for details.

### D399: Live External-State Enforcement
**Path**: `surfaces/verify/d399-microsoft-mint-customer-mailbox-canonical-lock.sh` (560 lines)

Unlike file-check gates, D399 makes **LIVE API calls to Microsoft** on every push to main. It performs 14 live checks against Microsoft Exchange/Graph API to enforce consistency between declared contracts (`communications.providers.contract.yaml`) and live production state.

This is the current frontier of spine enforcement: gates that reach into live production systems before they allow a merge. See: `docs/governance/DREAM_SYSTEM.md` for details.

## Projection Metadata

<!-- ENTRY_SURFACE_GATE_METADATA_START -->
# ENTRY SURFACE GATE METADATA (generated)
source_registry: ops/bindings/gate.registry.yaml
registry_updated: 2026-03-11
gate_count_total: 394
gate_count_active: 89
gate_count_retired: 305
max_gate_id: D398
<!-- ENTRY_SURFACE_GATE_METADATA_END -->
