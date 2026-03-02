---
loop_id: LOOP-VOUCHERVAULT-DEPLOYMENT-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: vouchervault
priority: medium
horizon: later
execution_readiness: runnable
objective: Deploy VoucherVault self-hosted gift card management system with OIDC SSO integration
---

# Loop Scope: LOOP-VOUCHERVAULT-DEPLOYMENT-20260302

## Objective

Deploy VoucherVault self-hosted gift card management system with OIDC SSO integration

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-VOUCHERVAULT-DEPLOYMENT-20260302`

## Phases
- Step 1:  Research and validate VoucherVault deployment options
- Step 2:  Create Docker Compose configuration with PostgreSQL + Redis
- Step 3:  Configure OIDC SSO with Authentik
- Step 4:  Deploy to target infrastructure (docker-host or proxmox-home)
- Step 5:  Configure Traefik ingress and TLS
- Step 6:  Set up Apprise notifications for expiry alerts
- Step 7:  Validate mobile PWA functionality

## Success Criteria
- VoucherVault accessible via Tailscale
- OIDC SSO working with Authentik
- Gift cards can be added and managed
- Expiry notifications working via Apprise
- Mobile PWA functional for in-store use

## Definition Of Done
- All services healthy and accessible
- Documentation updated in SSOTs
- Backup strategy defined
