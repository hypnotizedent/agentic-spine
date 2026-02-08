# LOOP-DEV-TOOLS-DEPLOY-20260208

> **Status:** open (P1 complete)
> **Blocked By:** none (unblocked 2026-02-08)
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** medium

---

## Executive Summary

Provision VM 206 on pve (shop R730XD) and deploy a self-hosted development toolchain: Gitea (lightweight Git forge), Gitea Actions runner, PostgreSQL, and optionally a container registry. This provides local CI/CD capability and reduces dependency on GitHub for homelab-specific repos.

---

## Stack Decisions (Locked In)

### Git Forge: Gitea

| Factor | Decision |
|--------|----------|
| **Choice** | Gitea |
| **Rejected** | GitLab (heavy — 4GB+ RAM, complex) |
| **Rationale** | Lighter footprint (~200MB RAM), Go binary, Actions-compatible, sufficient for homelab |

### CI Runner: Gitea Actions

| Factor | Decision |
|--------|----------|
| **Choice** | Gitea Actions (act runner) |
| **Rejected** | Drone CI (separate project, less integrated) |
| **Rationale** | Native integration, GitHub Actions-compatible YAML syntax |

---

## Target Architecture

### VM 206: dev-tools (shop R730XD)

| Service | Port | Purpose | Status |
|---------|------|---------|--------|
| Gitea | 3000 (HTTP), 2222 (SSH) | Git forge + web UI | This loop |
| Gitea Actions Runner | — | CI/CD runner (Docker-in-Docker) | This loop |
| PostgreSQL | 5432 | Gitea database | This loop |
| Container Registry | 5000 | OCI image registry (optional) | This loop |

### Provisioning Details

| Property | Value |
|----------|-------|
| **VM ID** | 206 |
| **Hypervisor** | pve (shop R730XD) |
| **Profile** | spine-ready-v1 |
| **Template** | 9000 (ubuntu-2404-cloudinit-template) |

---

## Phases

| Phase | Scope | Dependency |
|-------|-------|------------|
| P0 | Provision VM 206 with spine-ready-v1 | Blocked by LOOP-OBSERVABILITY-DEPLOY-20260208 |
| P1 | Deploy Gitea + PostgreSQL | P0 |
| P2 | Configure Gitea Actions runner | P1 |
| P3 | Integrate with Authentik SSO | P2 + LOOP-INFRA-CADDY-AUTH-20260207 |
| P4 | Migrate select repos from GitHub | P3 |
| P5 | Verify + closeout | P4 |

---

## Gitea Configuration Notes

### SSH Port Strategy

VM 206 host SSH runs on port 22. Gitea SSH must use a different approach:
- Option A: Gitea SSH on port 2222, NAT/alias for convenience
- Option B: Passthrough mode (Gitea uses host SSH authorized_keys)
- **Decision:** Option A — Gitea container SSH on port 2222 (host SSH keeps 22)

### Authentik Integration (P3)

Gitea supports OAuth2 providers natively:
```
; app.ini snippet
[oauth2]
ENABLED = true
```

Authentik provides an OAuth2/OpenID Connect provider that Gitea can consume directly.

---

## Repo Migration Plan (P4)

Only homelab-specific repos migrate. Public/collaboration repos stay on GitHub.

| Repo | Reason to Migrate |
|------|------------------|
| agentic-spine | Primary — spine runs locally, CI should too |
| workbench | Local automation, no external collaborators |
| infra-configs | Sensitive infrastructure configs |

**Note:** GitHub remains the remote for public/open-source work. Gitea mirrors or forks as needed.

---

## Secrets Required

| Secret | Project | Notes |
|--------|---------|-------|
| GITEA_DB_PASSWORD | infrastructure | PostgreSQL password |
| GITEA_SECRET_KEY | infrastructure | Internal token signing |
| GITEA_OAUTH_CLIENT_SECRET | infrastructure | For Authentik SSO |
| REGISTRY_HTTP_SECRET | infrastructure | Container registry auth (if deployed) |

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| VM 206 provisioned and spine-ready | SSH reachable, Tailscale joined |
| Gitea accessible | `https://git.ronny.works` shows login |
| PostgreSQL healthy | Gitea admin panel shows DB connected |
| Actions runner registered | Runner shows online in Gitea settings |
| SSO working | Login via Authentik redirects correctly |
| Test repo cloneable | `git clone git@git.ronny.works:ronny/test.git` works |

---

## Non-Goals

- Do NOT migrate all GitHub repos (only select homelab repos)
- Do NOT set up GitHub ↔ Gitea bidirectional sync in this loop
- Do NOT deploy Gitea Packages (use dedicated registry if needed)
- Do NOT configure complex branch protection rules yet

---

## Evidence

- Stack decision: Gitea over GitLab (lighter footprint, sufficient features)
- LOOP-OBSERVABILITY-DEPLOY-20260208 (prerequisite — monitoring must exist first)
- LOOP-INFRA-CADDY-AUTH-20260207 (SSO dependency for P3)

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_
