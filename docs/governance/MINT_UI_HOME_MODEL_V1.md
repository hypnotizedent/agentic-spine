# MINT UI/UX Home Model V1
**Authority**: Canonical UI placement policy for Mint system
**Status**: ACTIVE (enforcement in place)
**Version**: 1.0
**Effective**: 2026-03-08
**Scope**: All Mint UI surfaces (customer, operator, admin)

---

## Status: MINT_UI_HOME_MODEL_CANONICALIZED ✅

**What Is Landed**:
- ✅ Advisory guidance in `mint-modules/AGENTS.md`
- ✅ Module scope clarification in `mint-modules/quote-page/README.md`
- ✅ 3-tier UI architecture defined
- ✅ Legacy UI value assessed
- ✅ **Enforcement gate active** (Gate 12: UI placement lock in mint-modules pre-commit)

**What Remains (Acknowledged Temporary State)**:
- ⚠️ Payment return pages still in `quote-page` (temporary exception until Wave 1)
- ⏳ `customer-portal`, `admin-portal`, `production-portal` deferred (Waves 1-3)

**Current State**: Boundaries enforced, violations explicitly allowed as temporary exceptions, portals deferred.

---

## 1. Executive Summary

### The Real Drift

**Problem**: `quote-page` started as minimal customer intake but became default dumping ground for unrelated customer/payment UX.

**Evidence**:
- Payment return pages (`/checkout/success`, `/checkout/cancel`) in `quote-page/public/` (NOT quote-intake native)
- Fresh-slate: 15 modules, 14 API-only, only `quote-page` serves HTML
- No operator/admin dashboard despite rich legacy UI (175 files in ronny-ops/admin)
- Agents defaulting to first HTML surface due to no placement guidance

**Consequence**: Without boundaries, `quote-page` becomes monolithic frontend junk drawer.

---

### Canonical UI Home Model (3-Tier)

#### Tier 1: Module-Local Public Pages
- **Scope**: Thin pages owned by single module (1-3 max)
- **Tech**: Vanilla HTML + minimal JS (NO React/Vite)
- **Example**: `quote-page/public/` for quote intake form
- **Rule**: Module `public/` ONLY if page is module-native

#### Tier 2: Cross-Module Customer UX
- **Scope**: Customer workflows spanning multiple modules
- **Examples**: Order tracking, payment history, quote approval
- **Location**: `customer-portal/` (does NOT exist yet, deferred Wave 1)
- **Tech**: React + TypeScript (import from legacy `web` app)

#### Tier 3: Operator/Admin UX
- **Scope**: Internal dashboards, production floor UI
- **Examples**: Admin dashboard, production portal, shipping tools
- **Location**: `admin-portal/`, `production-portal/` (do NOT exist yet, deferred Wave 2-3)
- **Tech**: React + TypeScript (import from legacy `admin`/`production` apps)

---

## 2. Hard Boundary Rules

### Rule 1: Module Public Directory Discipline
Module `public/` ONLY for thin, module-native pages (1-3 max, vanilla HTML).

**Forbidden**: Payment pages in `quote-page`, customer portal in any backend module.

### Rule 2: No React/SPA in Module Public/
Tier 1 is vanilla HTML only. React/Vue/Angular FORBIDDEN in module `public/`.

### Rule 3: Cross-Module UX Needs Dedicated Home
Customer workflows spanning modules → `customer-portal` (not backend modules).

### Rule 4: Operator UX Separation
Operator/admin UI → dedicated portals (not backend API modules).

### Rule 5: Legacy UI = Reference Only
Legacy ronny-ops apps are reference, not runtime authority. Must rewire to fresh-slate APIs.

---

## 3. Current State (Acknowledged Violations)

**Temporary Exception** (defer migration to Wave 1):
- `/checkout/success`, `/checkout/cancel` in `quote-page/public/`
- Documented as temporary in `quote-page/README.md`
- Proper home: `customer-portal/pages/checkout/` (when it exists)

---

## 4. Legacy UI Value Assessment

| App | Files | Import Decision |
|-----|-------|-----------------|
| admin | 175 TSX | ✅ IMPORT (Wave 2) |
| web | 91 TSX | ✅ IMPORT (Wave 1) |
| production | 88 TSX | ✅ IMPORT (Wave 3) |
| shipping | 88 TSX | 📋 REFERENCE |
| job-estimator | 12 TS | 📋 REFERENCE |
| artwork | 6 JSX | 📋 REFERENCE |
| suppliers | 5 JSX | ❌ IGNORE |

---

## 5. Migration Waves (Deferred)

- **Wave 0**: ✅ COMPLETE (guidance landed, Gate 12 enforcement active)
- **Wave 1**: Customer portal (import legacy `web`, migrate payment pages)
- **Wave 2**: Admin portal (import legacy `admin`)
- **Wave 3**: Production portal (import legacy `production`)
- **Wave 4-6**: Shipping/artwork/estimator tools

---

## 6. Enforcement Status

✅ **Gate 12 Active** (mint-modules commit 80b9489):
- Flags React/SPA files (`.jsx`, `.tsx`, `vite.config.*`) in module `public/`
- Flags cross-module customer pages in backend modules
- Flags new `public/` directories in backend API modules
- Temporary exceptions: checkout-success.html, checkout-cancel.html in quote-page

**Next Wave** (Execute Wave 1 - customer portal foundation):
1. Import legacy `web` app → `customer-portal/`
2. Migrate payment return pages from quote-page to customer-portal
3. Validate rewire-to-fresh-slate pattern
4. Remove temporary exceptions from Gate 12

---

## 7. Advisory Guidance (Current State)

**Landed in `mint-modules/AGENTS.md`**:
- 3-tier architecture classification
- Forbidden placements (payment/customer/admin UI in backend modules)
- Tier 1 = vanilla HTML only

**Landed in `mint-modules/quote-page/README.md`**:
- Scope: Quote intake ONLY
- Payment pages marked as temporary violation
- Cross-module UX belongs elsewhere

---

**END OF DOCUMENT**

*Status: ACTIVE - enforcement gate landed, temporary exceptions documented, portals deferred*
