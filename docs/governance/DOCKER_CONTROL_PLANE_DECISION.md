---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-19
scope: docker-control-plane-posture
---

# Docker Control Plane Decision

Purpose: freeze the estate Docker control-plane posture so the future target is explicit without pretending adoption already happened.

## Decision

Current active system:

- spine remains the authority for governance, routing, smoke, and verification
- workbench remains the Git truth for compose files and non-secret env shape
- host runtime mirrors remain at `/opt/stacks/<stack>`
- governed SSH + `docker compose` remains the active executor

Preferred future target:

- Komodo

Fallback if Komodo is blocked:

- Dockhand

Fallback if control-plane adoption remains deferred long-term:

- Ansible orchestration over the existing spine + workbench + host-mirror model

## Not Adopted Yet

Komodo is not adopted in the estate today.
Dockhand is not adopted in the estate today.
No Docker control plane is being deployed in this wave.

The current boring target is not "install the tool."
The current boring target is "keep one explicit runtime contract and one explicit future decision."

## Why Komodo Is The Preferred Future Target

The 2026-03-19 tooling survey ranked Komodo first because it best matches the estate shape:

- Git-native reconciliation
- low-ceremony multi-host Compose operations
- explicit rollback path via Git history
- compatibility with spine-driven orchestration
- standard Docker/Compose exit path without inventing a second runtime model

## Why It Is Deferred

Komodo stays deferred until all of these are explicitly cleared:

1. License review
   Confirm the actual acceptability of the Komodo license for Ronny's environment and commercial obligations.

2. Security hardening and network posture
   Define the allowed control-plane topology, agent exposure rules, authentication posture, and credential rotation model before any rollout.

3. Bounded pilot scope
   Pick a 1-2 stack pilot with low blast radius and a rollback story before any estate-wide adoption.

## Estate Posture Until Then

Until those gates are cleared:

- current operations stay on the governed spine + workbench + host-mirror model
- Docker boringness work should continue to reduce compose/env/path ambiguity
- no UI or agent-based product may become a second compose authority

## What To Avoid

- Do not deploy Komodo or Dockhand just because the recommendation exists.
- Do not let a control plane become the source of truth ahead of Git/workbench canon.
- Do not broaden a future pilot into an estate rollout before the pilot proves topology, auth, and rollback.
