---
proposal_id: CP-VOUCHERVAULT-DEPLOYMENT-20260302
created: 2026-03-02T03:12:00Z
status: pending
parent_loop: LOOP-VOUCHERVAULT-DEPLOYMENT-20260302
owner: "@ronny"
scope: infrastructure-deployment
priority: medium
affects:
  - docker-host (VM 200) or proxmox-home
  - authentik (OIDC provider)
  - traefik (ingress)
  - SERVICE_REGISTRY.yaml
  - DEVICE_IDENTITY_SSOT.md
---

# Proposal: Deploy VoucherVault Self-Hosted Gift Card Management

## Summary

Deploy VoucherVault, a Django-based self-hosted web application for managing gift cards, vouchers, coupons, and loyalty cards. This addresses the user's need to consolidate physical and digital gift cards in one secure, self-hosted location with mobile-friendly access for in-store use.

## Background

**Problem Statement:**
- User has gift cards scattered across multiple locations (physical cards, emails, spreadsheets)
- Need centralized, secure storage for gift card numbers, balances, and expiry dates
- Need mobile access for in-store redemption
- Need expiry notifications to prevent gift card waste
- Privacy concerns with third-party gift card management apps

**Solution:**
VoucherVault is a mature (455+ GitHub stars), actively maintained Django application that provides:
- PWA support for mobile in-store use
- OIDC SSO integration (compatible with existing Authentik)
- Barcode/QR code scanning and display
- Expiry notifications via Apprise
- Transaction history tracking
- Multi-user support with sharing capabilities
- PostgreSQL + Redis backend for reliability

## Technical Architecture

### Application Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Web App | Django 5 | Main application |
| Database | PostgreSQL | Persistent data storage |
| Cache/Queue | Redis | Celery task queue + caching |
| Task Scheduler | Celery Beat | Periodic expiry checks |
| Notifications | Apprise | Multi-channel notifications |
| Frontend | PWA | Mobile-optimized interface |

### Deployment Target Options

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **docker-host (VM 200)** | Existing compose patterns, Traefik ingress, centralized | Shop rack, more critical | **Primary** |
| **proxmox-home (Beelink)** | Home location, less critical, good for personal tools | Limited RAM (27GB shared), no Traefik | Alternative |
| **New LXC** | Isolation, lightweight | Additional management overhead | Not recommended |

**Recommendation:** Deploy to `docker-host` (VM 200) as part of the existing compose infrastructure, leveraging existing Traefik ingress and PostgreSQL patterns.

### Integration Points

| Integration | Method | Configuration |
|-------------|--------|---------------|
| OIDC SSO | Authentik | New provider + app in Authentik |
| Ingress | Traefik | New router + service |
| Notifications | Apprise | Configure for existing notification channels |
| DNS | Tailscale | `vouchervault` hostname via MagicDNS |

## Implementation Plan

### Phase 1: Foundation Setup

**Step 1.1: Create Compose Configuration**
- Location: `/opt/stacks/vouchervault/docker-compose.yml` on docker-host
- Services: vouchervault, redis, db (PostgreSQL)
- Networks: traefik_proxy (external), internal
- Volumes: postgres_data, redis_data, static_files, media_files

**Step 1.2: Configure Environment Variables**
```yaml
# Core settings
DOMAIN: vouchervault.ts.net
SECURE_COOKIES: "True"
TZ: America/Los_Angeles

# Database
DB_ENGINE: postgres
POSTGRES_HOST: db
POSTGRES_USER: vouchervault
POSTGRES_PASSWORD: <from-infisical>
POSTGRES_DB: vouchervault

# Redis
REDIS_URL: redis://redis:6379/0

# OIDC (Authentik)
OIDC_ENABLED: "True"
OIDC_RP_CLIENT_ID: <from-infisical>
OIDC_RP_CLIENT_SECRET: <from-infisical>
OIDC_OP_AUTHORIZATION_ENDPOINT: https://auth.mintprints.co/application/o/authorize/
OIDC_OP_TOKEN_ENDPOINT: https://auth.mintprints.co/application/o/token/
OIDC_OP_USER_ENDPOINT: https://auth.mintprints.co/application/o/userinfo/
OIDC_OP_JWKS_ENDPOINT: https://auth.mintprints.co/application/o/vouchervault/jwks/
OIDC_RP_SIGN_ALGO: RS256

# Notifications
EXPIRY_THRESHOLD_DAYS: "30"
EXPIRY_LAST_NOTIFICATION_DAYS: "7"
```

**Step 1.3: Traefik Configuration**
- Router: `vouchervault-router`
- Rule: `Host(`vouchervault.ts.net`)`
- EntryPoints: websecure
- TLS: certResolver: letsencrypt
- Middlewares: authentik-forward-auth (optional, for additional protection)

### Phase 2: OIDC Provider Setup (Authentik)

**Step 2.1: Create Application in Authentik**
- Name: VoucherVault
- Slug: vouchervault
- Launch URL: https://vouchervault.ts.net

**Step 2.2: Create Provider**
- Type: OAuth2/OpenID Connect
- Client ID: Auto-generated
- Client Secret: Auto-generated (store in Infisical)
- Redirect URIs: https://vouchervault.ts.net/oidc/callback/
- Signing Key: RSA 256

**Step 2.3: Configure Claims**
- Email: required
- Name: preferred
- Groups: optional (for future multi-user)

### Phase 3: Deployment Execution

**Step 3.1: Pre-deployment Checklist**
- [ ] Infisical secrets created: `infrastructure/prod:/spine/shop/vouchervault/*`
- [ ] Authentik provider configured
- [ ] Traefik router tested (dry-run)
- [ ] docker-host disk space verified (>10GB free)

**Step 3.2: Deploy Stack**
```bash
# On docker-host
cd /opt/stacks/vouchervault
sudo docker compose pull
sudo docker compose up -d
```

**Step 3.3: Initialize Database**
- Django migrations run automatically on startup
- Default admin user created (password in logs)

**Step 3.4: Verify Deployment**
```bash
# Health check
curl -s https://vouchervault.ts.net/health

# OIDC flow test
open https://vouchervault.ts.net/oidc/callback/
```

### Phase 4: Notification Configuration

**Step 4.1: Configure Apprise URLs**
- User profile settings → Notification URLs
- Options: Discord webhook, Email (SMTP), Pushover, etc.

**Step 4.2: Schedule Expiry Checks**
- Default: Daily at 9AM (Celery Beat pre-configured)
- Threshold: 30 days advance notice + 7 days final reminder

### Phase 5: SSOT Updates

**Step 5.1: Update DEVICE_IDENTITY_SSOT.md**
```yaml
# Add to Tier 2 services
- hostname: vouchervault
  tailscale_ip: <assigned>
  role: Personal finance tool
  vm_host: docker-host (200)
```

**Step 5.2: Update SERVICE_REGISTRY.yaml**
```yaml
vouchervault:
  host: docker-host
  url: https://vouchervault.ts.net
  health: /health
  tier: 2
  category: finance
```

**Step 5.3: Update docker.compose.targets.yaml**
```yaml
vouchervault:
  path: /opt/stacks/vouchervault
  host: docker-host
  compose_file: docker-compose.yml
```

### Phase 6: Backup Strategy

**Step 6.1: PostgreSQL Backup**
- Add to existing backup automation
- Schedule: Daily at 4:00 AM
- Retention: 7 days
- Location: /tank/backups/vouchervault/

**Step 6.2: Volume Backup**
- Include in vzdump backup of docker-host (already configured)

## Rollback Plan

1. **Stop Services**: `docker compose down`
2. **Remove Traefik Router**: Delete router configuration
3. **Disable Authentik App**: Set to disabled
4. **Preserve Data**: Volume data persists, can restore if needed

## Success Criteria

- [ ] VoucherVault accessible at https://vouchervault.ts.net
- [ ] OIDC SSO login works with Authentik credentials
- [ ] Gift cards can be added with barcode/QR scanning
- [ ] Mobile PWA installs and works offline
- [ ] Expiry notifications sent via configured channels
- [ ] All services healthy in health checks
- [ ] SSOTs updated with new service
- [ ] Backup verified

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| OIDC integration issues | Medium | High | Test with Authentik dev provider first |
| Resource contention on docker-host | Low | Medium | Monitor resource usage, can migrate to proxmox-home |
| Data loss | Low | High | PostgreSQL backups + volume backups |
| App abandonment | Low | Low | SQLite fallback, data export available |

## Dependencies

- Authentik (OIDC provider) - available at auth.mintprints.co
- Traefik (ingress) - running on docker-host
- PostgreSQL - running on docker-host
- Redis - running on docker-host
- Tailscale (networking) - MagicDNS for hostname resolution

## Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Foundation | 1-2 hours | None |
| Phase 2: OIDC Setup | 30 minutes | Phase 1 |
| Phase 3: Deployment | 30 minutes | Phase 1, 2 |
| Phase 4: Notifications | 15 minutes | Phase 3 |
| Phase 5: SSOT Updates | 15 minutes | Phase 3 |
| Phase 6: Backup | 15 minutes | Phase 3 |

**Total Estimated Time:** 3-4 hours

## Files to Create/Modify

### Create
- `/opt/stacks/vouchervault/docker-compose.yml`
- `/opt/stacks/vouchervault/.env` (from Infisical)
- `ops/staged/vouchervault/README.md`
- `ops/staged/vouchervault/docker-compose.yml` (staged copy)

### Modify
- `ops/bindings/docker.compose.targets.yaml` - add vouchervault target
- `docs/governance/DEVICE_IDENTITY_SSOT.md` - add hostname
- `docs/governance/SERVICE_REGISTRY.yaml` - add service entry
- Infisical: `infrastructure/prod:/spine/shop/vouchervault/*`

## Approval Required

- [ ] @ronny: Confirm deployment target (docker-host vs proxmox-home)
- [ ] @ronny: Confirm notification channels for expiry alerts

## References

- VoucherVault GitHub: https://github.com/l4rm4nd/VoucherVault
- VoucherVault Wiki: https://github.com/l4rm4nd/VoucherVault/wiki
- VoucherVault Docker: https://hub.docker.com/r/l4rm4nd/vouchervault
- Authentik OIDC Docs: https://goauthentik.io/docs/providers/oauth2
