---
status: open
owner: "@ronny"
created: 2026-02-12
scope: loop-scope
loop_id: LOOP-MINT-DEPLOY-CONTRACT-20260212
severity: medium
---

# Loop Scope: LOOP-MINT-DEPLOY-CONTRACT-20260212

## Goal

Establish deploy contracts for mint-modules: Dockerfiles, compose files,
health checks, and deployment runbooks so each module has a repeatable
path from code to running container on VM 200.

## Boundary Rule

Workers only edit mint-modules. Spine edits = scope + receipts + closeout only.

## Phases

### P0: Baseline
- [x] authority.project.status: GOVERNED
- [x] spine.verify: PASS D1-D71
- [x] ops status: 0 loops, 0 gaps
- [x] gaps.status: 0 open, 0 orphaned

### P1: Worker D — Deploy artifacts
- [ ] Pending worker handoff

### P2: Worker E — Integration
- [ ] Pending worker handoff

### P3: Worker F — Validation
- [ ] Pending worker handoff

### P4: Terminal C — Recert + Closeout
- [ ] typecheck + build + test pass (order-intake, quote-page, artwork)
- [ ] Both remotes in sync
- [ ] Loop closed with evidence
