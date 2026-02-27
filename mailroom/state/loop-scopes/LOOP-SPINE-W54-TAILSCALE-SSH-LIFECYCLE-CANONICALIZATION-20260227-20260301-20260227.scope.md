---
loop_id: LOOP-SPINE-W54-TAILSCALE-SSH-LIFECYCLE-CANONICALIZATION-20260227-20260301-20260227
created: 2026-02-27
status: closed
owner: "@ronny"
scope: spine
priority: high
objective: Canonicalize Tailscale + SSH lifecycle contracts, parity gates, and runbooks so new VM/site/container onboarding cannot drift and machine monitors cannot trigger interactive auth loops.
---

# Loop Scope: LOOP-SPINE-W54-TAILSCALE-SSH-LIFECYCLE-CANONICALIZATION-20260227-20260301-20260227

## Objective

Canonicalize Tailscale + SSH lifecycle contracts, parity gates, and runbooks so new VM/site/container onboarding cannot drift and machine monitors cannot trigger interactive auth loops.

## Sequence
- Baseline classification + scope-clean isolation
- Forensic drift matrix
- Contracts + tombstones
- Gate/barrier rollout
- Runbooks + SOP
- Verification + acceptance

## Success Criteria
- No interactive auth loops from machine monitors
- SSH lifecycle parity enforced across authoritative sources
- No gate ID collisions
- Protected lanes untouched

## Definition Of Done
- Master receipt includes run keys, drift classes, gate modes, and decision
