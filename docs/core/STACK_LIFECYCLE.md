# Stack Lifecycle (Spine-Governed)

Purpose: define how stacks are discovered, operated, and verified without "compose guessing" or ad-hoc SSH.

## Authority (No Guessing)

When you need to know **what is deployed** and **where it lives**:

- Live stack directories are declared in `ops/bindings/docker.compose.targets.yaml`
- SSH reachability/user/ports are declared in `ops/bindings/ssh.targets.yaml`
- Health probes are declared in `ops/bindings/services.health.yaml`
- VM-infra compose SSOT (sanitized) lives under `ops/staged/**` (see `docs/governance/COMPOSE_AUTHORITY.md`)
- Workbench compose is **supporting/reference only** (never a runtime dependency). See `docs/governance/WORKBENCH_TOOLING_INDEX.md` for the only approved external reference paths.

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
   - Compose: `ops/staged/**`
   - Bindings: `ops/bindings/**`
2. **Apply to the live host** (receipted):
   - Preferred: `docker.compose.*` capabilities for normal stack lifecycle operations.
   - If secrets injection is required: `secrets.exec -- <ssh ... docker compose ...>`
3. **Verify health**:
   - `docker.compose.status` (containers running)
   - `services.health.status` (HTTP probes)
4. **Close loops / update gaps**:
   - If anything fails: it becomes an open loop. Fix, verify, close with receipts.
5. **Sync supporting surfaces (optional)**:
   - If a change impacts workbench reference inventories, update those next (spine remains authoritative per `ops/bindings/cross-repo.authority.yaml`).
