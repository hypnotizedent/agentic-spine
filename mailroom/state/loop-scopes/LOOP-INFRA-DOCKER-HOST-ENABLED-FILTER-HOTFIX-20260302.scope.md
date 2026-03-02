---
loop_id: LOOP-INFRA-DOCKER-HOST-ENABLED-FILTER-HOTFIX-20260302
created: 2026-03-02
status: closed
closed_at: "2026-03-02"
owner: "@ronny"
scope: infra
priority: medium
horizon: now
execution_readiness: runnable
objective: Fix yq enabled=false handling in infra.docker_host.status so disabled probes are not executed.
---

# Loop Scope: LOOP-INFRA-DOCKER-HOST-ENABLED-FILTER-HOTFIX-20260302

## Objective

Fix yq enabled=false handling in infra.docker_host.status so disabled probes are not executed.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-INFRA-DOCKER-HOST-ENABLED-FILTER-HOTFIX-20260302`

## Phases
- Step 1:  patch enabled selector semantics in infra.docker_host.status
- Step 2:  validate infra.docker_host.status and fast verify
- Step 3:  close loop with run-key evidence

## Success Criteria
- infra.docker_host.status respects enabled=false in services.health.yaml.
- Disabled docker-host probes are no longer executed.
- verify.run -- fast remains PASS.

## Definition Of Done
- Patch, validation run keys, and closed loop scope committed and pushed.

## Closure Evidence
- Patch: `ops/plugins/infra/bin/infra-docker-host-status`
- `CAP-20260302-034714__infra.docker_host.status__R1flc69023`
  result: `health probes ... none`, `summary: 0/0 probes healthy`, `status: OK`
- `CAP-20260302-034714__verify.run__R6kv369024`
  result: `verify.run fast 10/10 PASS`
