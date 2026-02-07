# LOOP-INFRA-CADDY-AUTH-20260207

> **Status:** open
> **Blocked By:** LOOP-INFRA-VM-RESTRUCTURE-20260206
> **Owner:** @ronny
> **Created:** 2026-02-07
> **Severity:** medium

---

## Executive Summary

Add Caddy (reverse proxy) and Authentik (SSO/auth) to infra-core (VM 204). These are the final foundation services needed before exposing services externally with unified authentication.

---

## Stack Decisions (Locked In)

### Reverse Proxy: Caddy

| Factor | Decision |
|--------|----------|
| **Choice** | Caddy |
| **Rejected** | Traefik (more complex), nginx (manual) |
| **Rationale** | Auto-HTTPS, simple Caddyfile, agent-readable config |

### Authentication: Authentik

| Factor | Decision |
|--------|----------|
| **Choice** | Authentik |
| **Rejected** | Keycloak (heavier, Java, enterprise-focused) |
| **Rationale** | Lighter (~500MB), Python, modern UI, built-in proxy outpost |

---

## Target Architecture

### VM 204: infra-core (After This Loop)

| Service | Port | Purpose | Status |
|---------|------|---------|--------|
| Cloudflared | — | Tunnel to Cloudflare | Done |
| Pi-hole | 53, 80 | DNS + ad blocking | Done |
| Infisical | 8080 | Secrets management | Done |
| Vaultwarden | 8081 | Password vault | Cutover (soak) |
| **Caddy** | 80, 443 | Reverse proxy | **This loop** |
| **Authentik** | 9000, 9443 | SSO/Authentication | **This loop** |

### Why On infra-core

- Reverse proxy is foundational — all external traffic flows through it
- Auth is foundational — all protected services depend on it
- Co-location with Cloudflare tunnel enables: `Internet → Cloudflare → Caddy → Authentik → Service`

---

## Caddy Configuration Pattern

Example Caddyfile for protected service:

```caddyfile
# Global options
{
    email info@mintprints.com
}

# Grafana with Authentik forward auth
grafana.yourdomain.com {
    forward_auth authentik:9000 {
        uri /outpost.goauthentik.io/auth/caddy
        copy_headers X-Authentik-Username X-Authentik-Groups X-Authentik-Email
        trusted_proxies private_ranges
    }
    reverse_proxy observability:3000
}

# Public service (no auth)
status.yourdomain.com {
    reverse_proxy observability:3001
}
```

**Agent Note:** Caddyfile is human-readable. Add one block per service.

---

## Authentik Setup Pattern

### Components

| Component | Purpose |
|-----------|---------|
| Server | Core auth engine |
| Worker | Background tasks |
| PostgreSQL | Auth database (can share with Infisical or separate) |
| Redis | Session cache |
| Outpost | Proxy authentication (embedded or standalone) |

### Integration Flow

```
User → Cloudflare Tunnel → Caddy → Authentik Outpost → Backend Service
                              ↓
                    (if not authenticated)
                              ↓
                    Authentik Login Page
                              ↓
                    (after login, redirect back)
```

---

## Phases

| Phase | Scope | Dependency |
|-------|-------|------------|
| P1 | Deploy Caddy on infra-core | Blocked by VM INFRA Phase 2 promotion gate |
| P2 | Deploy Authentik on infra-core | P1 |
| P3 | Configure Authentik users/groups | P2 |
| P4 | Integrate Caddy + Authentik outpost | P3 |
| P5 | Protect first service (Grafana) | P4 |
| P6 | Update Cloudflare tunnel to route through Caddy | P5 |

---

## Compose Stack (Draft)

```yaml
# /home/ubuntu/stacks/caddy-auth/docker-compose.yml

services:
  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    network_mode: host  # For easy access to other services
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config

  authentik-server:
    image: ghcr.io/goauthentik/server:latest
    container_name: authentik-server
    restart: unless-stopped
    command: server
    environment:
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY}
      AUTHENTIK_REDIS__HOST: authentik-redis
      AUTHENTIK_POSTGRESQL__HOST: authentik-postgres
      AUTHENTIK_POSTGRESQL__USER: authentik
      AUTHENTIK_POSTGRESQL__PASSWORD: ${AUTHENTIK_DB_PASSWORD}
      AUTHENTIK_POSTGRESQL__NAME: authentik
    ports:
      - "9000:9000"
      - "9443:9443"
    depends_on:
      - authentik-postgres
      - authentik-redis

  authentik-worker:
    image: ghcr.io/goauthentik/server:latest
    container_name: authentik-worker
    restart: unless-stopped
    command: worker
    environment:
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY}
      AUTHENTIK_REDIS__HOST: authentik-redis
      AUTHENTIK_POSTGRESQL__HOST: authentik-postgres
      AUTHENTIK_POSTGRESQL__USER: authentik
      AUTHENTIK_POSTGRESQL__PASSWORD: ${AUTHENTIK_DB_PASSWORD}
      AUTHENTIK_POSTGRESQL__NAME: authentik
    depends_on:
      - authentik-postgres
      - authentik-redis

  authentik-postgres:
    image: postgres:15-alpine
    container_name: authentik-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: authentik
      POSTGRES_PASSWORD: ${AUTHENTIK_DB_PASSWORD}
      POSTGRES_DB: authentik
    volumes:
      - authentik_postgres:/var/lib/postgresql/data

  authentik-redis:
    image: redis:alpine
    container_name: authentik-redis
    restart: unless-stopped
    volumes:
      - authentik_redis:/data

volumes:
  caddy_data:
  caddy_config:
  authentik_postgres:
  authentik_redis:
```

---

## Secrets Required

| Secret | Project | Notes |
|--------|---------|-------|
| AUTHENTIK_SECRET_KEY | infrastructure | Generate with `openssl rand -base64 32` |
| AUTHENTIK_DB_PASSWORD | infrastructure | Postgres password |

Add to Infisical before deployment.

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| Caddy running on infra-core | `curl -I https://infra-core` returns 200 |
| Authentik accessible | `https://auth.yourdomain.com` shows login |
| Forward auth working | Protected service redirects to Authentik |
| Grafana protected | Can't access without login |

---

## Non-Goals

- Do NOT migrate all services to Caddy in this loop (just set up + first service)
- Do NOT configure complex RBAC (just basic users/groups)
- Do NOT set up SAML/enterprise federation

---

## Evidence

- Conversation with Opus 4.5 on 2026-02-07
- LOOP-INFRA-VM-RESTRUCTURE-20260206 (prerequisite)
- Stack decisions: Caddy over Traefik, Authentik over Keycloak

---

_Scope document created by: Opus 4.5_
_Created: 2026-02-07_
