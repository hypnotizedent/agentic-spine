---
loop_id: LOOP-TAILSCALE-AUTH-HARDENING-20260225
created: 2026-02-25
status: closed
owner: "@ronny"
scope: infrastructure
priority: medium
objective: Eliminate recurring Tailscale browser re-authentication prompts on macbook by disabling node key expiry, reviewing tailnet session policy, and fixing the broken docker-tunnel LaunchAgent
---

# Loop Scope: LOOP-TAILSCALE-AUTH-HARDENING-20260225

## Objective

Trace and resolve the root cause of recurring browser-based Tailscale re-authentication prompts on macbook. Harden tailnet auth posture so the workstation node never requires manual browser re-auth.

## Root Cause (FINAL)

**Tailscale v1.90+ encrypted local state regression** (github.com/tailscale/tailscale issues #17645, #18097). Version 1.90 added encrypted local state support which loses machine keys on macOS restart/relaunch, forcing browser re-auth at login.tailscale.com. Fix was supposed to land in v1.92.0 but some users still report it on v1.94.2.

Key expiry was already disabled on macbook — this was NOT the cause. Session duration policy is not configurable on personal Tailscale plans and is also not the cause.

## Background

- macbook node (100.85.186.7) created 2025-05-20, key expiry ALREADY disabled
- macOS 26.3 (Sequoia), Tailscale v1.92.1 (App Store), EncryptState=true
- Tailscale daemon healthy: BackendState=Running, HaveNodeKey=True, no health warnings
- All 22 Tailscale peers healthy, no expired peer keys
- No spine scripts, LaunchAgents, or verify gates call `tailscale up` or `tailscale login`
- docker-tunnel LaunchAgent was broken (SSH timeout spam) — fixed separately

## Investigation Summary

- Checked: `tailscale status --json`, `tailscale debug prefs`, `tailscale serve status`, macOS system logs, all 15 custom LaunchAgents, zshrc, SSH config, all ops/ scripts, Tailscale admin API (devices + tailnet settings + ACL)
- Confirmed NOT caused by: session.start, verify gates, alerting.probe, mcp-runtime-anti-drift, bin/ops, key expiry, session duration policy
- Confirmed IS caused by: Tailscale v1.90+ encrypted state regression losing machine keys on restart

## Actions Taken

1. **Key expiry disabled on ALL 23 devices** via Tailscale admin API (macbook was already disabled; 16 VMs newly disabled)
2. **TAILSCALE_API_KEY provisioned** in Infisical at /spine/vm-infra/provisioning for future admin API automation
3. **docker-tunnel LaunchAgent hardened**: added ConnectTimeout=10, ExitOnForwardFailure=yes, ServerAliveCountMax=3, ThrottleInterval=30
4. **Root cause documented**: Tailscale encrypted state bug, not key expiry or session duration

## Gaps Linked (all CLOSED)

- GAP-OP-926 (fixed): Key expiry disabled on all 23/23 devices via admin API
- GAP-OP-927 (fixed): Root cause identified as v1.90+ encrypted state bug, not session duration. API key provisioned for future automation.
- GAP-OP-928 (fixed): docker-tunnel plist hardened with timeout/retry controls, LaunchAgent reloaded

## Remaining Watch Item

- If browser re-auth persists after next Mac restart: update Tailscale to latest via App Store. If still occurring, file bug referencing github.com/tailscale/tailscale/issues/18097 with macOS 26.3 details.
