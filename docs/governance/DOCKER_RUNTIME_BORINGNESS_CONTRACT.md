---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-19
scope: docker-compose-runtime-boringness
---

# Docker Runtime Boringness Contract

Purpose: define the estate-wide boring contract for Docker Compose stacks so current stacks can be scored the same way and new stacks are born inside the same fence.

## Core Contract

1. One canonical compose truth per stack.
   Git is the authority. The host copy at `/opt/stacks/<stack>/docker-compose.yml` is a deployed mirror, not a second authority.

2. One canonical env surface per stack.
   The runtime env file is adjacent to the host compose root by default (`/opt/stacks/<stack>/.env`). Git keeps the shape via `.env.example`, runbook, or equivalent non-secret contract.

3. One canonical runtime path per stack.
   Managed Linux guests use `/opt/stacks/<stack>`. Home-directory stack roots are transitional exceptions only and must be explicitly documented with an exit criterion.

4. Stack identity must be declared in canon.
   A kept stack must be legible in:
   - `docs/governance/STACK_REGISTRY.yaml`
   - `docs/governance/SERVICE_REGISTRY.yaml`
   - `workbench/scripts/root/deploy/stack-map.sh` when dispatcher-managed

5. Image-first deploys are the default.
   Compose stacks pull and run images. Host-local `docker build` is break-glass or an explicitly justified exception.

6. Break-glass host builds are exceptional, not standard.
   Any kept host-build path must name the reason, the owner, and the exit criterion back to image-first boringness.

7. Healthchecks are required where the service can expose health.
   HTTP services should probe HTTP. TCP-only services should probe the listening socket. Internal support containers without a meaningful probe may be exempted in docs.

8. Restart policy, `stop_grace_period`, and resource limits are required.
   Every long-lived service must declare a restart policy and `stop_grace_period`. Every kept production service must declare at least a memory limit.

9. Stable labels are required for operator queries.
   Required labels:
   - `com.ronny.stack`
   - `com.ronny.service`
   - `com.ronny.env`

10. Production stacks need a rollback path.
    At minimum: previous compose file backup plus either a previous image path or a documented app/state restore path.

11. Production stacks need a smoke path.
    A named read-only verification command or status surface must exist and be runnable after deploy.

12. Stateful stacks need backup and restore proof.
    `backup.inventory.yaml` coverage and a restore runbook are mandatory. If restore proof is stale, the stack is not boring.

13. Docs and contracts must match live runtime truth.
    If the host path, compose root, env file, or service list changed, canon must change in the same wave.

14. No parallel compose authorities.
    There is never a "real" compose and a separate "prod" compose both claiming to be canonical for the same live stack.

## Standard Operating Model For New Stacks

Every new Docker/Compose stack must ship with:

- one repo compose root, normally `workbench/infra/compose/<stack>/docker-compose.yml`
- one non-secret env contract, normally `workbench/infra/compose/<stack>/.env.example`
- one host runtime root at `/opt/stacks/<stack>`
- one deploy mapping in `stack-map.sh` if operators will dispatch it
- one smoke/status path
- one rollback note
- backup + restore proof if the stack is stateful

## Done And Boring

A stack is "done and boring" when:

- repo compose truth, host compose mirror, and docs all agree
- one `.env` surface is declared and understood
- one runtime path exists and is not ambiguous
- runtime hardening is present (`restart`, `stop_grace_period`, healthchecks, limits, labels)
- smoke and rollback paths are explicit
- stateful recovery proof exists where required
