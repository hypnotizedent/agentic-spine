---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-26
scope: spine-wide-governance-sequence
loop: LOOP-SPINE-GOVERNANCE-NORMALIZATION-SEQUENCE-20260226-20260226
---

# Spine Governance Normalization Sequence

## Purpose

Provide one canonical sequence for governing every VM, container, and product surface without agents hunting context across scattered docs.

Machine contract:
- `ops/bindings/spine.governance.sequence.contract.yaml`

## What Already Exists (Current Authority)

| Layer | Canonical Source |
|------|------------------|
| VM identity/lifecycle | `ops/bindings/vm.lifecycle.yaml` |
| Stack inventory + compose authority | `docs/governance/STACK_REGISTRY.yaml`, `ops/bindings/docker.compose.targets.yaml` |
| Service runtime inventory | `docs/governance/SERVICE_REGISTRY.yaml` |
| Ingress/routing authority | `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml`, `docs/governance/INGRESS_AUTHORITY.md` |
| Service probe authority | `ops/bindings/services.health.yaml` |
| Communications alert queue SLO/dispatcher/retry | `ops/bindings/communications.alerts.queue.contract.yaml` |
| Escalation contract | `ops/bindings/communications.alerts.escalation.contract.yaml` |
| Legacy/deprecation policy | `docs/governance/LEGACY_DEPRECATION.md` |

Current problem:
- Authority exists, but execution flow is fragmented. Agents can read each file, but there was no single canonical sequence tying all layers together.

## Canonical Sequence

1. Resolve VM authority.
- Confirm lifecycle state in `vm.lifecycle.yaml`.

2. Resolve stack authority.
- Confirm compose/runtime paths in `STACK_REGISTRY.yaml` + `docker.compose.targets.yaml`.

3. Resolve service authority.
- Confirm service host/container/port/status in `SERVICE_REGISTRY.yaml`.

4. Resolve ingress authority.
- Confirm hostname target/routing layer in `DOMAIN_ROUTING_REGISTRY.yaml` + `INGRESS_AUTHORITY.md`.

5. Resolve probe authority.
- Confirm probe parity/coverage in `services.health.yaml`.

6. Resolve communications queue authority.
- Confirm dispatcher/retry/DLQ posture from communications queue contracts.

7. Resolve deprecation authority.
- Classify legacy artifacts as `safe_cleanup_now`, `verify_first`, or `defer`.

8. Verify and close.
- Run scoped verify pack.
- Close linked gaps with fixed-in receipt IDs.

## Plain Agent Model (How It Should Work)

1. Any domain emits work or alert intent.
2. System routes by canonical bindings, not ad-hoc host memory.
3. Dispatcher/worker sends intents automatically.
4. Delivery/probe logs record success or failure.
5. Failures retry with backoff, then move to dead-letter.
6. Agent only does three actions: `status`, `fix`, `replay/close`.

## Docker-Host Boundary

Use `ops/bindings/docker-host.deprecation.contract.yaml` for fragment cleanup.

Non-negotiable:
- Mint-OS runtime decommission remains deferred to Mint loops/agents.
- This sequence is the stepping-stool governance layer that removes confusion first.

## Canonical Commands

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run verify.route.recommend
./bin/ops cap run infra.docker_host.status
./bin/ops cap run communications.alerts.queue.status
./bin/ops cap run communications.alerts.dispatcher.status
./bin/ops cap run verify.pack.run infra
```
