# Gitea SSO Browser Test — 2026-02-09

> **Result:** PASS
> **Tested by:** ronny (hypnotizedent)
> **Date:** 2026-02-09 ~08:21 EST
> **Gaps closed:** GAP-OP-054
> **Loops updated:** LOOP-CADDY-PROTO-FIX-20260209 (T8), LOOP-DEV-TOOLS-GITEA-STANDARDIZATION-20260209 (P6)

---

## Test Flow

1. Navigated to `https://git.ronny.works` in browser
2. Clicked "Sign in with Authentik" on login page
3. Redirected to `https://auth.ronny.works` — Authentik login form
4. Authenticated with Authentik credentials
5. Redirected back to `https://git.ronny.works/user/link_account`
6. Clicked "Link to Existing Account" tab, entered Gitea `ronny` credentials
7. Successfully linked Authentik identity to Gitea `ronny` account
8. Logged in — Gitea dashboard visible with 2 repos, 94 contributions

## Issues Encountered and Resolved

### Issue 1: JWT Issuer Mismatch (pre-fix)
- **Error:** `oauth2: error validating JWT token: issuer in token does not match issuer in OpenIDConfig discovery`
- **Root cause:** Gitea container cached OIDC discovery document from before LOOP-CADDY-PROTO-FIX-20260209 deployed `X-Forwarded-Proto https` to Caddy. Cached issuer was `http://auth.ronny.works/...`, new JWT tokens had `iss: https://auth.ronny.works/...`.
- **Fix:** `docker restart gitea` on VM 206 to clear in-memory OIDC discovery cache.
- **Lesson:** After changing reverse proxy headers that affect OIDC issuer URLs, restart all downstream OIDC relying parties (Gitea, etc.) to flush cached discovery documents.

### Issue 2: Gitea "must change password" flag
- **Error:** `Username or password is incorrect.` on Link Account page
- **Root cause:** `gitea admin user change-password` CLI sets `must_change_password=true` by default, which blocks the OAuth link flow.
- **Fix:** Re-ran with `--must-change-password=false` flag.

## Verification Commands

```bash
# Confirmed OIDC discovery returns https:// issuer from VM 206
curl -s https://auth.ronny.works/application/o/gitea/.well-known/openid-configuration | jq .issuer
# "https://auth.ronny.works/application/o/gitea/"

# Confirmed JWT token via Caddy has correct iss claim
curl -s -X POST -H 'Host: auth.ronny.works' http://127.0.0.1:80/application/o/token/ \
  -d 'grant_type=client_credentials&client_id=...' | # decoded id_token
# iss: "https://auth.ronny.works/application/o/gitea/"

# Confirmed Gitea API accessible with linked account
curl -s -u 'ronny:...' http://localhost:3000/api/v1/user | jq .login
# "ronny"
```

## Screenshots (viewed in-session)
- `Screenshot 2026-02-09 at 8.01.41 AM.png` — Issuer mismatch error on git.ronny.works/user/login
- `Screenshot 2026-02-09 at 8.21.48 AM.png` — Successful login, Gitea dashboard with repos visible
