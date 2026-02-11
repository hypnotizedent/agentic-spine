---
status: open
owner: "@ronny"
created: 2026-02-11
scope: loop-scope
loop_id: LOOP-CONTAINER-SPINE-CLEANUP-CLOSEOUT-20260211
severity: medium
---

# Loop Scope: LOOP-CONTAINER-SPINE-CLEANUP-CLOSEOUT-20260211

## Goal

Close D/E/F audit findings from runtime-registry parity, health-backup coverage,
and secrets-capability cleanliness audits. Leave baseline clean: 2 loops (MD1400 +
HOME-BACKUP), 1 gap (GAP-OP-037).

## Problem

Three read-only audits (CP-20260211-202658, CP-20260211T202946Z, CP-20260211-152717)
identified 82 findings across runtime/registry parity (26), health/backup coverage (44),
and secrets/capability cleanliness (12). Key issues: 6 active mint-os frontends unregistered,
caddy/cloudflared missing health probes, stale docker-host finance probe entries, stopped
services without explicit status, agent registry pointing at old VM, and MCP configs
using pre-migration endpoints.

## Acceptance Criteria

1. SERVICE_REGISTRY: mint-os frontends registered, stopped services marked, immich host ssh fixed
2. Health probes: caddy added, stale docker-host finance entries removed, policy notes for non-probeable
3. Agents: firefly/paperless agents point to finance-stack VM 211
4. MCP configs: paperless.json points to VM 211, microsoft-graph.json Azure IDs externalized
5. Secrets namespace: N8N_ENCRYPTION_KEY and mint-os vendor keys mapped
6. spine.verify PASS

## Phases

| Phase | Scope | Status | Commit/Proposal |
|-------|-------|--------|-----------------|
| P0 | Register loop + GAP-OP-104 | DONE | (this commit) |
| P1 | Runtime/registry truth cleanup | pending | |
| P2 | Health + backup coverage hardening | pending | |
| P3 | Secrets/capability/agent-path cleanup | pending | |
| P4 | Validate + close | pending | |

## Registered Gaps

- GAP-OP-104: Container/spine cleanup findings from D/E/F audits
