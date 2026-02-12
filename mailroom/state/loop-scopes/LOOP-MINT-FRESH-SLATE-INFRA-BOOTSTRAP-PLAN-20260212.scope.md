---
loop_id: LOOP-MINT-FRESH-SLATE-INFRA-BOOTSTRAP-PLAN-20260212
status: open
owner: "@ronny"
created: 2026-02-12
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

## Evidence Required

- spine.verify PASS before and after
- gaps.status stable
- Commit hashes
