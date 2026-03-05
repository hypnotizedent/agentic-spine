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

## Projection Metadata

<!-- ENTRY_SURFACE_GATE_METADATA_START -->
# ENTRY SURFACE GATE METADATA (generated)
source_registry: ops/bindings/gate.registry.yaml
registry_updated: 2026-03-05
gate_count_total: 377
gate_count_active: 361
gate_count_retired: 16
max_gate_id: D381
<!-- ENTRY_SURFACE_GATE_METADATA_END -->
