---
status: closed
owner: "@ronny"
created: 2026-02-11
closed: 2026-02-11
scope: loop-scope
loop_id: LOOP-AUTHORITY-PARITY-CLEANUP-20260211
severity: medium
---

# Loop Scope: LOOP-AUTHORITY-PARITY-CLEANUP-20260211

## Goal

Close 6 findings from two read-only audits:
- CP-20260211-181200__cross-repo-authority-drift-readonly (3 findings)
- CP-20260211-182000__service-registry-parity-readonly (3 findings)

## Acceptance Criteria

1. Workbench README.md clarified (reference, not canonical) — DONE (4f1036d)
2. WORKBENCH_CONTRACT.md clarified (operational configs, not canonical state) — DONE (4f1036d)
3. Workbench SERVICE_REGISTRY.yaml entries changed from authoritative to deprecated — DONE (4f1036d)
4. Immich added to docker.compose.targets.yaml — DONE (fdadd1e)
5. 6 SERVICE_REGISTRY entries get compose paths — DONE (fdadd1e)
6. Cloudflared probe resolved — DONE (disabled with policy note; no --metrics in compose, SPOF risk prevents live fix)

## Phases

| Phase | Scope | Status | Commit/Proposal |
|-------|-------|--------|-----------------|
| P0 | Baseline | DONE | receipts only |
| P1 | Workbench authority wording | DONE | 4f1036d (workbench) |
| P2 | Spine registry-parity | DONE | CP-20260211-182200 / fdadd1e |
| P3 | Cloudflared probe | DONE | CP-20260211-182400 (this proposal) |
| P4 | Validate + close | DONE | (this commit) |
