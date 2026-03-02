---
loop_id: LOOP-CLOUDFLARE-CANONICAL-CONTROL-PLANE-20260302
created: 2026-03-02
status: closed
owner: "@ronny"
scope: cloudflare
priority: high
horizon: now
execution_readiness: runnable
objective: Canonicalize Cloudflare control-plane contracts/capabilities/routing so new services can be published securely with deterministic governance; resolve token/auth breakage and close Homarr + mail-archiver routing drift.
---

# Loop Scope: LOOP-CLOUDFLARE-CANONICAL-CONTROL-PLANE-20260302

## Objective

Canonicalize Cloudflare control-plane contracts/capabilities/routing so new services can be published securely with deterministic governance; resolve token/auth breakage and close Homarr + mail-archiver routing drift.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-CLOUDFLARE-CANONICAL-CONTROL-PLANE-20260302`

## Phases
- W0: runtime-baseline
- W1: authority-reconcile
- W2: capability-gap-closure
- W3: service-routing-rollout
- W4: gates-and-closeout

## Success Criteria
- Cloudflare API auth and zone/tunnel reads pass with run keys
- mail-archive + homarr routes canonicalized in DOMAIN_ROUTING_REGISTRY + tunnel ingress parity
- new-service publish transaction is governed and reproducible

## Definition Of Done
- verify.pack.run infra + communications pass except classified pre-existing
