---
loop_id: LOOP-TAILSCALE-CONTROL-PLANE-HARDENING-20260302
created: 2026-03-02
status: active
owner: "@ronny"
scope: tailscale
priority: high
horizon: now
execution_readiness: runnable
objective: Control-plane hardening after LAN-first closure — ACL policy-as-code, enrollment security, DNS authority contract, Cloudflare/Tailscale coexistence, webhook/audit-log integration, zero-popup preservation.
---

# Loop Scope: LOOP-TAILSCALE-CONTROL-PLANE-HARDENING-20260302

## Objective

Control-plane hardening after LAN-first closure — ACL policy-as-code, enrollment security, DNS authority contract, Cloudflare/Tailscale coexistence, webhook/audit-log integration, zero-popup preservation.

## Parent Context

LOOP-TAILSCALE-SYSTEMIC-AUDIT-CANONICAL-20260301 (closed)

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-TAILSCALE-CONTROL-PLANE-HARDENING-20260302`

## Phases

- W0: Baseline capture + delta guard
- W1: ACL policy-as-code authority
- W2: Enrollment security hardening (OAuth + key lifecycle)
- W3: DNS + Cloudflare/Tailscale coexistence contracts
- W4: Webhooks + audit log integration contract
- W5: Verify + closeout

## Success Criteria

- ACL policy tracked in git with validate/apply workflow
- OAuth-scoped enrollment preferred over static auth key
- DNS authority documented with no ambiguity
- Cloudflare/Tailscale boundary explicit and gated
- Webhook/audit-log integration contract captured
- Zero interactive auth prompts in automation paths
- All new authority surfaces wired to gates/capabilities

## Definition Of Done

- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- No introduced verify failures.
- No open tailscale hardening gaps from this wave.
- Loop status can be moved to closed.
