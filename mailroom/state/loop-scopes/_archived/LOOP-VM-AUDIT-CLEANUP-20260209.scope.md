# LOOP-VM-AUDIT-CLEANUP-20260209

> **Status:** CLOSED
> **Owner:** @ronny
> **Created:** 2026-02-09
> **Closed:** 2026-02-09
> **Severity:** medium
> **Origin:** Cross-VM deep audit (204, 205, 206, 207, 209, 210) via 4-subagent pattern

---

## Executive Summary

Deep audits of all 6 shop VMs found them operationally healthy (53 containers, all running). Two gaps were fixed in-session (STACK_REGISTRY + LAN IPs for VM 204, Loki healthcheck for VM 205). This loop collected the remaining documentation/governance gaps discovered across all audits into a single receipted cleanup pass.

All 10 tasks completed. 50/50 drift gates pass.

UDR7 is now installed at proxmox-home location (previously "on-hand"). Network cutover planning can begin.

---

## Tasks

### P0 — SSOT Fixes

| Task | File | Action | Status |
|------|------|--------|--------|
| T1 | `docs/governance/STACK_REGISTRY.yaml` | Add ai-consolidation stack entry (VM 207) | **DONE** |
| T2 | `docs/governance/SHOP_VM_ARCHITECTURE.md` | Add dedicated subsections for download-stack (209) + streaming-stack (210) | **DONE** |
| T3 | `docs/governance/DEVICE_IDENTITY_SSOT.md` | Expand streaming-stack role to include all key services | **DONE** |
| T4 | `ops/bindings/services.health.yaml` | Add spotisub health check for streaming-stack (port 8766) | **DONE** |

### P1 — Binding Fixes

| Task | File | Action | Status |
|------|------|--------|--------|
| T5 | `ops/bindings/naming.policy.yaml` | Add ai-consolidation entry (VM 207) | **DONE** |
| T6 | `ops/bindings/naming.policy.yaml` | Fix observability: device_identity→true, compose_target→true, verification_state→verified | **DONE** |

### P2 — Staged Config Fixes

| Task | Target | Action | Status |
|------|--------|--------|--------|
| T7 | `ops/staged/ai-consolidation/docker-compose.yml` | Add Qdrant Docker HEALTHCHECK (wget /healthz) | **DONE** |

### P3 — Verify + Closeout

| Task | Action | Status |
|------|--------|--------|
| T8 | `spine.verify` — 50/50 drift gates pass | **DONE** |
| T9 | Update MEMORY.md with UDR7 status | **DONE** |
| T10 | Close loop | **DONE** |

---

## Receipts

- spine.verify: `RCAP-20260209-074632__spine.verify__Rfasu15988` — 50/50 PASS
- Commit: (pending — all edits staged, not yet committed)

---

## Deferred (tracked elsewhere, not in scope)

- Secrets namespace migration for media stacks (planned_key_paths → required_key_paths) — future loop
- ubuntu not in docker group on all VMs — convenience, no governance impact
- GAP-OP-059: Grafana admin secret path undocumented — deferred
- VM 209 timezone Etc/UTC — timezone loop closed, 209 exception noted

## Non-Goals

- Do NOT change any runtime configuration except T7 (Qdrant healthcheck)
- Do NOT address secrets migration (separate scope)
- Do NOT modify network configuration (UDR cutover is separate scope)

---

_Created: 2026-02-09_
_Closed: 2026-02-09_
