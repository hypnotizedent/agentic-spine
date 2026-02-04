# Stack Authority

> **Status:** authoritative
> **Last verified:** 2026-02-04

This document defines the rules of record for where **authoritative compose configs** live, what counts as an **active stack**, and how deploy automation interacts with these stacks.

## Non-negotiables

- Docs-first: this file documents authority; it does not change runtime.
- No runtime behavior changes unless explicitly scoped and approved as its own issue.
- Keep diffs small, reversible, and verified.
- Secrets rotation and git history rewrite are explicitly deferred.

## Definitions

### Active stack
A stack is **active** if it meets all of the following:
- It has one or more compose files under known stack roots (see "Stack Roots").
- It is referenced by deploy tooling / automation, or is part of current infrastructure operations.
- It is **not** located under excluded paths (archives/worktrees).

### Authoritative compose
A compose file is **authoritative** if:
- It lives inside the repo under a stack root (see below), AND
- It is the intended source of truth for that stack's configuration (even if deployment copies it elsewhere), AND
- It is not an archived / legacy copy.

> Note: Some deploy workflows operate on a *checked-out copy* under `~/stacks/...` on `docker-host`. The repo remains the SSOT for what those files should be.

### Non-authoritative (excluded)
The following paths are **never** authoritative:
- `.archive/**`
- `.worktrees/**`
- any `legacy/`, `deprecated/`, `backup/` mirrors (if added later)

## Stack roots

The authoritative stack roots in this repo are:

- `infrastructure/**`
- `finance/**`
- `media-stack/**`
- `modules/**`

## Current active stacks (inventory)

This inventory is derived from the Epic 2 evidence run (compose inventory excluding archive/worktrees).

### infrastructure/docker-host/mint-os (4 compose files)
- `infrastructure/docker-host/mint-os/docker-compose.yml`
- `infrastructure/docker-host/mint-os/docker-compose.frontends.yml`
- `infrastructure/docker-host/mint-os/docker-compose.minio.yml`
- `infrastructure/docker-host/mint-os/docker-compose.monitoring.yml`

Notes:
- This stack is fragmented across multiple compose files by design today.
- Consolidation is explicitly out-of-scope unless created as a separate issue.

### finance (2 compose files)
- `finance/docker-compose.yml`
- `finance/mail-archiver/docker-compose.yml`

### media-stack (1 compose file)
- `media-stack/docker-compose.yml`

### infrastructure (standalone stacks; 7 compose files)
- `infrastructure/cloudflare/tunnel/docker-compose.yml`
- `infrastructure/dashy/docker-compose.yml`
- `infrastructure/n8n/docker-compose.yml`
- `infrastructure/pihole/docker-compose.yml`
- `infrastructure/secrets/docker-compose.yml`
- `infrastructure/storage/docker-compose.yml`
- `infrastructure/templates/docker-compose.template.yml`

### modules/files-api (1 compose file)
- `modules/files-api/docker-compose.yml`

### infrastructure/mcpjungle (1 compose file)
- `infrastructure/mcpjungle/docker-compose.yml`

## Deploy / authority model

### CI deploy workflows (current pattern)
- Runner: `docker-host` (self-hosted)
- Deploy target directory (default): `DEPLOY_STACK_DIR=~/stacks/mint-os`
- Command pattern: `docker compose restart <service>`

Implications:
- Deploy workflows operate on the `docker-host` working directory and restart services by name.
- The repo SSOT must maintain consistent service naming across compose files for deploy reliability.
- CI portability guidance is tracked in `docs/governance/CI_PORTABILITY.md`.

## Duplicate service names (inventory only)

Duplicate service names exist across stacks and compose files. This is not a problem by itself, but it becomes important when:
- multiple compose files are used together, or
- deploy automation assumes unique service identity.

Top duplicates observed (evidence):
- `redis` (5) — mint-os, n8n, finance, secrets, template
- `postgres` (4) — mint-os, n8n, finance, template
- `minio` (3) — mint-os (x2), storage

Action:
- Track duplicates in a machine-readable registry (see `STACK_REGISTRY.yaml`).
- Consolidation/refactor is out-of-scope unless explicitly planned.

## Governance links
- **[Governance Index](./README.md)** — Entry point for all governance docs
- CI portability assumptions: `docs/governance/CI_PORTABILITY.md`
- Domain routing SSOT: `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml`
- Stack registry: `docs/governance/STACK_REGISTRY.yaml`
