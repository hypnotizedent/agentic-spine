---
status: authoritative
owner: "@ronny"
created: 2026-02-27
scope: w53-resend-expansion-audit
parent_loop: LOOP-SPINE-RESEND-CANONICAL-UPGRADE-20260227-20260301-20260227
---

# W53 Resend Expansion Audit

## Context

Resend shipped their "Email for Agents" platform overhaul on 2026-02-26, including:
- **MCP Server v2.1.0** with 56+ tools (send, receive, contacts, broadcasts, domains, webhooks)
- **3 Agent Skills** (resend-skills, react-email, email-best-practices) - Anthropic standard
- **Official n8n node** (native Resend integration replacing raw HTTP)

## Current Spine Communications Inventory

| Layer | Status | Notes |
|-------|--------|-------|
| Resend API (transactional) | LIVE (phase1-canary) | `RESEND_API_KEY` in Infisical |
| Governed send flow | LIVE | preview then execute (D147 routing lock) |
| MCP agent (gateway) | LIVE | 13 tools in Claude Desktop |
| Stalwart self-hosted | LIVE | SMTP/IMAP/JMAP on VM 214 |
| Alert pipeline | LIVE | Queue, dispatcher, SLO, escalation |
| n8n quote alerts | LIVE | **UNGOVERNED** raw HTTP to Resend |
| Delivery tracking | LIVE | Log, anomaly detection, incident bundling |
| Inbound email | PARTIAL | IMAP polling on Stalwart only |
| Contacts/audience | MISSING | No spine capabilities |
| Broadcasts/campaigns | MISSING | No spine capabilities |
| Webhook events | MISSING | No ingest surface |

## Gap Analysis

### HIGH VALUE (fills real gaps)

1. **Inbound email for agents (GAP-OP-1023)**: Resend MCP reads replies to transactional emails. Closes customer communication loop without IMAP polling.
2. **Contact management (GAP-OP-1024)**: Full CRM-lite via Resend MCP. Customer lists, segments, topic subscriptions.
3. **Broadcast campaigns (GAP-OP-1025)**: Agent-accessible marketing campaigns with personalization. Currently zero spine capability.
4. **Webhook events (GAP-OP-1023)**: Real-time delivery/bounce/complaint/open/click events replacing poll-based anomaly detection.

### MEDIUM VALUE (improves existing patterns)

5. **MCP coexistence (GAP-OP-1027)**: Run official Resend MCP alongside spine gateway. Resend for reads, spine for governed sends.
6. **n8n bypass remediation (GAP-OP-1026)**: A01 workflow uses raw HTTP to Resend. Replace with official n8n node or spine capability.

### GOVERNANCE CERTIFICATION

7. **Acceptance cert (GAP-OP-1028)**: Prove end-to-end governance with acceptance matrix.

## New Gates Required

| ID | Name | Purpose |
|----|------|---------|
| D263 | resend-mcp-transactional-send-authority-lock | No Resend MCP send_email in governed paths |
| D264 | communications-resend-webhook-schema-lock | Webhook event schema contract present |
| D265 | communications-contacts-governance-lock | Contacts mutations require approval |
| D266 | communications-broadcast-governance-lock | Broadcast sends require approval + rate guard |
| D267 | n8n-resend-direct-bypass-lock | n8n must not call Resend API directly |
| D268 | communications-resend-expansion-contract-parity-lock | Contract + policy docs present and consistent |

## Protected Lanes (NOT TOUCHED)

- LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226
- GAP-OP-973
- EWS import lane
- MD1400 rsync lane

## Deliverables

1. `docs/CANONICAL/COMMUNICATIONS_RESEND_EXPANSION_CONTRACT_V1.yaml`
2. `docs/CANONICAL/COMMUNICATIONS_RESEND_MCP_COEXISTENCE_POLICY_V1.md`
3. `docs/planning/W53_RESEND_EXPANSION_AUDIT.md` (this file)
4. `docs/planning/W53_RESEND_ACCEPTANCE_MATRIX.md`
5. 6 gate scripts (D263-D268)
6. Gate registry + topology + profile wiring
7. Updated RUNBOOK.md and communications-agent.contract.md
8. Master receipt
