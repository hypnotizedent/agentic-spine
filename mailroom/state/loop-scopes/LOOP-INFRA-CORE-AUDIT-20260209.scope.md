# LOOP-INFRA-CORE-AUDIT-20260209

> **Status:** OPEN
> **Owner:** @ronny
> **Created:** 2026-02-09
> **Severity:** medium
> **Origin:** VM 204 (infra-core) deep audit via 4 parallel subagents

---

## Executive Summary

A four-subagent audit of VM 204 (infra-core) across SSOTs, bindings, staged configs, and live SSH found the host operationally healthy (11 containers, all passing health checks) with two governance gaps:

1. STACK_REGISTRY.yaml missing caddy-auth and vaultwarden stack entries (registry claims to be canonical for stacks but omits 2 of 5 infra-core stacks)
2. DEVICE_IDENTITY_SSOT.md has no LAN IPs for shop VMs (only Tailscale; LAN IPs needed for NFS, local routing)

---

## Tasks

| Task | File | Action | Status |
|------|------|--------|--------|
| T1 | `docs/governance/STACK_REGISTRY.yaml` | Add caddy-auth + vaultwarden stack entries | OPEN |
| T2 | `docs/governance/DEVICE_IDENTITY_SSOT.md` | Add shop VM LAN IPs subsection | OPEN |
| T3 | spine.verify | Confirm 49/49 gates pass | OPEN |

## Non-Goals

- Do NOT change any runtime configuration
- Do NOT uncomment Grafana Caddy block (separate scope)
- Do NOT address low-severity findings (no swap, no caddy health check, accept-routes)

---

_Created: 2026-02-09_
