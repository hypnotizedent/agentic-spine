---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
created: 2026-02-16
scope: mint-agent-daily-loop
---

# Mint Agent Golden Loop

> Canonical daily operating loop for the mint-agent domain.
> Executed through spine capabilities with receipt tracking.

## Daily Sequence

```bash
cd /Users/ronnyworks/code/agentic-spine

# 1. Route — confirm agent identity
./bin/ops cap run agent.route mint-modules

# 2. Verify — run mint-agent gate pack
./bin/ops cap run verify.pack.run mint-agent

# 3. Health — probe all module endpoints
./bin/ops cap run mint.modules.health

# 4. Migrate — check pending migrations
./bin/ops cap run mint.migrate.dryrun

# 5. Closeout — session traceability
./bin/ops cap run agent.session.closeout
```

Or run the full loop as a single capability:

```bash
./bin/ops cap run mint.loop.daily
```

## Nightly Schedule

The nightly pass runs `verify.pack.run mint-agent` and `mint.modules.health` to catch drift or downtime between operator sessions. Results appear as receipts in the next session's `./bin/ops status` output.

Scheduling options (choose one):
- **LaunchAgent** (macOS): plist in `workbench/dotfiles/macbook/launchd/`
- **Cron** (VM): direct `crontab -e` on operator machine
- **n8n workflow**: webhook-triggered spine capability call

Recommended cadence: once daily at 06:00 local time.

## Loop Outputs

| Step | Receipt | Failure Action |
|------|---------|----------------|
| agent.route | Routing confirmation | Re-check agents.registry.yaml |
| verify.pack.run | 14-gate pass/fail | Triage failing gates via `/triage` |
| mint.modules.health | 6-component health status | SSH to failing VM, check containers |
| mint.migrate.dryrun | Migration count | Apply pending via `npm run migrate` in module |
| agent.session.closeout | Session cross-ref | Review stale/blocked loops |

## Escalation

If `verify.pack.run mint-agent` fails:
1. Read the failing gate output from the receipt
2. Run `/triage` with the gate ID
3. Fix in the appropriate repo (spine or mint-modules)
4. Re-run `verify.pack.run mint-agent` to confirm

If `mint.modules.health` fails:
1. Run `mint.deploy.status` to check container state
2. SSH to the failing VM and inspect with `docker logs <container>`
3. Restart if needed: `docker compose -f /opt/stacks/<stack>/docker-compose.yml restart <service>`

## Related

- Agent contract: `ops/agents/mint-agent.contract.md`
- Gate pack: `ops/bindings/gate.agent.profiles.yaml` (mint-agent: 14 gates)
- Domain pack: `ops/bindings/gate.domain.profiles.yaml` (mint domain)
- Module migration contract: `mint-modules/docs/ARCHITECTURE/MODULE_MIGRATION_RUNNER_CONTRACT.md`
