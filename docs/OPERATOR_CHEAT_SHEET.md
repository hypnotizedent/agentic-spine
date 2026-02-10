# Operator Cheat Sheet

> **Status:** authoritative
> **Last verified:** 2026-02-10

Quick reference for spine operations and governance tasks.

## Common Operations

### Start work on an issue
```bash
cd ~/code/agentic-spine
./bin/ops start ISSUE_NUMBER
```

### Verify infrastructure
```bash
./bin/ops cap run spine.verify
```

### Run capabilities
```bash
./bin/ops cap list                     # List all capabilities
./bin/ops cap run <capability_name>    # Run a specific capability
./bin/ops cap show <capability_name>   # Show capability details
```

### Stage and create PR
```bash
./bin/ops pr create                    # Stage, commit, push, and create PR
./bin/ops pr close ISSUE_NUMBER        # Verify, confirm merge, close issue
```

## Ready check (before any API work)

Run in terminal you intend to use for API-touching capabilities:

- `./bin/ops ready`

If it STOPs (exit 2), run the one-liner it prints:

- `source ~/.config/infisical/credentials`

Then rerun `./bin/ops ready`.

### What ready check does
1. Runs spine health gates (verify, replay, status)
2. Checks secrets binding
3. Validates Infisical auth hydration
4. Checks bound project is ACTIVE per SSOT
5. Exits 0 if terminal is cleared for API work

### Why this exists
Shell environments cannot be reliably mutated by subprocess capabilities. The `ops ready` command provides a single operator ritual that validates auth is hydrated before any API-touching capability runs.

## Capability Categories

### Spine Health
- `spine.verify` - Drift gate health check
- `spine.replay` - Determinism verification
- `spine.status` - Watcher and queue status

### Secrets Management
- `secrets.binding` - Print binding (SSOT)
- `secrets.auth.load` - Load auth guidance
- `secrets.auth.status` - Check auth presence
- `secrets.credentials.parity` - Audit creds file setup across declared nodes
- `secrets.projects.status` - Verify bound project is ACTIVE

### GitHub Integration
- `github.actions.status` - Workflow run counts + latest conclusion
- `github.queue.status` - PR queue state

### Cloudflare Integration
- `cloudflare.records.status` - DNS record validation

## Governance

All capabilities are governed by:
- Read-only safety checks
- Precondition chains (.requires[])
- Receipt generation for audit trail
- SSOT binding validation

See `docs/governance/` for full governance documentation.
