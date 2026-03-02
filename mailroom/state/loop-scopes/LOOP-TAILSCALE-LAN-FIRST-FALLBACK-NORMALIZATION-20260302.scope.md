---
loop_id: LOOP-TAILSCALE-LAN-FIRST-FALLBACK-NORMALIZATION-20260302
created: 2026-03-02
status: closed
owner: "@ronny"
scope: tailscale
priority: high
horizon: now
execution_readiness: runnable
objective: Normalize host resolution to LAN->Tailscale fallback across SSH targets and service probes, with recurrence gate coverage and forensic traceability.
---

# Loop Scope: LOOP-TAILSCALE-LAN-FIRST-FALLBACK-NORMALIZATION-20260302

## Objective

Normalize host resolution to LAN->Tailscale fallback across SSH targets and service probes, with recurrence gate coverage and forensic traceability.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-TAILSCALE-LAN-FIRST-FALLBACK-NORMALIZATION-20260302`

## Phases
- W0:  Capture baseline LAN-vs-Tailscale reachability and container truth matrix
- W1:  Implement fallback in ssh.target.status for lan_first targets
- W2:  Normalize media/finance/observability/infra probes to binding-driven host resolver with fallback
- W3:  Add regression gate for fallback-aware resolution and off-LAN probe parity
- W4:  Execute end-to-end verify, classify friction, close loop with evidence

## Success Criteria
- All lan_first VM targets that are Tailnet-reachable are reported reachable by fallback-aware status capabilities even when LAN path fails.
- No target capability in scope hardcodes LAN-only IPs for shop VM probes.
- New fallback regression gate fails on LAN-only hardcoding or resolver drift and passes after normalization.
- verify.run -- fast passes after implementation with no introduced failing IDs.

## Definition Of Done
- Baseline + post-change run keys recorded for ssh.target.status, network.shop.audit.canonical, and scoped service status capabilities.
- All code changes constrained to allowlisted files and linked to loop artifacts.
- Friction findings filed/reconciled and linked to this loop.
- Loop scope moved to closed with cleanup proof and push confirmation.
