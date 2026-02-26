---
loop_id: LOOP-MINT-FRESH-SLATE-INFRA-HARDENING-20260225
created: 2026-02-25
status: active
owner: "@ronny"
scope: mint
severity: high
objective: Resolve infrastructure drift findings on fresh-slate VMs 212 (mint-data) and 213 (mint-apps) discovered during read-only audit
---

# Loop Scope: LOOP-MINT-FRESH-SLATE-INFRA-HARDENING-20260225

## Problem Statement

Read-only infrastructure audit of VM 212 (mint-data) and VM 213 (mint-apps) on
2026-02-25 identified 4 drift findings that require remediation:

1. VM 212 root disk at 80% (9.5G remaining) — data plane storage pressure
2. Redis on VM 212 uses anonymous Docker volume — data loss risk on container recreate
3. Duplicate compose files on VM 213 — unclear authority for 4 module services
4. Data services on VM 212 bind 0.0.0.0 — Postgres/Redis/MinIO exposed on all interfaces

## Deliverables

1. Expand or reclaim disk on VM 212 to bring usage below 70%.
2. Convert Redis anonymous volume to a named volume (preserve existing data).
3. Consolidate or deprecate duplicate per-module compose files on VM 213.
4. Scope data service binds to Tailscale or restrict with firewall rules.

## Acceptance Criteria

1. `df -h /` on VM 212 reports below 70%.
2. `docker volume ls` on VM 212 shows a named volume for Redis (no anonymous hash).
3. Each module on VM 213 has exactly one authoritative compose file.
4. `ss -tlnp` on VM 212 shows data ports bound to Tailscale IP or 127.0.0.1, or UFW rules restrict LAN access.

## Constraints

1. No module code changes — infrastructure only.
2. No data loss — Redis volume migration must preserve existing data.
3. Compose consolidation must not restart healthy containers unless planned.
4. All changes require receipt-backed evidence.

## Gaps

- GAP-OP-932: VM 212 root disk at 80%
- GAP-OP-933: Redis anonymous volume on VM 212
- GAP-OP-934: Duplicate compose authority on VM 213
- GAP-OP-935: VM 212 data services bind 0.0.0.0
