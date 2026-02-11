# LOOP-CADDY-PROTO-FIX-20260209

> **Status:** CLOSED
> **Owner:** @ronny
> **Created:** 2026-02-09
> **Closed:** 2026-02-09
> **Severity:** high
> **Origin:** SSO browser test for Gitea (LOOP-DEV-TOOLS-GITEA-STANDARDIZATION-20260209 P6)

---

## Executive Summary

Authentik OAuth2 flow for Gitea SSO failed with "Request failed. Please try again later." Two root causes:

1. **Caddy proto header missing**: Caddy passed `X-Forwarded-Proto: http` to Authentik because CF tunnel terminates TLS upstream. Authentik generated `http://` OIDC URLs.
2. **Downstream OIDC cache stale**: After fixing Caddy, Gitea still had the old `http://` issuer cached in memory. Required a Gitea container restart.

This exposed a governance gap: no artifact tracked deployment dependencies (upstream config change → downstream restart required), and no gate validated the Caddy proto header.

---

## Tasks

| Task | Action | Status |
|------|--------|--------|
| T1 | Diagnose "Request failed" on auth.ronny.works OAuth flow | **DONE** |
| T2 | Add `header_up X-Forwarded-Proto https` to all Authentik proxy blocks | **DONE** |
| T3 | Sync staged Caddyfile with live (was missing forward-auth blocks) | **DONE** |
| T4 | Deploy to infra-core + Caddy reload | **DONE** |
| T5 | Verify OIDC discovery returns https:// URLs (all 4 providers) | **DONE** |
| T6 | Audit all Authentik providers/apps/flows/outpost for gaps | **DONE** — no config gaps |
| T7 | Verify all proxied services healthy post-reload | **DONE** — 5/5 pass |
| T8 | Restart Gitea to clear stale OIDC cache | **DONE** (user, separate terminal) |
| T9 | Register GAP-OP-063 (missing deployment dependency tracking) | **DONE** |
| T10 | Create `deploy.dependencies.yaml` binding (dependency chain map) | **DONE** |
| T11 | Create D51 `caddy-proto-lock` drift gate | **DONE** |
| T12 | spine.verify — 51/51 PASS | **DONE** |

---

## Root Cause

```
Browser (HTTPS) → Cloudflare Tunnel → cloudflared (HTTP) → Caddy (HTTP) → Authentik

1. Caddy's reverse_proxy sets X-Forwarded-Proto from what it sees (HTTP).
2. Authentik uses X-Forwarded-Proto to build OIDC URLs → generates http:// URLs.
3. Browser rejects mixed-content API calls → "Request failed."
4. After fix: Gitea had stale http:// issuer in OIDC discovery cache.
5. JWT tokens now contain https:// issuer but Gitea compared against cached http://.
6. Gitea restart cleared cache → SSO works.
```

## Authentik Config Audit (T6)

| Component | Count | Status |
|-----------|-------|--------|
| Providers | 4 (3 proxy + 1 OAuth2) | All external_host/redirect_uri use https:// |
| Applications | 4 (pihole, vault, secrets, gitea) | All launch_url use https:// |
| Outposts | 1 (embedded) | authentik_host + browser both https:// |
| Flows | 14 | Standard, auth flow has proper stages |
| Users | 2 (akadmin + outpost SA) | Active |
| OIDC discovery | 4 providers | All 9 endpoints per provider use https:// |

## Governance Artifacts Created

1. **`ops/bindings/deploy.dependencies.yaml`** — Maps upstream config changes to required downstream restarts
2. **`surfaces/verify/d51-caddy-proto-lock.sh`** — Validates Caddyfile has `X-Forwarded-Proto https` on all Authentik proxy blocks
3. **GAP-OP-063** — Registered in operational.gaps.yaml (fixed)

## Receipts

- spine.verify: `RCAP-20260209-081308__spine.verify__Rux8u65050` — 51/51 PASS

---

## Non-Goals

- Do NOT modify Authentik application/provider config (audit only)
- Do NOT add new Caddy sites
- Do NOT change CF tunnel routing

---

_Created: 2026-02-09_
_Closed: 2026-02-09_
