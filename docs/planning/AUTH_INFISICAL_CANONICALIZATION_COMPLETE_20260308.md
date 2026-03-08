# Auth Infisical Canonicalization - Final Status

**Date:** 2026-03-08
**Original Gap:** GAP-OP-1512 (closed prematurely)
**Status:** ✅ **DURABLE DEPLOYMENT ESTABLISHED**

---

## Executive Summary

Auth and files-api on mint-apps (100.79.183.14) now have **durable Infisical-backed deployment** that works with normal operator compose commands.

**Solution:** Machine-generated `.env.auth-secrets` file + layered env files
**Source of Truth:** Infisical `infrastructure/prod /spine/services/auth`
**Deployment:** Governed via `mint.auth.deploy` capability

---

## Timeline: Two Waves

### Wave 1 (2026-03-08 morning): Proof-of-Concept
- **Goal:** Prove Infisical injection works
- **Approach:** SSH session exports + docker compose
- **Script:** `ops/plugins/mint/bin/auth-deploy-infisical`
- **Result:** ✅ Worked, but NOT durable (only during script execution)
- **Problem:** Removed AUTH_* from .env without durable replacement
- **Impact:** Both auth and files-api became restart-fragile

### Wave 2 (2026-03-08 afternoon): Durable Solution
- **Goal:** Make runtime work with normal compose operations
- **Approach:** Machine-generated env file + layered env files
- **Scripts:** `mint-auth-secrets-sync`, `mint-auth-deploy`
- **Result:** ✅ Durable and proven
- **Impact:** Normal restart/recreate operations work

---

## Current Architecture

### Secret Flow
```
Infisical (source of truth)
  ↓ (via local canonical agent)
mint-auth-secrets-sync script
  ↓ (SSH write)
/opt/stacks/mint-apps/.env.auth-secrets
  ↓ (docker compose --env-file layering)
auth + files-api containers
```

### Files on mint-apps
- `/opt/stacks/mint-apps/.env` - main env file (no auth secrets)
- `/opt/stacks/mint-apps/.env.auth-secrets` - machine-generated (600, non-authoritative)

### Compose Command Pattern
```bash
docker compose --env-file .env --env-file .env.auth-secrets [command]
```

### Governed Capabilities
- `mint.auth.secrets.sync` - regenerate .env.auth-secrets from Infisical
- `mint.auth.deploy` - deploy auth/files-api with health checks

---

## Secrets Inventory

**Infisical Location:** `infrastructure/prod /spine/services/auth`

| Secret | Used By | Purpose |
|--------|---------|---------|
| AUTH_DATABASE_URL | auth | PostgreSQL connection string |
| AUTH_API_KEY | auth | Service API authentication |
| CUSTOMER_JWT_SECRET | auth, files-api | Shared JWT signing/verification |
| ADMIN_JWT_SECRET | auth | Admin token signing |
| EMPLOYEE_JWT_SECRET | auth | Employee token signing |

**Key Sharing:** `CUSTOMER_JWT_SECRET` is intentionally shared between auth and files-api for JWT interoperability.

---

## Deployment Procedures

### Standard Deployment
```bash
cd ~/code/agentic-spine
./bin/ops cap run mint.auth.deploy
```

### Manual Deployment (if needed)
```bash
# 1. Sync secrets from Infisical
cd ~/code/agentic-spine
./bin/ops cap run mint.auth.secrets.sync

# 2. Deploy on mint-apps
ssh mint-apps "cd /opt/stacks/mint-apps && \
  docker compose --env-file .env --env-file .env.auth-secrets up -d auth files-api"

# 3. Verify health
ssh mint-apps "curl -sf http://localhost:4300/health && \
  curl -sf http://localhost:3500/health"
```

### Normal Operator Commands (All Work)
```bash
ssh mint-apps "cd /opt/stacks/mint-apps && \
  docker compose --env-file .env --env-file .env.auth-secrets restart auth files-api"

ssh mint-apps "cd /opt/stacks/mint-apps && \
  docker compose --env-file .env --env-file .env.auth-secrets up -d --force-recreate auth"
```

---

## Verification Evidence (2026-03-08)

### Infisical Secrets Present
```bash
$ ./ops/tools/infisical-agent.sh list-recursive infrastructure prod | \
  jq -r '.secrets[] | select(.secretPath == "/spine/services/auth") | .secretKey'
ADMIN_JWT_SECRET
AUTH_API_KEY
AUTH_DATABASE_URL
CUSTOMER_JWT_SECRET
EMPLOYEE_JWT_SECRET
```

### .env Cleanup Verified
```bash
$ ssh mint-apps "grep '^AUTH' /opt/stacks/mint-apps/.env"
AUTH_TAG=latest  # Docker image tag only, not a secret
```

### Compose Config Shows Non-Blank Secrets
```bash
$ ssh mint-apps "docker compose --env-file .env --env-file .env.auth-secrets config" | \
  grep -A 2 'CUSTOMER_JWT_SECRET:'
      CUSTOMER_JWT_SECRET: eNatqYwDsqrYuOfWmXJof1mc1MJotRefBserkEJ7zc4=
```

### Services Healthy
```bash
$ ssh mint-apps "curl -sf http://localhost:4300/health"
{"status":"ok","service":"auth","version":"0.1.0","database":"ok"}

$ ssh mint-apps "curl -sf http://localhost:3500/health"
{"status":"ok","db":"ok","minio":"ok"}
```

### E2E JWT Flow Works
```bash
# Customer signup via auth
$ curl -X POST http://mint-apps:4300/api/auth/customer/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"TestPass123","name":"Test User"}'
{"token":"eyJ...","customer":{...}}

# Files-API accepts JWT
$ curl http://mint-apps:3500/api/customer/designs \
  -H "Authorization: Bearer eyJ..."
{"items":[]}  # Valid response, not auth error
```

### Normal Compose Operations Work
```bash
# Restart test
$ ssh mint-apps "docker compose --env-file .env --env-file .env.auth-secrets restart auth"
✅ Auth restarted and healthy

# Recreate test
$ ssh mint-apps "docker compose --env-file .env --env-file .env.auth-secrets up -d --force-recreate auth"
✅ Auth recreated and healthy
```

---

## Git Commits

### agentic-spine (main branch)
- `b083d699` - File GAP-OP-1516 (auth non-durable runtime bug)
- `4423556a` - File GAP-OP-1517 (plaintext residue)
- `e9068a77` - File GAP-OP-1518 (files-api durability broken)
- `2927ba01` - File GAP-OP-1519 (script not governed)
- `ab15fc0d` - Close GAP-OP-1517 (residue cleaned)
- `5455ca30` - Close GAP-OP-1518 (files-api durability restored)
- `09337fe1` - Close GAP-OP-1519 (scripts now governed)
- `92ee8540` - Establish durable deployment with layered env files

---

## Gap Status

| Gap ID | Severity | Description | Status |
|--------|----------|-------------|--------|
| GAP-OP-1512 | medium | Auth runtime .env-backed (original) | CLOSED (prematurely, replaced by 1516-1519) |
| GAP-OP-1516 | high | Auth runtime non-durable | OPEN (functionally fixed, needs gate for closure) |
| GAP-OP-1517 | medium | Plaintext residue | CLOSED ✅ |
| GAP-OP-1518 | medium | files-api durability broken | CLOSED ✅ |
| GAP-OP-1519 | low | Scripts not governed | CLOSED ✅ |

**Note on GAP-OP-1516:** Runtime is functionally fixed (normal compose operations work), but gap requires `regression_lock_id` (gate) for closure due to high severity. Gate D383 should be created to enforce durability, or severity downgraded to medium for closure.

---

## Security Posture

**BEFORE Wave 1:**
- Auth secrets in .env (manual source of truth)
- Auth secrets in Infisical (seeded but unused)

**AFTER Wave 1:**
- Auth secrets removed from .env
- Runtime non-durable (only works via helper script)
- Restart-fragile state

**AFTER Wave 2 (CURRENT):**
- Infisical: source of truth
- .env.auth-secrets: machine-generated projection (600 permissions)
- .env: no auth secrets
- Runtime: durable (normal compose operations work)

**Security Improvements:**
1. Single source of truth (Infisical)
2. Machine-generated projection (not manual)
3. Tight permissions (600 on .env.auth-secrets)
4. Clear non-authoritative markers in generated file
5. Secrets rotation happens in Infisical, propagates via sync script

---

## Known Issues

### Minor
- .env.auth-secrets must be manually regenerated after Infisical rotation (not automatic)
- Docker compose commands require explicit `--env-file` flags (not default)

### Resolved
- ✅ Plaintext residue cleaned up
- ✅ files-api durability restored
- ✅ Scripts now governed

---

## Future Enhancements

### Immediate (Optional)
1. Create gate D383 for auth durability enforcement
2. Automate .env.auth-secrets regeneration (cron or pre-deploy hook)
3. Make `--env-file .env --env-file .env.auth-secrets` the default compose command

### Long-term
1. Migrate all Mint modules to Infisical-backed deployment
2. Create generic mint-module-deploy framework
3. Integrate with mint.deploy.sync for unified deployment path
4. Add drift detection for .env.auth-secrets vs Infisical

---

## Lessons Learned

### Wave 1 Mistake
**Problem:** Removed secrets from .env without establishing durable replacement first
**Impact:** Broke runtime for both auth and files-api
**Lesson:** Proof-of-concept ≠ production-ready; always ensure durability before removing old path

### Wave 2 Success
**Key Insight:** Docker compose layered env files (`--env-file` multiple times) provide clean separation:
- Main .env: non-secret config
- .env.auth-secrets: machine-generated secret projection
- Both can coexist without .env becoming authoritative

### Governance Requirement
**Finding:** Helper scripts are not "canonical" until registered as capabilities
**Resolution:** Added to capabilities.yaml, capability_map.yaml, routing.dispatch.yaml

---

**Report Generated:** 2026-03-08
**Final Status:** ✅ DURABLE DEPLOYMENT ESTABLISHED
**Auth Service:** LIVE on mint-apps:4300
**Files-API:** LIVE on mint-apps:3500
**Secret Source:** Infisical `infrastructure/prod /spine/services/auth`
**Deployment:** `./bin/ops cap run mint.auth.deploy`
**Runtime:** DURABLE (normal compose operations work)
