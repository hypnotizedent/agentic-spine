# Customer Portal Canonical Plan v1

**Date:** 2026-03-08  
**Status:** Planning complete, awaiting approval for execution  
**Planning Agent:** Claude Sonnet 4.5 (LOOP-CUSTOMER-PORTAL-PLANNING-20260308)

---

## 1. Executive Summary

### What the Customer Portal Actually Is

The customer portal is a **self-service web application** for Mint Prints customers to:
- Track order status and view order history
- Submit and manage quote requests
- View and manage saved designs
- Update profile and contact information
- Make payments on outstanding balances

**Current state:** The fresh-slate `quote-page` module provides basic quote submission at `mintprints.com/quote`, but there is NO comprehensive customer portal. The legacy web app (`ronny-ops/mint-os/apps/web`) contains a full-featured React SPA with portal, order lookup, quote approval, and authentication — but it's reference code, not runtime authority.

**Goal:** Build a minimal, production-ready v1 customer portal that consolidates essential customer-facing features into a single, authenticated experience backed by fresh-slate APIs.

### What Legacy Solved Well

The legacy web app (`ronny-ops/mint-os/apps/web`) provides proven UX patterns:

1. **Portal Dashboard** (`PortalPage.tsx`) — Clean tabbed interface with:
   - Orders table with detail drawer (payment status, line items, artwork, notes)
   - Quotes list with inline quote request form
   - Designs grid (saved designs from orders)
   - Settings/profile editor
   
2. **Order Lookup** (`OrderLookupPage.tsx`) — Public order tracking:
   - Search by order number (no auth required)
   - Status display with visual indicators
   - Line item breakdown, due dates
   - Pay Now button for outstanding balances
   
3. **Quote Approval** (`QuoteApprovalPage.tsx`) — Customer quote review:
   - Line item display with totals/tax
   - Canvas signature capture
   - Approve (+ pay deposit) or request changes
   
4. **Simple Quote Form** (`SimpleQuotePage.tsx`) — Quick quote request (similar to current fresh-slate quote-page)

5. **Authentication Flow** — Login/signup with JWT, redirect handling for payment success

### What Fresh-Slate is Ready For

Fresh-slate modules provide production-ready backends:

| Feature | Backend Support | Readiness | Notes |
|---------|----------------|-----------|-------|
| **Customer auth** | `auth` module | ✅ Ready | JWT-based, actor boundaries |
| **Order listing** | `orders` `GET /api/customer/orders` | ✅ Ready | Customer-scoped, paginated |
| **Order detail** | `orders` `GET /api/v2/jobs/{id}` | ✅ Ready | Full job data with line items |
| **Public order lookup** | `orders` `GET /api/orders/public/{orderNumber}` | ✅ Ready | No auth required |
| **Quote listing** | `quotes` `GET /api/customer/quotes` | ✅ Ready | Customer-scoped |
| **Quote detail** | `quotes` `GET /api/quotes/public/{hash}` | ✅ Ready | For approval flow |
| **Quote submission** | `quote-page` + `artwork` seeds API | ✅ Ready | Live in production |
| **Payment checkout** | `payment` `POST /api/v2/checkout` | ✅ Ready | Stripe sessions |
| **Payment history** | `payment` `GET /api/v2/jobs/:id/payments` | ✅ Ready | Per-job payment records |
| **Profile update** | `customers` `PUT /api/customers/{id}` | ✅ Ready | Customer CRUD |
| **Saved designs** | `artwork` `GET /api/customer/designs` | ⚠️ Thin adapter | Endpoint exists, needs testing |
| **Artwork files** | `artwork` EQ-9 job files endpoints | ✅ Ready | Download URLs, presigned access |

**Missing backend pieces:**
- Product catalog API (blocked on supplier integration)
- Interactive designer backend (blocked on mockup generation)
- AI order composer backend (blocked on LLM integration)

### What v1 Should Include

**Minimal v1 portal scope** (3-4 week build):

1. **Authenticated Dashboard** (`/portal`)
   - Orders tab: table view + detail drawer
   - Quotes tab: list view + inline quote request form
   - Settings tab: profile editor
   - (Designs tab deferred to v2)

2. **Public Order Lookup** (`/order/:orderId`)
   - No auth required
   - Order status, line items, due dates
   - Pay Now button (redirects to payment checkout)

3. **Quote Approval Flow** (`/approve/:token` or `/quotes/approve/:token`)
   - View quote details (line items, totals, terms)
   - Signature capture canvas
   - Approve + pay deposit OR request changes

4. **Authentication** (`/login`, `/signup`)
   - JWT-based auth against fresh-slate `auth` module
   - Payment success redirects (`/portal?payment=success&order=XXX`)

5. **Quote Intake** (keep existing `/quote` standalone page)
   - Current `quote-page` module works well
   - Integrate into portal header ("Request Quote" button)

**Explicitly deferred to v2:**
- Saved designs tab (backend ready, low priority)
- Product catalog / recommendations (backend not ready)
- Interactive designer (backend not ready)
- AI order composer (backend not ready)
- Reorder flow (needs order duplication API)

---

## 2. Legacy Capability Matrix

| Legacy Feature | What It Did | Value | Import Decision | Notes |
|----------------|-------------|-------|-----------------|-------|
| **Portal Dashboard** | Tabbed interface (Orders/Quotes/Designs/Settings) | ⭐⭐⭐ Must-have | `import UI foundation` | Clean UX, proven patterns |
| **Orders Table** | Paginated order list with search, status badges, balance display | ⭐⭐⭐ Must-have | `import UI foundation` | Backend ready (`GET /api/customer/orders`) |
| **Order Detail Drawer** | Right-side sheet with payment summary, timeline, line items, artwork, notes | ⭐⭐⭐ Must-have | `import UI foundation` | Backend ready (`GET /api/v2/jobs/{id}`) |
| **Quote Request Form** | Inline form in Quotes tab (category, quantity, description, artwork upload) | ⭐⭐⭐ Must-have | `rebuild clean` | Fresh-slate `quote-page` already has this, integrate |
| **Quotes List** | Card-based quote display with status badges | ⭐⭐ Good v1 | `import UI foundation` | Backend ready (`GET /api/customer/quotes`) |
| **Designs Grid** | Saved designs from orders, thumbnail grid | ⭐ Good v2 | `defer` | Backend ready but low priority for v1 |
| **Profile Settings** | Form-based profile editor (name, company, phone, address) | ⭐⭐ Good v1 | `import UI foundation` | Backend ready (`PUT /api/customers/{id}`) |
| **Order Lookup** | Public order tracking by order number, no auth | ⭐⭐⭐ Must-have | `import UI foundation` | Backend ready (`GET /api/orders/public/{orderNumber}`) |
| **Quote Approval** | Quote review + signature canvas + approve/reject | ⭐⭐⭐ Must-have | `import UI foundation` | Backend ready (`GET /api/quotes/public/{hash}`) |
| **Payment Button** | Pay Now for outstanding balances | ⭐⭐⭐ Must-have | `rebuild clean` | Use fresh-slate payment API (`POST /api/v2/checkout`) |
| **Login/Signup** | JWT auth flow with redirect handling | ⭐⭐⭐ Must-have | `rebuild clean` | Use fresh-slate `auth` module |
| **Landing Page (AI Composer)** | Natural language order parsing | ⭐ Reference only | `do not import` | No backend support, vision/PRD only |
| **Product Recommendations** | Visual product grid with supplier integration | ⭐ Reference only | `do not import` | No supplier API integration yet |
| **Interactive Designer** | Canvas workspace for mockup creation | ⭐ Reference only | `do not import` | No mockup generation backend |

**Key takeaways:**
- **Portal dashboard UX** is proven and should be imported as foundation
- **Order lookup and quote approval** are high-value standalone pages
- **AI composer, product catalog, designer** are aspirational — defer until backends exist
- **Authentication and payment** should be rebuilt cleanly against fresh-slate APIs

---

## 3. Fresh-Slate Readiness Matrix

| Portal Capability | Backing Module(s) | Readiness | Missing Backend Pieces | Notes |
|-------------------|-------------------|-----------|------------------------|-------|
| **Customer login** | `auth` | ✅ `ready_now` | None | JWT-based, actor boundaries enforced |
| **Order listing** | `orders` | ✅ `ready_now` | None | `GET /api/customer/orders` returns paginated orders |
| **Order detail** | `orders` | ✅ `ready_now` | None | `GET /api/v2/jobs/{id}` returns full job + line items + payments |
| **Order search** | `orders` | ⚠️ `thin_adapter_needed` | Search/filter params | API supports filters but needs query param design |
| **Public order lookup** | `orders` | ✅ `ready_now` | None | `GET /api/orders/public/{orderNumber}` no auth |
| **Quote listing** | `quotes` | ✅ `ready_now` | None | `GET /api/customer/quotes` customer-scoped |
| **Quote submission** | `quote-page` + `artwork` | ✅ `ready_now` | None | Live in production at `mintprints.com/quote` |
| **Quote approval** | `quotes` + `artwork` | ✅ `ready_now` | None | `GET /api/quotes/public/{hash}` + approve/reject endpoints |
| **Payment checkout** | `payment` | ✅ `ready_now` | None | `POST /api/v2/checkout` creates Stripe session |
| **Payment history** | `payment` | ✅ `ready_now` | None | `GET /api/v2/jobs/:id/payments` per-job records |
| **Payment status** | `orders` | ✅ `ready_now` | None | `amount_outstanding` in order response |
| **Profile view** | `customers` | ✅ `ready_now` | None | `GET /api/customers/{id}` |
| **Profile update** | `customers` | ✅ `ready_now` | None | `PUT /api/customers/{id}` |
| **Saved designs** | `artwork` | ⚠️ `thin_adapter_needed` | Verify endpoint + pagination | `GET /api/customer/designs` exists, needs validation |
| **Artwork download** | `artwork` | ✅ `ready_now` | None | `GET /api/v1/files/:id/download` presigned URLs |
| **Reorder** | `orders` | ❌ `backend_gap` | Order duplication API | `POST /api/v2/jobs/{id}/duplicate` may exist, needs validation |
| **Product catalog** | None | ❌ `backend_gap` | Supplier API integration | AS Colour, S&S Activewear, SanMar APIs not integrated |
| **Mockup designer** | None | ❌ `backend_gap` | Canvas + mockup generation | `digital-proofs` exists but not customer-facing |
| **AI composer** | None | ❌ `backend_gap` | LLM integration + parsing | No backend for natural language order parsing |

**Summary:**
- **Core portal features** (orders, quotes, payments, profile) are fully backed by fresh-slate APIs
- **Saved designs** endpoint exists but needs validation (low risk)
- **Product catalog, designer, AI composer** have no backend support (defer to v2+)

---

## 4. Canonical Ownership Map

| UX Surface | Canonical Home | Owner | Why |
|------------|---------------|-------|-----|
| **Quote intake form** (`/quote`) | `quote-page` module | `quote-page` | Standalone, production-ready, no build step |
| **Payment success page** | `customer-portal` module | `customer-portal` | Currently in quote-page, should move to portal |
| **Payment cancel page** | `customer-portal` module | `customer-portal` | Currently in quote-page, should move to portal |
| **Customer dashboard** (`/portal`) | `customer-portal` module | `customer-portal` | New module |
| **Order lookup** (`/order/:orderId`) | `customer-portal` module | `customer-portal` | Public-facing, no auth |
| **Quote approval** (`/approve/:token`) | `customer-portal` module | `customer-portal` | Public-facing, token-based |
| **Login/signup** (`/login`, `/signup`) | `customer-portal` module | `customer-portal` | Auth flow entry points |
| **Stripe webhook handling** | `payment` module | `payment` | Backend-only, no UI |
| **Artwork file upload** | `artwork` module API | `artwork` | Backend-only, presigned URLs |
| **Public API endpoints** | Domain modules (`orders`, `quotes`, `customers`, `payment`) | Respective modules | Customer-portal is pure UI layer |

**Key decisions:**
1. **quote-page stays standalone** — It works, don't break it. Portal links to it.
2. **payment success/cancel moves to portal** — Quote-page should redirect to portal after payment.
3. **customer-portal is pure UI** — No backend logic, only calls fresh-slate APIs.
4. **customer-portal owns all authenticated UX** — Dashboard, profile, order detail, etc.
5. **customer-portal owns public UX** — Order lookup, quote approval (token-based, no auth).

---

## 5. Recommended Phased Plan

### Phase 0: Prerequisites (1 week)

**Objective:** Validate backend readiness, set up customer-portal scaffold

**Tasks:**
1. Create `customer-portal` module in `mint-modules/`
2. Set up React + TypeScript + Vite (match existing `quote-page` patterns)
3. Set up routing (React Router v6)
4. Set up shared UI components (shadcn/ui or similar)
5. Create API client for fresh-slate backends (centralized fetch wrapper)
6. Validate all required API endpoints with Postman/curl:
   - `GET /api/customer/orders`
   - `GET /api/v2/jobs/{id}`
   - `GET /api/customer/quotes`
   - `POST /api/v2/checkout`
   - `GET /api/customers/{id}`
   - `PUT /api/customers/{id}`
7. Document any API gaps or issues

**Success criteria:**
- Module scaffold exists
- API client can authenticate and call test endpoints
- No blocking API issues discovered

---

### Phase 1: v1 Portal Scope (3 weeks)

**Objective:** Build minimal production-ready portal

#### Week 1: Authentication + Shell

**Tasks:**
1. Build login page (`/login`)
   - Email + password form
   - Call `auth` module for JWT
   - Store token in localStorage or httpOnly cookie
   - Redirect to `/portal` on success
2. Build signup page (`/signup`)
   - Name, email, password, company (optional)
   - Create customer via `customers` API
   - Auto-login after signup
3. Build portal shell (`/portal`)
   - Header with logo, "New Order" button (links to `/quote`), logout
   - Tabbed navigation (Orders, Quotes, Settings)
   - Empty tab content (placeholders)
4. Implement auth guard
   - Redirect to `/login` if not authenticated
   - Redirect to `/portal` if authenticated user visits `/login`

**Success criteria:**
- Users can sign up, log in, log out
- Portal shell renders with tabs
- Auth flow works end-to-end

#### Week 2: Orders Tab + Payment

**Tasks:**
1. Build Orders tab
   - Fetch `GET /api/customer/orders`
   - Render table: Order #, Name, Status, Total, Balance, Due Date, Actions
   - Click row to open detail drawer
2. Build order detail drawer (right-side sheet)
   - Payment summary (total, balance, deposit status)
   - Timeline (order date, due date, customer due date)
   - Line items list (product, color, quantity, price)
   - Artwork thumbnails (if available)
   - Notes section
   - "Pay Now" button (if balance > 0)
   - "Message" button (mailto link)
3. Implement Pay Now flow
   - Call `POST /api/v2/checkout` with job ID
   - Redirect to Stripe checkout
   - Handle success redirect (`/portal?payment=success&order=XXX`)
   - Show toast notification on success

**Success criteria:**
- Orders table loads and displays customer's orders
- Detail drawer shows full order info
- Pay Now flow completes successfully
- Payment success redirects to portal with toast

#### Week 3: Quotes Tab + Settings Tab

**Tasks:**
1. Build Quotes tab
   - Fetch `GET /api/customer/quotes`
   - Render card list: product category, quantity, decoration type, status, date
   - Empty state with "Request Quote" button
   - "Request Quote" button opens modal or redirects to `/quote`
2. Build Settings tab
   - Fetch `GET /api/customers/{id}`
   - Render profile form: first name, last name, company, phone, address (full)
   - Save button calls `PUT /api/customers/{id}`
   - Show success toast on save

**Success criteria:**
- Quotes tab displays customer's quotes
- Can request new quote (links to `/quote`)
- Settings tab loads customer profile
- Can update and save profile changes

---

### Phase 2: Public Pages (1 week)

**Objective:** Build public order lookup and quote approval

**Tasks:**
1. Build order lookup page (`/order/:orderId`)
   - Search form (if no orderId in URL)
   - Call `GET /api/orders/public/{orderNumber}`
   - Display order status, line items, due dates
   - "Pay Now" button for outstanding balances
   - No auth required
2. Build quote approval page (`/approve/:token`)
   - Call `GET /api/quotes/public/{hash}`
   - Display quote line items, totals, tax
   - Signature canvas (HTML5 canvas)
   - Approve button → signature capture → `POST /api/quotes/{id}/approve`
   - Request changes button → textarea → `POST /api/quotes/{id}/reject`
   - Handle already-approved state
   - Handle expired quotes

**Success criteria:**
- Order lookup works without authentication
- Quote approval flow completes (approve or reject)
- Signature capture works on desktop and mobile
- Payment deposit flow works (if integrated with approval)

---

### Phase 3: Polish + Deployment (1 week)

**Objective:** Production readiness

**Tasks:**
1. Error handling
   - Global error boundary
   - API error toasts
   - Loading states on all async operations
2. Mobile responsiveness
   - Test all pages on mobile
   - Drawer becomes bottom sheet on mobile
   - Table becomes card list on mobile
3. Accessibility
   - Keyboard navigation
   - ARIA labels
   - Focus management
4. Docker deployment
   - Dockerfile (single-stage build)
   - docker-compose.yml
   - Environment variable configuration
5. Public ingress wiring
   - Add customer-portal to `public-ingress` routing
   - Configure subdomain: `portal.mintprints.com` or `customer.mintprints.com/portal`
6. Redirect payment success/cancel from quote-page
   - Update quote-page to redirect to `/portal?payment=success&order=XXX`
   - Remove success.html from quote-page

**Success criteria:**
- All pages responsive on mobile
- Error handling graceful
- Deployed to production
- Payment flow redirects to portal
- No blocking bugs

---

### Deferred to v2 (Future)

**Not in scope for v1:**
1. **Saved Designs tab**
   - Backend ready (`GET /api/customer/designs`)
   - Low priority, can add later
2. **Reorder flow**
   - Needs order duplication API validation
   - Can add "Reorder" button in order detail drawer
3. **Advanced search/filters**
   - Current orders/quotes endpoints support basic pagination
   - Can add filters (status, date range) later
4. **Notifications**
   - Email/SMS notifications on order status changes
   - Requires `notifications` module integration
5. **Activity timeline**
   - Full order activity log
   - Requires event tracking backend

**Not in scope until backends exist:**
1. **Product catalog** — Blocked on supplier API integration
2. **Interactive designer** — Blocked on mockup generation backend
3. **AI order composer** — Blocked on LLM integration
4. **Landing page** — Blocked on product catalog + AI composer

---

## 6. Risks & Assumptions

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **API endpoint changes** | High | Freeze API contracts for customer/orders/quotes before starting |
| **Authentication flow complexity** | Medium | Use existing JWT patterns from legacy web app |
| **Payment redirect handling** | Medium | Test Stripe webhooks thoroughly, handle edge cases |
| **Mobile signature capture** | Medium | Use proven canvas library (e.g., react-signature-canvas) |
| **Cross-module auth** | Medium | Ensure all fresh-slate modules enforce customer JWT correctly |
| **Artwork file access** | Low | Presigned URLs from artwork API should work |
| **Performance (order listing)** | Low | Fresh-slate APIs are pagination-ready |

### Assumptions

1. **Fresh-slate auth module is production-ready** — JWT issuance and validation work correctly
2. **Customer API endpoints exist** — `GET /api/customer/orders`, `GET /api/customer/quotes` are functional
3. **Payment module works** — Stripe checkout sessions and webhook handling are reliable
4. **Quote-page stays standalone** — No need to consolidate quote intake into portal for v1
5. **No admin features in portal** — Customer portal is pure customer-facing (no admin/employee access)
6. **CORS is configured** — Fresh-slate APIs allow requests from portal domain
7. **Public order lookup is intentional** — Business wants unauthenticated order tracking (confirm with Ronny)

---

## 7. Final Status

**CUSTOMER_PORTAL_PLAN_CANONICALIZED**

This plan is ready for execution by another agent. It defines:
- ✅ What the portal is supposed to do (self-service customer web app)
- ✅ What legacy value is worth carrying forward (portal UX, order lookup, quote approval)
- ✅ What backend support already exists (orders, quotes, customers, payment APIs)
- ✅ What to build first (authenticated dashboard, public pages)
- ✅ What not to stuff into quote-page again (keep quote-page standalone)

**Next steps:**
1. Review this plan with Ronny
2. Validate API endpoint assumptions (Phase 0 prerequisite)
3. Create `customer-portal` module scaffold
4. Execute Phase 1 → Phase 2 → Phase 3
5. Deploy to production

**Estimated timeline:** 6 weeks (1 week Phase 0 + 3 weeks Phase 1 + 1 week Phase 2 + 1 week Phase 3)

---

**End of Plan**
