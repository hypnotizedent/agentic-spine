# Communications Stack Audit — 2026-02-22

> **Scope:** Full trace of every email path, provider, domain, template, and send mechanism across the spine, workbench, and Mint systems.
> **Purpose:** Identify all disconnects, then define the 3-lane communications model with a clear plan for the self-hosted spine email.

---

## Current State: What Exists

### 3 Email Providers (Active)

| Provider | Purpose | Status | Send Domain |
|----------|---------|--------|-------------|
| **Microsoft** | Ronny's work email (Outlook). Calendar, identity, operational mailbox | Live | `ronny@mintprints.com` (Outlook 365) |
| **Resend** | Transactional customer emails (quotes, payments, shipping) | Phase 1 live (partially working) | `noreply@mintprints.co` (verified in Cloudflare + Resend) |
| **Twilio** | Transactional SMS (customer notifications) | Simulation-only | `+15619335513` |

### 3 Send Mechanisms (Competing)

| Mechanism | Where | Governed? | What It Sends |
|-----------|-------|-----------|---------------|
| **Spine communications plugin** | `ops/plugins/communications/` (12 binaries) | Yes — preview → execute → delivery log, D147 drift lock | Briefing email, test sends, quote-ready via Resend |
| **N8N workflows** | Docker VM, direct HTTP to `api.resend.com` | No — bypasses spine governance entirely | Payment-needed, shipped, ready-for-pickup, pricing-ready, daily digest |
| **Microsoft agent** | `workbench/agents/microsoft/tools/microsoft_tools.py` | Partially — spine contract, but no D147 coverage for Microsoft sends | Live-pilot send-test, A01 quote alerts via Outlook |

### 4 Domains In Play

| Domain | Provider | DNS Status | Used For |
|--------|----------|-----------|----------|
| `mintprints.com` | Microsoft 365 (MX) | Active — MX points to Outlook | Ronny's work email, all `@mintprints.com` mailboxes |
| `mintprints.co` | Resend (verified) | Active — DKIM + SPF in Cloudflare | Transactional sends via spine (`noreply@mintprints.co`) |
| `mintprintshop.com` | Unknown | Unknown | Hardcoded in A02 n8n workflow (`orders@mintprintshop.com`) — likely stale |
| `communications.local` | Planned (Stalwart) | Not deployed | Allowed in stack contract but VM 214 is still `status: planned` |

### Self-Hosted Email (Stalwart) — NOT DEPLOYED

The stack contract references Stalwart on VM 214, but:

- `infra.relocation.plan.yaml` shows `status: planned`, `tailscale_ip: null`
- No Stalwart Docker compose, no DNS records, no mailbox provisioning
- The stack contract lists 3 "mailboxes" (ops, alerts, noreply) but they all route to `ronny@mintprints.com` (Outlook) via `shared-pilot-inbox` — these are contract stubs, not real mailboxes

---

## The 8 Disconnects

### DISCONNECT 1: Provider Contract Contradicts Itself

`communications.providers.contract.yaml` line 10 says `mode: live` and `cutover_phase: phase1-resend-live` — but the Resend provider block on line 43 says `execution_mode: simulation-only`. The phase matrix says phase1 should have `resend_execution_mode: live`. Meanwhile `communications.stack.contract.yaml` line 48 says `transactional.mode: simulation-only`.

**Result:** The spine doesn't know if Resend is live or simulated. The briefing email works (delivery log shows successful sends with real Resend message IDs), but the contract says it shouldn't. The `communications.provider.status` MCP tool reports conflicting states depending on which field it reads.

### DISCONNECT 2: N8N Sends Emails Outside Spine Governance

Six n8n workflows make direct HTTP POST calls to `https://api.resend.com/emails`:

- Mint_OS_-_Payment_Needed_Email
- Mint_OS_-_Shipped_Notification_Email
- Mint_OS_-_Ready_for_Pickup_Email
- A02_-_Pricing_Ready_Notification
- A05_-_Daily_Digest (sends to 3 recipients)

These bypass the spine communications plugin entirely — no preview receipts, no delivery log, no policy gates (opt-in, quiet hours), no anomaly detection. D147 (communications routing lock) only scans the spine repo for direct API calls — it can't see what n8n does at runtime.

### DISCONNECT 3: Sender Addresses Are Scattered and Some Don't Exist

| Sender | Where Used | Works? |
|--------|-----------|--------|
| `noreply@mintprints.co` | Spine comms plugin, quote request webhook | Yes — Resend verified |
| `ronny@mintprints.com` | Stack contract default, Microsoft send-test | Yes — Outlook 365 |
| `sales@mintprints.com` | A01 n8n workflow (New Quote Alert) | **NO — NDR bounce: "sales wasn't found at mintprints.com"** |
| `orders@mintprintshop.com` | A02 n8n workflow (Pricing Ready) | **UNKNOWN — wrong domain entirely** |
| `digest@mintprints.com` | A05 n8n workflow (Daily Digest) | **UNKNOWN — likely doesn't exist in Outlook** |
| `production@mintprints.com` | A05 n8n workflow (Daily Digest CC) | **UNKNOWN — likely doesn't exist in Outlook** |
| `Mint Prints` (display name) | Resend sends | Yes — but no-reply, customers can't respond |

The Undeliverable PDF proves `sales@mintprints.com` doesn't exist — the n8n A01 workflow is bouncing every quote alert.

### DISCONNECT 4: Two Template Systems, No Single Source

The spine has a YAML template catalog (`communications.templates.catalog.yaml`) with 10 templates using `{{variable}}` interpolation. The workbench has HTML email templates in `workbench/infra/compose/n8n/email-templates/` (payment-needed.html, ready-for-pickup.html, shipped.html) with n8n variable interpolation.

These are two completely separate template systems with no connection. The spine catalog is what the communications plugin renders; the n8n templates are what n8n actually sends. They cover overlapping message types but use different formats, different variables, and different rendering engines.

### DISCONNECT 5: Briefing Email Works But Reports Errors

The "Spine Daily Briefing 2026-02-22 (error)" PDF shows the briefing system correctly:

1. Generates JSON via `spine-briefing --json`
2. Creates a preview via `communications-send-preview`
3. Executes via `communications-send-execute`
4. Sends via Resend (message ID: f96ad356-d00a-446b-b06c-565ed65de674)

But the briefing DATA has errors — "stability snapshot unavailable", "calendar status unavailable", "verify status unknown". The email pipeline works; the upstream data collectors don't. This is a briefing plugin issue, not a communications issue.

### DISCONNECT 6: Microsoft Boundary Not Enforced

The governance docs say Outlook is "STRICTLY for work" and should not be touched for spine operations. But:

- The stack contract's `send_test` uses `ronny@mintprints.com` (Outlook) as both sender and recipient
- The `communications-mail-send-test` binary sends via Microsoft (Outlook)
- The live-pilot send-test PDF confirms this — sent from "Ronny Hantash" via Outlook

The spine is currently using Ronny's work Outlook for test sends. This should route through the self-hosted email once deployed.

### DISCONNECT 7: No Catchall / Shared AI Mailbox Exists

The user's stated need: "a self-hosted email for our agentic-system, isolated from my current mailboxes, a new catchall email that my spine + team of AI assistants all share."

Nothing like this exists today. The closest is the stack contract's 3 mailbox stubs (ops, alerts, noreply) all pointing to Outlook. There's no shared AI inbox, no catchall, no way for agents to receive email.

### DISCONNECT 8: Resend Auth Failures (HTTP 403)

The delivery log shows intermittent HTTP 403 errors from Resend:

- 2026-02-21 18:37 — 403 failure, then 18:38 success (same template, different run)
- 2026-02-22 06:14 — 403 failure, then 06:15 success

This suggests either API key rotation issues or rate limiting. The RESEND_API_KEY may not be consistently loaded from Infisical before sends.

---

## The 3-Lane Model (What Should Exist)

### Lane 1: Outlook (Microsoft) — RONNY'S WORK EMAIL

- **Scope:** Ronny's personal/business email. Client communications where Ronny is the sender. Calendar. Identity.
- **Addresses:** `ronny@mintprints.com` (primary), any future team mailboxes on `@mintprints.com`
- **Who sends:** Ronny manually, or a future "Ronny's AI assistant" agent with explicit approval
- **NOT for:** Spine operations, automated notifications, agent-to-agent comms, test sends
- **Governance:** Microsoft agent contract, Microsoft boundary doc. Agents can READ (search, list) but SEND requires explicit human approval per message.

### Lane 2: Resend — TRANSACTIONAL CUSTOMER EMAIL

- **Scope:** Automated customer-facing notifications. No-reply. Triggered by business events (quote ready, payment needed, shipped, etc.)
- **Addresses:** `noreply@mintprints.co` (verified), eventually `orders@mintprints.com` when domain is Cloudflare-managed
- **Who sends:** Spine communications plugin (governed) OR n8n workflows (needs governance migration)
- **NOT for:** Ronny's personal email, agent internal comms, login/catchall
- **Governance:** Spine communications plugin with preview → execute → delivery log. All n8n transactional sends should eventually route through spine or at minimum share the same delivery log.

### Lane 3: Self-Hosted (Stalwart) — SPINE + AI AGENT EMAIL

- **Scope:** The new catchall for the agentic system. Shared AI assistant inbox. Service logins. Non-critical registrations. Agent-to-agent email (if needed). Spine operational notifications.
- **Addresses:** `spine@mintprints.co`, `catchall@mintprints.co`, `alerts@mintprints.co`, individual agent addresses if desired
- **Who sends:** Spine (automated), AI agents (governed), Ronny (for non-important logins/registrations)
- **NOT for:** Customer-facing transactional email (that's Resend), Ronny's work email (that's Outlook)
- **Governance:** Self-hosted on VM 214 (Stalwart), Tailscale-only access, IMAP/SMTP for agent tooling

---

## Plan: What Needs To Happen

### Phase 1: Fix The Contract Contradictions (Day 1)

1. **Align provider contract**: Set `providers.resend.execution_mode: live` to match `cutover_phase: phase1-resend-live`. OR set `mode: simulation-only` to match the provider block. Pick one truth.
2. **Align stack contract**: If Resend is live, update `transactional.mode: live`. If not, update provider contract to `simulation-only`.
3. **Fix sender addresses in n8n workflows**:
   - A01: Change `sales@mintprints.com` → either remove (if quote alerts should go through spine) or create the mailbox in Outlook
   - A02: Change `orders@mintprintshop.com` → `noreply@mintprints.co` (the verified Resend domain)
   - A05: Change `digest@mintprints.com` → a real address or remove

### Phase 2: Deploy Stalwart Self-Hosted Email (Week 1)

1. **Provision VM 214** (communications-stack) on Proxmox
2. **Deploy Stalwart** via Docker Compose:
   - IMAP + SMTP + JMAP
   - Tailscale-only network (no public exposure)
   - Catchall on `@mintprints.co` (secondary domain, won't conflict with Resend transactional sends which use specific verified senders)
   - OR use a new subdomain: `@spine.mintprints.co` or `@mail.mintprints.co` to cleanly separate from Resend
3. **Create shared mailboxes**:
   - `spine@{domain}` — main AI/agent inbox
   - `alerts@{domain}` — automated alert delivery
   - `noreply-spine@{domain}` — spine operational sends (briefings, digests)
   - `catchall@{domain}` — everything else (service logins, registrations)
4. **Configure DNS**: Add MX + SPF + DKIM for the Stalwart domain
5. **Update stack contract**: Point mailboxes to real Stalwart addresses instead of Outlook stubs
6. **Move briefing email**: Route daily briefing through Stalwart instead of Resend (it's an internal operational email, not a customer notification)
7. **Move send-test**: Route live-pilot tests through Stalwart instead of Outlook Microsoft

### Phase 3: Govern N8N Email Sends (Week 2)

Two options:

**Option A (Recommended): Route n8n through spine communications plugin**
- N8N workflows call spine capability endpoints instead of Resend API directly
- Gets preview receipts, delivery log, policy gates, anomaly detection for free
- Single delivery log across all send mechanisms

**Option B: Shared delivery log only**
- Keep n8n calling Resend directly but add a webhook that writes to the spine delivery log
- Lighter lift but no policy gate enforcement

### Phase 4: Template Consolidation (Week 2-3)

1. **Choose one template system**: The spine YAML catalog or the n8n HTML templates. The HTML templates are richer (branded, styled) so they should be the source of truth.
2. **Move templates to spine**: `ops/bindings/communications.templates/` with HTML files referenced by the YAML catalog
3. **Update spine send-preview**: Render HTML templates with variable interpolation instead of plain text bodies

### Phase 5: Microsoft Boundary Enforcement (Week 3)

1. **Remove Outlook from spine operations**: No more `ronny@mintprints.com` as send-test sender/recipient
2. **Update stack contract**: send-test routes through Stalwart
3. **Add drift gate D151**: Enforce that no spine capability sends email via Microsoft (only reads are allowed)
4. **Document the boundary**: Update MICROSOFT_BOUNDARY.md with the 3-lane model

---

## File Reference

| File | What It Controls |
|------|-----------------|
| `ops/bindings/communications.stack.contract.yaml` | Stack pilot config, mailboxes, VM target |
| `ops/bindings/communications.providers.contract.yaml` | Provider routing, cutover phase, execution modes |
| `ops/bindings/communications.templates.catalog.yaml` | Spine template catalog (YAML) |
| `ops/bindings/communications.policy.contract.yaml` | Consent, quiet hours, compliance |
| `ops/bindings/communications.delivery.contract.yaml` | Delivery log, preview receipts, anomaly thresholds |
| `ops/plugins/communications/bin/*` | 12 spine capability binaries |
| `ops/runtime/spine-briefing-email-daily.sh` | Briefing → email pipeline (launchd scheduled) |
| `ops/agents/communications-agent.contract.md` | MCP gateway agent contract |
| `ops/agents/microsoft-agent.contract.md` | Microsoft agent contract + boundary |
| `workbench/agents/communications/tools/src/index.ts` | Communications MCP gateway implementation |
| `workbench/agents/microsoft/tools/microsoft_tools.py` | Microsoft tools (mail, calendar) |
| `workbench/infra/compose/n8n/email-templates/` | HTML email templates for n8n |
| `workbench/infra/compose/n8n/workflows/` | N8N workflow JSON files (6 email senders) |
| `docs/governance/MICROSOFT_BOUNDARY.md` | Microsoft boundary governance (stub → workbench) |
| `surfaces/verify/d147-communications-canonical-routing-lock.sh` | Drift lock for Resend/Twilio centralization |
