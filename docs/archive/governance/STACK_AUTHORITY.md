---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-24
scope: stack-rules
---

# Stack Authority

This document defines the rules of record for where **authoritative compose configs** live, what counts as an **active stack**, and how operators should find the *live* runtime directories.

## Non-Negotiables

- Docs-first: this file documents authority; it does not change runtime.
- No runtime behavior changes unless explicitly scoped as its own loop/capability.
- Compose files in spine must be **sanitized** (no `.env` values committed).
- **Never guess live paths** on hosts; use bindings.

## Definitions

### Active stack

A stack is **active** if it meets all of the following:

- It has an authoritative compose source (see "Authoritative compose").
- It is deployed on at least one host referenced in `ops/bindings/docker.compose.targets.yaml`.
- It is not located under excluded paths (archives/worktrees/legacy).

### Authoritative compose

Authoritative compose comes from one of these sources:

1. **Foundation typed VM-infra SSOT:** `agentic-foundation/ops/{infra,domains}/**` (canonical, sanitized)
2. **Workbench supporting compose:** `/Users/ronnyworks/code/workbench/infra/compose/**` (supporting/reference for non-VM-infra stacks)

### Live runtime compose directory

The directory you actually run `docker compose` in on a host is declared in:

- `ops/bindings/docker.compose.targets.yaml` (SSOT)

This prevents drift between "what the repo says" and "what is actually deployed on host".

### Non-authoritative (excluded)

These paths are never authoritative:

- `.worktrees/**`
- `.archive/**`
- `ops/legacy/**`
- `docs/legacy/**`

## Foundation Typed Stack Roots

- `agentic-foundation/ops/infra/**`
- `agentic-foundation/ops/domains/**`
- `agentic-foundation/ops/staged/**` (interim residue only)

These roots contain sanitized compose/config for typed implementation source plus interim residue that has not been safely typed yet.

## Current VM-Infra Active Stacks (Inventory)

- cloudflared: `ops/infra/cloudflared/`
- caddy-auth: `ops/infra/caddy-auth/`
- secrets (Infisical): `ops/infra/secrets/`
- vaultwarden: `ops/infra/vaultwarden/`
- pihole: `ops/infra/pihole/`
- dev-tools/gitea: `ops/domains/dev-tools/gitea/`
- observability: `ops/infra/observability/*`
- download-stack: `ops/domains/download-stack/`
- streaming-stack: `ops/domains/streaming-stack/`

## Governance Links

- Compose locations: `docs/governance/COMPOSE_AUTHORITY.md`
- Domain routing SSOT: `ops/bindings/domain.routing.registry.yaml`
- Ingress authority: `docs/governance/INGRESS_AUTHORITY.md`
- Live compose paths binding: `ops/bindings/docker.compose.targets.yaml`
