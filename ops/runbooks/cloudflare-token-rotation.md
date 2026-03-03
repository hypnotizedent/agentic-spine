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

1. **Generate new token** in Cloudflare dashboard:
   - Cloudflare Dashboard > My Profile > API Tokens > Create Token
   - Use "Edit zone DNS" template or match existing scopes
   - Required permissions: Zone:Read, DNS:Edit, Tunnel:Read, Registrar:Read

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
   ```
   - Confirm `auth_mode: token` (not global fallback)
   - Confirm no `fallback_used` line in output

5. **Run D315 gate**:
   ```bash
   bash surfaces/verify/d315-cloudflare-auth-readpath-health-lock.sh
   ```
   - Must return `D315 PASS`

## Post-Rotation

- Record evidence_refs in gap/loop closure:
  - Token health run key (step 3)
  - D315 run result (step 5)
- Revoke old token in Cloudflare dashboard

## Failure Recovery

If new token fails validation:
1. Do NOT revoke old token yet
2. Check token scopes match requirements above
3. Re-run `cloudflare.token.health --json` for detailed classification
4. If `rate_limited`: wait 60s and retry (Cloudflare rate-limits token creation)
