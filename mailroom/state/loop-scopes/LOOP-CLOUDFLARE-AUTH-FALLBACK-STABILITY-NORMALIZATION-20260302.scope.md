---
loop_id: LOOP-CLOUDFLARE-AUTH-FALLBACK-STABILITY-NORMALIZATION-20260302
created: 2026-03-02
status: active
owner: "@ronny"
scope: cloudflare
priority: high
horizon: now
execution_readiness: runnable
objective: Stabilize Cloudflare auth path by eliminating token-invalid masking, reducing rate-limit flapping, and making D315 diagnostics deterministic.
---

# Loop Scope: LOOP-CLOUDFLARE-AUTH-FALLBACK-STABILITY-NORMALIZATION-20260302

## Objective

Stabilize Cloudflare auth path by eliminating token-invalid masking, reducing rate-limit flapping, and making D315 diagnostics deterministic.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-CLOUDFLARE-AUTH-FALLBACK-STABILITY-NORMALIZATION-20260302`

## Phases
- W0:  Capture token-only vs fallback auth matrix and baseline run keys
- W1:  Implement explicit token-health probe and fallback policy hardening
- W2:  Add 429 backoff/circuit-breaker behavior in high-call read paths
- W3:  Make D315 expose root error classification and fail deterministically
- W4:  Verify infra pack stability and close with evidence

## Success Criteria
- Token health is explicitly measurable without implicit global fallback masking.
- cloudflare.status and related read paths handle 429 with bounded retry and deterministic terminal state.
- D315 failure output includes root cause class (token_invalid, rate_limited, api_error) rather than generic fail.
- verify.pack.run infra passes Cloudflare lock path without auth-mode flapping.

## Definition Of Done
- Operator token-rotation evidence captured when required.
- Run keys for zone.list, status, inventory.sync, D315, verify.pack.run infra recorded pre/post.
- Gaps and loop artifacts linked and closure includes cleanup proof.
