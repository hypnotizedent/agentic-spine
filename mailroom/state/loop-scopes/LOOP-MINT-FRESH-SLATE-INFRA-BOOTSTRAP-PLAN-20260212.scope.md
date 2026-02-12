---
loop_id: LOOP-MINT-FRESH-SLATE-INFRA-BOOTSTRAP-PLAN-20260212
status: closed
owner: "@ronny"
created: 2026-02-12
closed: 2026-02-12
terminal: C
type: plan-only
---

# Mint Fresh-Slate Infra Bootstrap Plan

## Objective

Produce an executable infrastructure bootstrap plan for mint-modules on two new VMs (mint-data + mint-apps), with zero legacy runtime dependency in the final target state. Plan-only — no host mutations.

## Artifacts Produced

1. `docs/planning/MINT_FRESH_SLATE_INFRA_BOOTSTRAP_RUNBOOK.md` — Step-by-step VM provisioning, registration, deployment, and validation runbook
2. (Content includes binding impact matrix, cutover checklist, and definition of done)

## ADR Alignment

- ADR-001: Runtime Boundary (two-VM topology, zero legacy dependency)
- ADR-002: Data Plane (new `mint_modules` DB, start empty, HTTP-only integration)
- ADR-003: Secrets Project Model (per-module Infisical projects)

## Constraints

- No host mutations (no VM create/clone/start/stop, no docker changes, no DNS/Cloudflare, no Infisical writes)
- Mailroom proposals for tracked spine edits
- Current system remains stable

## Evidence

### Baseline (P0)
- spine.verify: RCAP-20260212-082435__spine.verify__R863082070 — ALL PASS
- gaps.status: RCAP-20260212-082504__gaps.status__Rf2qi91669 — 2 open (GAP-OP-117/118, pre-existing home-infra)
- authority.project.status: RCAP-20260212-082508__authority.project.status__Rm4zn91740 — GOVERNED

### Recert (P3)
- spine.verify: RCAP-20260212-083129__spine.verify__R5ed992627 — ALL PASS
- gaps.status: RCAP-20260212-083200__gaps.status__R13kr2726 — 2 open (same pre-existing, unchanged)
- authority.project.status: RCAP-20260212-083200__authority.project.status__Rfl7e2786 — GOVERNED

### Commits
- spine: 41d61c4 (proposal CP-20260212-083037__mint-fresh-slate-infra-bootstrap-plan)
