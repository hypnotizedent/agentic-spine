---
loop_id: LOOP-TAILSCALE-AUTH-HARDENING-20260225
created: 2026-02-25
status: active
owner: "@ronny"
scope: infrastructure
priority: medium
objective: Eliminate recurring Tailscale browser re-authentication prompts on macbook by disabling node key expiry, reviewing tailnet session policy, and fixing the broken docker-tunnel LaunchAgent
---

# Loop Scope: LOOP-TAILSCALE-AUTH-HARDENING-20260225

## Objective

Trace and resolve the root cause of recurring browser-based Tailscale re-authentication prompts on macbook. Harden tailnet auth posture so the workstation node never requires manual browser re-auth.

## Background

- macbook node (100.85.186.7) created 2025-05-20, key expiry enabled (default)
- Tailscale daemon is healthy: BackendState=Running, HaveNodeKey=True, no health warnings
- Authentication manifests as browser opening to `login.tailscale.com` (OIDC re-auth via Google)
- Two root causes identified: (1) node key expiry triggers periodic re-auth, (2) tailnet session duration policy may enforce short OIDC sessions
- Secondary finding: `com.ronny.docker-tunnel` LaunchAgent (KeepAlive SSH to 100.92.156.118) is broken and spamming timeouts — not causing auth prompts but creates noise
- All 22 Tailscale peers are healthy; no expired peer keys
- No spine scripts, LaunchAgents, or verify gates call `tailscale up` or `tailscale login`
- SSH config (`~/.ssh/config.d/tailscale.conf`) and services.health.yaml use Tailscale IPs passively — they don't trigger auth flows

## Investigation Summary

- Checked: `tailscale status --json`, `tailscale debug prefs`, `tailscale serve status`, macOS system logs, all 15 custom LaunchAgents, zshrc, SSH config, all ops/ scripts
- Confirmed NOT caused by: session.start, verify gates, alerting.probe, mcp-runtime-anti-drift, bin/ops, any spine capability
- Confirmed IS caused by: Tailscale control plane OIDC session expiry + node key expiry (both require browser re-auth)

## Gaps Linked

- GAP-OP-926: Tailscale macbook node key expiry enabled — causes periodic browser re-auth (high)
- GAP-OP-927: Tailnet session duration policy not reviewed/configured (medium)
- GAP-OP-928: docker-tunnel LaunchAgent broken — KeepAlive SSH spamming timeouts (medium)

## Completion Criteria

- [ ] macbook node key expiry disabled in Tailscale admin console
- [ ] Tailnet session duration reviewed and set to appropriate interval
- [ ] docker-tunnel LaunchAgent fixed or disabled
- [ ] No Tailscale browser auth prompts for 30+ days post-fix

## Constraints

- CAPTURE-ONLY: This loop files gaps and documents findings. No runtime changes in this commit.
- Fixes require Tailscale admin console access (browser) and LaunchAgent plist edits (home surface)
