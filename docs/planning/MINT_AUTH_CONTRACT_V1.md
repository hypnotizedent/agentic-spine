---
status: draft
owner: "@ronny"
created: 2026-02-22
scope: mint-auth-contract-gate1
loop_id: LOOP-MINT-AUTH-PHASE0-CONTRACT-20260222
---

# MINT Auth Contract V1 (Gate 1)

Contract-only artifact. No runtime mutation.

Evidence:
- Customer JWT auth: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/auth.cjs:37-245`
- Admin JWT auth: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/admin-auth.cjs:32-219`
- Legacy admin path overlap (`admin_users`): `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/auth.cjs:386-417`
- Employee PIN + JWT + timekeeping: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/employee.cjs:123-176`, `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/employee.cjs:763-1244`
- Production portal usage: `/Users/ronnyworks/ronny-ops/mint-os/apps/production/src/lib/api.ts:80-250`, `/Users/ronnyworks/ronny-ops/mint-os/apps/production/README.md:71-97`
- Table creation for admin auth: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/migrations/004_admin_users.sql:7-34`
- RAG check (replacement evidence): `CAP-20260222-001530__rag.anythingllm.ask__Rlrin87540` (retrieval-only, no direct replacement proof)

## 1) Module boundary decision (1 module or 2)

Decision: treat Rank 5 as one auth domain with two bounded surfaces:

1. `auth-core` (customer + admin)
2. `auth-workforce` (employee PIN + kiosk timekeeping token)

Reason:
- Customer/admin JWT share token primitives but target different actor sets and tables (`customers` vs `dashboard_admins`).
- PIN workflows are operationally separate and coupled to `employees` + `time_entries` + `time_entry_breaks` tables.
- Shipping and production prerequisites reference employee/PIN behavior that is not part of customer/admin login.

## 2) Table ownership (`dashboard_admins`, `dashboard_admin_sessions`)

Proposed ownership at cutover:
- `dashboard_admins`: owned by Auth Rank 5 (`auth-core`) as sole writer.
- `dashboard_admin_sessions`: owned by Auth Rank 5 (`auth-core`) as sole writer.

Current state:
- Legacy reads/writes `dashboard_admins` (`admin-auth.cjs:49`, `admin-auth.cjs:84`, `admin-auth.cjs:173`).
- `dashboard_admin_sessions` exists by migration (`004_admin_users.sql:23`) but active write path is not yet enforced in route code.

Open issue:
- `admin_users` table is still referenced (`auth.cjs:393`) and has no migration evidence in the scoped migration set. Status: `UNKNOWN` until operator confirms canonical admin table.

## 3) Secrets migration (names only, no values)

Target namespace model follows ADR-003 per-module rule.

Required new namespace:
- `/spine/services/auth`

Proposed key routing:
- `JWT_SECRET` -> `/spine/services/auth`
- `ADMIN_JWT_SECRET` -> `/spine/services/auth`
- `AUTH_ACCESS_TOKEN_TTL` (new) -> `/spine/services/auth`
- `AUTH_REFRESH_TOKEN_TTL` (new, if refresh introduced) -> `/spine/services/auth`
- `PIN_TOKEN_TTL` (new workforce token policy) -> `/spine/services/auth`

Dependencies still external to auth namespace:
- `SHIPPING_API_KEY` remains `/spine/services/shipping` (`secrets.namespace.policy.yaml:161-164`)
- Communications/provider keys remain in communications namespaces.

Gap:
- `/spine/services/auth` is not present in current `module_namespaces` map (`secrets.namespace.policy.yaml:71-79`).

## 4) Fresh-slate API surface to expose

### 4.1 Customer auth (`auth-core`)
- `POST /api/v1/auth/customer/login`
- `POST /api/v1/auth/customer/signup`
- `GET /api/v1/auth/customer/verify`
- `GET /api/v1/auth/customer/me`
- `PUT /api/v1/auth/customer/profile`

### 4.2 Admin auth (`auth-core`)
- `POST /api/v1/auth/admin/login`
- `GET /api/v1/auth/admin/verify`
- `GET /api/v1/auth/admin/me`
- `POST /api/v1/auth/admin/logout`

### 4.3 Workforce PIN auth (`auth-workforce`)
- `POST /api/v1/auth/employee/login-pin`
- `GET /api/v1/auth/employee/verify`
- `GET /api/v1/auth/employee/me`
- `POST /api/v1/auth/employee/refresh` (if refresh token introduced)

### 4.4 Timekeeping PIN surfaces (deferred from auth token core)
- Preserve current paths behind auth-workforce boundary until lifecycle extraction:
  - `/api/timekeeping/clock-in`
  - `/api/timekeeping/clock-out`
  - `/api/timekeeping/break/start`
  - `/api/timekeeping/break/end`

## 5) What V1 quote-form needs from auth

V1 quote-form needs no customer/admin auth for primary intake:
- V1 quote-page submit routes are public (`/Users/ronnyworks/code/mint-modules/docs/ARCHITECTURE/V1_SCOPE_AND_ROUTE_CANON.md:49-54`).
- V1 scope is explicitly quote form only (`V1_SCOPE_AND_ROUTE_CANON.md:14-33`).

Contract impact:
- Rank 5 auth is not a blocker for V1 quote submit path.
- Rank 5 is a blocker for post-V1 protected portals and production/shop-floor actor flows.

## 6) What Rank 2 shipping needs from auth

Observed shipping module state:
- Current shipping module uses API key middleware (`/Users/ronnyworks/code/mint-modules/shipping/src/routes/shipping.ts:17-139`).

Shipping prerequisite interpretation:
- Minimum requirement for backend shipping cutover: service-to-service API key auth is sufficient.
- Legacy PIN prerequisite applies to production-portal/operator flows that invoke shipping-related actions through employee contexts.

Decision for Gate 2 readiness:
- Shipping can proceed on API-key boundary for backend endpoints.
- Employee PIN replacement remains required before any production-portal shipping workflow cutover.

## Current replacement status

- Fresh-slate auth replacement for legacy JWT/PIN/admin paths: `UNVERIFIED` (no direct replacement evidence found).
- Evidence run key: `CAP-20260222-001530__rag.anythingllm.ask__Rlrin87540`.

## Gate 1 outcome

- Boundary is defined.
- Gate 2 blocked on operator decision for `admin_users` table canonicality and final split between `auth-core` and `auth-workforce` implementation ownership.
