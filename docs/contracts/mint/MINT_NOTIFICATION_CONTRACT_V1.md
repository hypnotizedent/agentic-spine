---
status: draft
owner: "@ronny"
created: 2026-02-22
scope: mint-notification-contract-gate1
loop_id: LOOP-MINT-NOTIFICATION-PHASE0-CONTRACT-20260222
---

# MINT Notification Contract V1 (Gate 1)

Contract-only artifact. No runtime mutation.

Evidence:
- Email helper + template files: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/lib/email.cjs:17-55`, `/Users/ronnyworks/ronny-ops/mint-os/apps/api/templates/*.html`
- Twilio helper: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/lib/twilio.cjs:64-166`
- Notification route surface: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/notifications.cjs:67-200`
- Shipping notification helper: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/lib/notifications.cjs:84-129`
- Order lifecycle notification calls: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/v2-jobs.cjs:4237-4333`
- Communications provider readiness: `CAP-20260222-001200__communications.provider.status__Rq8lc11610`
- Event-router workflow state: `CAP-20260222-001212__n8n.workflows.get__Rno9p16280`

## 1) Current trigger map (event -> template -> channel)

| event | source | template/content source | channel | state |
|---|---|---|---|---|
| quote ready SMS | `v2-jobs` `/notify-sms` type=`quote` (`v2-jobs.cjs:4266`) | inline SMS text (`twilio.cjs:124-137`) | Twilio SMS | provider not live-ready |
| payment needed SMS | `v2-jobs` `/notify-sms` type=`payment` (`v2-jobs.cjs:4264`) | inline SMS text (`twilio.cjs:107-122`) | Twilio SMS | provider not live-ready |
| ready for pickup SMS | `v2-jobs` `/notify-sms` type=`ready` (`v2-jobs.cjs:4263`) | inline SMS text (`twilio.cjs:91-105`) | Twilio SMS | provider not live-ready |
| shipped SMS | `v2-jobs` `/notify-sms` type=`shipped` (`v2-jobs.cjs:4265`) | inline SMS text (`twilio.cjs:140-156`) | Twilio SMS | provider not live-ready |
| invoice email | `v2-jobs` `/invoice/send` (`v2-jobs.cjs:4291-4333`) | inline HTML in route | Resend | provider not live-ready |
| generic templated email | `/api/email/send` (`notifications.cjs:87-124`) | filesystem HTML templates (`order-created`, `quote-ready`, `deposit-confirmation`) | Resend | provider not live-ready |
| shipping status email | `lib/notifications.sendShippingNotification` | generated HTML in code (`lib/notifications.cjs:31-62`) | Resend | provider not live-ready |
| status-change router (`READY FOR PICKUP`, `SHIPPED`) | n8n workflow nodes `Ready for Pickup (P08)` and `Shipped (P10)` | no-op nodes | n8n/event router | no delivery implementation |

## 2) What spine communications-agent already covers vs missing

Covered by spine communications stack:
- Provider routing surfaces (Graph, Resend, Twilio) and governed send preview/execute capabilities.
- Policy/status and delivery log capability surfaces.

Missing for Mint transactional replacement:
- Mint event contract mapping into communications-agent send surfaces.
- Template ownership normalization (route-inline HTML, filesystem HTML, and DB templates are split).
- Provider readiness for transactional lanes (`RESEND_API_KEY`, `FROM_EMAIL`, `TWILIO_*` missing per run key above).
- Active workflow implementation for P08/P10 (currently no-op nodes).

## 3) Gap type: wiring vs implementation

Primary gap: **wiring**, with targeted implementation gaps.

Wiring gaps:
- Mint runtime events are not systematically routed into communications-agent execution path.
- n8n event-router status branches terminate in no-op nodes.

Implementation gaps:
- Provider credentials not yet live-ready.
- Template model is fragmented and needs one canonical source for operational ownership.

## 4) What Phase B needs

Minimum Phase B (do first):
1. Quote-created/quote-ready customer email.
2. Payment-needed customer notification (email first, SMS optional fallback).
3. Ready-for-pickup and shipped notifications with active event-router branches.

Full lifecycle (later):
- Invoice reminders, delivery confirmation, internal operator alerts, escalation/retry policy by channel.

## 5) Template storage decision (code or DB)

Observed current state:
- Filesystem templates: `/apps/api/templates/*.html`.
- DB templates: `message_templates` table used by `v2-communications`.
- Inline templates: embedded directly inside route handlers (`v2-jobs.cjs:4317-4324`, `twilio.cjs:101-153`).

Contract decision:
- Canonical template registry should be DB-backed (`message_templates`) for runtime edits and audit trail.
- Filesystem templates remain fallback/bootstrap assets only.
- Inline templates must be migrated to registry-backed identifiers.

## Gate 1 outcome

- Notification boundary defined.
- Gate 2 blocked on (a) provider live readiness, (b) event-router no-op replacement, and (c) template source-of-truth lock.
