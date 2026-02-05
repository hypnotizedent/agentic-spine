---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-05
scope: agent-lifecycle
github_issue: "#634"
---

# Agents Governance (SSOT)

Tracks: #634

## Purpose
Define the lifecycle and verification contract for agent scripts and related automation in the agentic-spine.

## Sources of Truth

> **Spine-native:** Agent automation lives inside this repo. Trust the files below instead of legacy workbench paths (archived elsewhere).

- Inventory (machine-readable): `ops/agents/` contains the active agent entry scripts and metadata.
- Verification script: `surfaces/verify/agents_verify.sh` (runs every agent through the spine health gate).
- Reference reports:
  - `docs/governance/AUDIT_VERIFICATION.md`
  - `docs/governance/_audits/AGENT_RUNTIME_AUDIT.md`
  - `docs/governance/CORE_AGENTIC_SCOPE.md`

## Lifecycle
- **Create**: add an agent script under `ops/agents/` and document it in this file or on the governance board.
- **Change**: update the script + update any metadata stored in `receipts/` or the ledger so the change is auditable.
- **Retire**: disable the script, archive its receipt trail, and document the rationale in a session handoff.
- **Verify**: run `./surfaces/verify/agents_verify.sh` (or `./bin/ops cap run spine.verify`) and store the resulting receipt in `receipts/sessions/`.

## Safety Rules
- No secrets in inventory (names/paths only; never values)
- Verification output must not print secret content
- Any automation changes (launchd/cron/GHA) are out of scope unless explicitly tracked by a mailroom loop or plan

## References
See `docs/governance/CORE_AGENTIC_SCOPE.md` for the invariants that every agent implementation must strengthen.

## Verification
```bash
./surfaces/verify/agents_verify.sh
```
Exit 0 = PASS, non-zero = FAIL
