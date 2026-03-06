# Cloudflare API Token Rotation Runbook

## Purpose

Canonical operator procedure for rotating CLOUDFLARE_API_TOKEN with validation proof.

## When to Use

- Token health probe returns `token_invalid` or `rate_limited`
- D315 gate fails with `class=token_invalid`
- Scheduled rotation cadence

## Pre-Rotation

1. Run token health check:
   ```bash
   ./bin/ops cap run cloudflare.token.health
   ```
2. Record the run key and current status.

## Rotation Steps

1. **Generate new runtime token**:
   - Preferred bootstrap paths:
     - Cloudflare API using global key auth, or
     - a dedicated bootstrap token with `API Tokens Write`
   - Dashboard fallback:
     - Cloudflare Dashboard > My Profile > API Tokens > Create Token
   - Required active-runtime permissions:
     - `Zone Read`
     - `DNS Read`
     - `DNS Write`
     - `Cloudflare Tunnel Read`
     - `Cloudflare Tunnel Write`
     - `Registrar Domains Read`
     - `Pages Read`
     - `Workers Scripts Read`
     - `Workers Scripts Write`
     - `Workers R2 Storage Read`
   - Notes:
     - `Workers R2 Storage Read` is required by the active `cloudflare.r2.bucket.list` / `cloudflare.r2.object.list` surface, but the API can still return feature-state errors if R2 is not enabled on the account.
     - `Access` / `WAF` / mutating `Pages` / mutating `R2` scopes remain out of band until those capability waves are activated.

2. **Update Infisical**:
   - Path: `/spine/network/edge`
   - Key: `CLOUDFLARE_API_TOKEN`
   - Replace value with new token

3. **Validate immediately** (token-only, no fallback):
   ```bash
   ./bin/ops cap run cloudflare.token.health
   ```
   - Must return `status: valid`
   - Record the run key as evidence

4. **Run full read-path verification**:
   ```bash
   ./bin/ops cap run cloudflare.status
   ./bin/ops cap run cloudflare.zone.list
   ./bin/ops cap run cloudflare.tunnel.ingress.status
   ./bin/ops cap run cloudflare.pages.list
   ./bin/ops cap run cloudflare.workers.list
   ```
   - Confirm `auth_mode: token` (not global fallback)
   - Confirm no `fallback_used` line in output

5. **Run idempotent write proof**:
   - Re-apply an existing DNS record with the same value via `cloudflare-dns-record-set`
   - Re-apply an existing tunnel ingress rule with the same service via `cloudflare-tunnel-ingress-set`
   - Both must succeed with global fallback disabled

6. **Run D315 gate**:
   ```bash
   bash surfaces/verify/d315-cloudflare-auth-readpath-health-lock.sh
   ```
   - Must return `D315 PASS`

## Post-Rotation

- Record evidence_refs in gap/loop closure:
  - Token health run key (step 3)
  - D315 run result (step 6)
- Revoke old token in Cloudflare dashboard

## Failure Recovery

If new token fails validation:
1. Do NOT revoke old token yet
2. Check token scopes match requirements above
3. Re-run `cloudflare.token.health --json` for detailed classification
4. If `rate_limited`: wait 60s and retry (Cloudflare rate-limits token creation)
