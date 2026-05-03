---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-10
scope: stack-lifecycle
---

# Stack Lifecycle (Spine-Governed)

Purpose: define how stacks are discovered, operated, and verified without "compose guessing" or ad-hoc SSH.

## Authority (No Guessing)

When you need to know **what is deployed** and **where it lives**:

- Live stack directories are authored in `ops/bindings/probe.registry.yaml` and projected to `ops/bindings/docker.compose.targets.yaml`
- SSH reachability/user/ports are declared in `ops/bindings/ssh.targets.yaml`
- Health probes are authored in `ops/bindings/probe.registry.yaml` and projected to `ops/bindings/services.health.yaml`
- Typed compose SSOT (sanitized) lives under `workbench/ops/{infra,domains}/**` (PACKET-597: was `agentic-foundation/ops/...` — agentic-foundation was absorbed into workbench on 2026-04-09 per LOCAL_CONTROL_PLANE_CONTRACT.md:26); archived transition material lives at the historical `agentic-foundation/docs/archive/ops-staged/` artifacts retained as evidence
- Workbench compose is now the canonical SSOT (PACKET-597 superseded the prior "supporting/reference only" framing). Query `~/code/workbench` directly when an external reference is required.

## Allowed Operations (Receipt-Producing)

Read-only:

- `./bin/ops cap run docker.compose.status`
- `./bin/ops cap run services.health.status`

Mutating (stack lifecycle):

- `./bin/ops cap run docker.compose.up <target> <stack> [service...]`
- `./bin/ops cap run docker.compose.down <target> <stack>`
- `./bin/ops cap run docker.compose.pull <target> <stack> [service...]`
- `./bin/ops cap run docker.compose.logs <target> <stack> [service...]` (read-only)

Secrets-bearing deploys:

- Use `./bin/ops cap run secrets.exec -- <cmd...>` when a stack must be run under injected secrets (Infisical) or when commands would otherwise expose secrets.

## Change Flow (End-to-End)

1. **Edit canonical SSOT** (spine-owned):
   - Compose: `workbench/ops/{infra,domains}/**` (PACKET-597: was
     `agentic-foundation/ops/...` — agentic-foundation was absorbed into
     workbench on 2026-04-09 per LOCAL_CONTROL_PLANE_CONTRACT.md:26)
   - Service/host/stack projection authority: `ops/bindings/probe.registry.yaml`
   - Bindings: `ops/bindings/**`
2. **Rebuild generated service projections**:
   - `./bin/ops cap run probe.registry.projection.build`
3. **Apply to the live host** (receipted):
   - Preferred: `docker.compose.*` capabilities for normal stack lifecycle operations.
   - If secrets injection is required: `secrets.exec -- <ssh ... docker compose ...>`
4. **Verify health**:
   - `docker.compose.status` (containers running)
   - `services.health.status` (HTTP probes)
5. **Close loops / update gaps**:
   - If anything fails: it becomes an open loop. Fix, verify, close with receipts.
6. **Sync supporting surfaces (optional)**:
   - If a change impacts workbench reference inventories, update those next (spine remains authoritative per `ops/bindings/cross-repo.authority.yaml`).
