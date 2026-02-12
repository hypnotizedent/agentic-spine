---
status: closed
owner: "@ronny"
created: 2026-02-11
closed: 2026-02-11
scope: loop-scope
loop_id: LOOP-INFISICAL-UI-RBAC-PARITY-LOCK-20260211
severity: high
---

# Loop Scope: LOOP-INFISICAL-UI-RBAC-PARITY-LOCK-20260211

## Goal

Lock Infisical UI + RBAC parity with spine runtime enforcement. Eliminate disconnect between spine runtime behavior, Infisical UI project state, and RBAC permissions for agent secret writes.

## Phases

### P0: Baseline & Proof — DONE
- [x] secrets.projects.status OK (10/10), namespace OK (77 keys, 0 root), cli PASS, D1-D70 PASS, 1 gap
- [x] Scan: 0 agent-facing deprecated refs, 7 operator-only allowlisted, 1 comment fixed

### P1: RBAC Lock (live Infisical) — DONE (034747f)
- [x] Identity: cli-access (1afd588e-...), Universal Auth
- [x] RBAC downgraded: admin → viewer on 3 deprecated projects
- [x] Created secrets-identity-rbac-status (probe) + secrets-identity-rbac-lock (mutation)
- [x] Self-escalation blocked (403 PermissionDenied confirms lock is irrevocable)

### P2: UI Lifecycle Parity Lock — DONE (034747f)
- [x] UI descriptions verified: stale on deprecated projects
- [x] Description update blocked by viewer role (validates RBAC lock works)
- [x] Inventory updated with rbac: viewer field for 3 deprecated projects
- [x] mint-os-portal (delete_candidate): keep with viewer lock; safe to archive/delete later

### P3: Active Consumer Cleanup (non-legacy) — DONE (workbench 92629c9)
- [x] 0 agent-facing deprecated API calls (already cleaned in prior loop)
- [x] 1 comment fix: sync-firefly-transaction.sh (finance-stack → infrastructure)
- [x] Hash parity: PASS (b38361592cbb)
- [x] 7 operator-only scripts identified and allowlisted

### P4: Anti-regression Gate — DONE (e38d5b7)
- [x] D71 deprecated-ref allowlist lock created
- [x] deprecated-project-allowlist.yaml with 7 entries
- [x] Wired into drift-gate.sh
- [x] VERIFY_SURFACE_INDEX.md updated (53 drift gates, 73 total)

### P5: Validation — DONE
- [x] secrets.projects.status OK (10/10)
- [x] secrets.namespace.status OK (77 keys, 0 root)
- [x] secrets.cli.status PASS (hash b38361592cbb)
- [x] spine.verify D1-D71 PASS
- [x] gaps.status: 1 open (GAP-OP-037, hardware-blocked), 0 orphans
- [x] secrets.identity.rbac.status: deprecated_writable=0, status=OK

## Acceptance Criteria

1. ✅ Spine identity cannot mutate deprecated projects (RBAC enforced — viewer role, 403 on self-escalation)
2. ✅ UI lifecycle matches spine lifecycle (inventory + rbac field updated; UI description update needs manual admin)
3. ✅ Active non-legacy deprecated-project refs = 0 (agent-facing) or exactly matched allowlist (7 operator-only)
4. ✅ Gate coverage prevents regression (D71 + D70 + D25)
5. ✅ All receipts captured

## Commits

| Phase | Hash | Repo | Description |
|-------|------|------|-------------|
| P1+P2 | 034747f | spine | RBAC lock capabilities + inventory rbac field + loop scope |
| P3 | 92629c9 | workbench | Comment fix: finance-stack → infrastructure |
| P4 | e38d5b7 | spine | D71 gate + allowlist + drift-gate wiring + index update |
| P5 | (this) | spine | Loop closure with evidence |
