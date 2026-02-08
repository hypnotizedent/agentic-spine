---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
scope: agent-locations
---

# AGENTS LOCATION CONTRACT

## Governance (Spine)

- `ops/agents/<id>.contract.md` — per-agent ownership contracts
- `ops/bindings/agents.registry.yaml` — machine-readable catalog with routing rules
- `surfaces/verify/d49-agent-discovery-lock.sh` — drift gate for registry integrity
- `docs/governance/AGENTS_GOVERNANCE.md` — lifecycle and safety rules

## Implementation (Workbench)

- `workbench/agents/<domain>/` — domain agent tools, configs, playbooks, docs
- Must comply with WORKBENCH_CONTRACT (no watchers, no cron, no schedulers)
- Implementation path declared in `agents.registry.yaml` → `implementation` field

## Runtime Tooling (Spine)

- `ops/` + `surfaces/` — commands + verification scripts
- `_imports/` — frozen intake only (never runtime)

## Rule

If it changes agent **governance** (contracts, routing, verification), it must land in the spine with a receipt.
If it changes agent **behavior** (tools, configs, playbooks), it must land in the workbench under `agents/<domain>/`.
