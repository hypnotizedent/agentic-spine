# Agents Governance (SSOT)

> **Status:** authoritative
> **Last verified:** 2026-02-04

Tracks: #634

## Purpose
Define the lifecycle and verification contract for agent scripts and related automation in the agentic-spine.

## Sources of Truth

> **Workbench-side:** The paths below reference the workbench monolith (`~/Code/workbench`). For the spine's own agent contracts, see `agents/contracts/` and [CORE_AGENTIC_SCOPE.md](CORE_AGENTIC_SCOPE.md).

- Inventory (machine-readable): `infrastructure/data/agents_inventory.json`
- Verification script: `scripts/infra/agents_verify.sh`
- Reference reports:
  - `docs/runbooks/AGENTS_VERIFICATION_REPORT_2026-01-25.md`
  - `docs/runbooks/AGENTS_GAPS_REPORT_2026-01-25.md`

## Lifecycle
- **Create**: add agent script + add entry to inventory
- **Change**: update agent + update inventory metadata
- **Retire**: disable in inventory (`enabled: false`) and document rationale
- **Verify**: run `scripts/infra/agents_verify.sh` and store receipt in `receipts/`

## Safety Rules
- No secrets in inventory (names/paths only; never values)
- Verification output must not print secret content
- Any automation changes (launchd/cron/GHA) are out of scope unless explicitly tracked by an issue/plan

## Schema Reference
See `docs/runbooks/PR_SCOPE_AGENTS_2026-01-25.md` for schema contract.

## Verification
```bash
./scripts/infra/agents_verify.sh
```
Exit 0 = PASS, non-zero = FAIL
