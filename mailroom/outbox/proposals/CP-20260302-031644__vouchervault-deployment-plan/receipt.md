# Proposal Receipt: CP-20260302-031644__vouchervault-deployment-plan

## What was done

Created loop scope and detailed deployment plan for VoucherVault, a self-hosted gift card management system:

1. **Loop Scope** (`mailroom/state/loop-scopes/LOOP-VOUCHERVAULT-DEPLOYMENT-20260302.scope.md`)
   - Defined 7-phase deployment plan
   - Set success criteria and definition of done
   - Horizon: later (deferred until user is ready)

2. **Deployment Plan** (`ops/staged/vouchervault/DEPLOYMENT_PLAN.md`)
   - Complete technical architecture documentation
   - Docker Compose configuration specifications
   - OIDC SSO integration with Authentik
   - Traefik ingress configuration
   - Apprise notification setup
   - SSOT update procedures
   - Backup strategy
   - Rollback plan

## Why

User requested a self-hosted solution for managing scattered gift cards:
- Physical gift cards stored in various locations
- Digital gift cards in emails
- Need for centralized, secure storage
- Mobile-friendly access for in-store redemption
- Expiry notifications to prevent waste
- Privacy concerns with third-party solutions

VoucherVault (455+ GitHub stars, actively maintained) addresses all these needs with:
- PWA support for mobile use
- OIDC SSO integration (compatible with existing Authentik)
- Barcode/QR code scanning and display
- Expiry notifications via Apprise
- PostgreSQL + Redis for reliability

## Constraints

- **Deployment target:** Recommended docker-host (VM 200) but proxmox-home is alternative
- **OIDC dependency:** Requires Authentik provider configuration
- **Resource requirements:** ~1GB RAM, PostgreSQL + Redis containers
- **Approval needed:** User must confirm deployment target and notification channels

## Expected outcomes

When applied and executed:
1. VoucherVault running on docker-host with Traefik ingress
2. Accessible via Tailscale at `vouchervault.ts.net`
3. OIDC SSO login working with Authentik credentials
4. Gift cards can be added with barcode/QR scanning
5. Mobile PWA installs and works offline
6. Expiry notifications sent via configured channels
7. SSOTs updated with new service entries
8. Backup strategy in place

## Next Steps

To execute this plan:
1. Promote loop to `horizon=now`: `./bin/ops cap run planning.horizon.set -- --loop-id LOOP-VOUCHERVAULT-DEPLOYMENT-20260302 --horizon now --readiness runnable`
2. Apply this proposal: `./bin/ops cap run proposals.apply CP-20260302-031644__vouchervault-deployment-plan`
3. Begin execution following the phased plan in DEPLOYMENT_PLAN.md
