---
loop_id: LOOP-SPINE-COMMS-BOUNDARY-20260222
created: 2026-02-22
status: active
owner: "@ronny"
scope: spine
priority: high
objective: Execute 3-lane communications boundary: fix remaining contract contradictions, deploy Stalwart (Lane C), enforce Graph boundary with D151 gate. Tracks 8 disconnects from COMMUNICATIONS_AUDIT_20260222.
---

# Loop Scope: LOOP-SPINE-COMMS-BOUNDARY-20260222

## Objective

Execute the 3-lane communications boundary model with hard separation between Mint (customer) and Spine (operational) email. Remediate all 8 disconnects from `COMMUNICATIONS_AUDIT_20260222.md`.

## Source Audit

- Audit doc: `mailroom/state/loop-scopes/COMMUNICATIONS_AUDIT_20260222.md`
- Source commit: `ae336e457b22a1118d0b8c7475a5d8c6a6233665`

## 3-Lane Model

| Lane | Provider | Domain | Purpose |
|------|----------|--------|---------|
| A: Graph | Microsoft 365 | `@mintprints.com` | Ronny's work email. READ=auto, SEND=human-approval |
| B: Resend | Resend API | `noreply@mintprints.co` | Customer transactional notifications (governed) |
| C: Stalwart | Self-hosted | `@spine.mintprints.co` (proposed) | Spine ops, agent inbox, catchall, alerts |

## Canonical Sender Identities

- **Work mailbox:** `info@mintprints.com` (Graph, Lane A)
- **Customer automation:** `noreply@mintprints.co` (Resend, Lane B)
- **Spine operations:** `spine@spine.mintprints.co` (Stalwart, Lane C — planned)

## 8 Disconnects — Status Tracker

| # | Disconnect | Status | Fixed By | Evidence |
|---|-----------|--------|----------|----------|
| D1 | Provider contract contradicts itself | **PARTIAL** | `ce88689` (resend execution_mode -> live) | Stack contract `transactional.mode` still `simulation-only` — see GAP-OP-818 |
| D2 | N8N sends outside governance | **FIXED** | n8n purge (36 workflows deleted, workbench commit `8a297f7`) | `n8n.workflows.list` returns 0. Only `Spine_-_Mailroom_Enqueue` file remains. |
| D3 | Sender addresses scattered | **FIXED** | n8n purge eliminated all stale senders | Zero `mintprintshop.com`/`sales@`/`digest@`/`production@` references remain |
| D4 | Two template systems | **FIXED** | n8n HTML templates deleted | Spine YAML catalog is sole template surface |
| D5 | Briefing email reports errors | **OUT OF SCOPE** | N/A | Briefing plugin data issue, not comms |
| D6 | Graph boundary not enforced | **FIXED** | D151 gate + stack contract update | send_test → spine.mintprints.co, mailboxes → stalwart-direct, D151 enforces boundary |
| D7 | No shared AI mailbox | **OPEN** | See GAP-OP-820 | VM 214 not provisioned, Stalwart not deployed |
| D8 | Resend auth failures (403) | **OPEN** | See GAP-OP-821 | Intermittent 403 in delivery log, root cause unknown |

## 5-Phase Execution Plan — Status

| Phase | Description | Status | Remaining |
|-------|-----------|--------|-----------|
| P1 | Contract consistency + sender normalization | **DONE** | GAP-OP-818 closed, stack contract mode=live, sender addresses normalized |
| P2 | Stalwart bootstrap (VM 214) | **NOT STARTED** | Full VM + deploy + DNS (GAP-OP-820) |
| P3 | N8N migration to spine governance | **SUPERSEDED** | Deleted all n8n flows. `Spine_-_Mailroom_Enqueue` is the only future path. |
| P4 | Template SSOT consolidation | **DONE** | Dual system eliminated. Spine YAML catalog is SSOT. |
| P5 | Boundary enforcement (D151 gate) | **DONE** | D151 registered, stack contract updated, gate passes |

## Gaps (Remaining Work)

- **GAP-OP-818**: Stack contract `transactional.mode: simulation-only` contradicts provider contract `mode: live` (P1 finish)
- **GAP-OP-819**: Graph boundary not enforced — send_test uses Outlook, no D151 gate (P5)
- **GAP-OP-820**: Stalwart self-hosted email not deployed — VM 214, DNS, mailboxes (P2)
- **GAP-OP-821**: Resend intermittent 403 — Infisical injection timing investigation (D8)

## Key Decisions

- **Domain for Stalwart:** `spine.mintprints.co` (subdomain to avoid Resend MX conflict) — PENDING CONFIRMATION
- **N8N strategy:** Full deletion (not migration). All customer notifications will be rebuilt through `Spine_-_Mailroom_Enqueue` or direct spine comms plugin.
- **Template format:** Spine YAML catalog with `body_text` is current SSOT. HTML templates can be added later when customer sends resume.

## Next Action for Any Agent

```bash
# Quick win — finish P1 (stack contract mode alignment):
# Edit ops/bindings/communications.stack.contract.yaml line 48
# Change: mode: simulation-only -> mode: live
# Then verify:
./bin/ops cap run communications.provider.status
./bin/ops cap run verify.core.run
```
