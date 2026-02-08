---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
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

1. **Spine VM-infra SSOT:** `ops/staged/**` (canonical, sanitized)
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

## Spine VM-Infra Stack Root

- `ops/staged/**`

This root contains sanitized, repo-tracked compose/config for VM-infra stacks.

## Current VM-Infra Active Stacks (Inventory)

- cloudflared: `ops/staged/cloudflared/`
- caddy-auth: `ops/staged/caddy-auth/`
- secrets (Infisical): `ops/staged/secrets/`
- vaultwarden: `ops/staged/vaultwarden/`
- pihole: `ops/staged/pihole/`
- dev-tools/gitea: `ops/staged/dev-tools/gitea/`
- observability: `ops/staged/observability/*`
- download-stack: `ops/staged/download-stack/`
- streaming-stack: `ops/staged/streaming-stack/`

## Governance Links

- Compose locations: `docs/governance/COMPOSE_AUTHORITY.md`
- Domain routing SSOT: `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml`
- Ingress authority: `docs/governance/INGRESS_AUTHORITY.md`
- Live compose paths binding: `ops/bindings/docker.compose.targets.yaml`

