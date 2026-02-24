---
loop_id: LOOP-COMMS-AGENTIC-LAYER-20260223
created: 2026-02-23
status: active
owner: "@ronny"
scope: spine
priority: high
objective: Build the self-hosted agentic communications primitive layer on VM 214 (Stalwart). Activate CalDAV/CardDAV, DKIM/DMARC, IMAP agent ingestion, and calendar sync execution. Zero new VMs — extends existing communications-stack.
parent_loop: LOOP-SPINE-COMMS-BOUNDARY-20260222
---

# Loop Scope: LOOP-COMMS-AGENTIC-LAYER-20260223

## Objective

Transform the existing Stalwart deployment (VM 214) from a basic mail server into a full agentic communications primitive layer. Agents gain the ability to send, receive, and process email, manage calendars via CalDAV, manage contacts via CardDAV, and authenticate deliverability via DKIM/DMARC.

## Source Context

- Parent loop: `LOOP-SPINE-COMMS-BOUNDARY-20260222` (closed — established 3-lane model)
- Stalwart already live: SMTP (25/465/587), IMAP (993), ManageSieve (4190), Admin (8080/8443)
- 3 mailboxes active: `ops@`, `alerts@`, `noreply@` spine.mintprints.co
- DNS: `mail.spine.mintprints.co` A record, MX, SPF configured
- VM 214 Tailscale: `100.115.16.37`, LAN: `192.168.1.26`

## Infrastructure Constraint

- **Zero new VMs** — all work on existing VM 214
- **Zero new containers** — Stalwart natively supports CalDAV, CardDAV, JMAP
- Governance contracts already exist for most capabilities

## 4-Phase Execution Plan

### Phase 1: Email Authentication Hardening
**Goal:** DKIM/DMARC for `spine.mintprints.co` — deliverability and anti-spoofing

| Step | Action | Evidence |
|------|--------|----------|
| 1.1 | Generate DKIM keys in Stalwart admin | Key pair exists in Stalwart config |
| 1.2 | Add DKIM DNS record (`stalwart._domainkey.spine.mintprints.co`) | DNS TXT record resolves |
| 1.3 | Add DMARC DNS record (`_dmarc.spine.mintprints.co`) | DNS TXT record resolves |
| 1.4 | Send test email, verify DKIM/DMARC pass in headers | `Authentication-Results: dkim=pass` |
| 1.5 | Register drift gate for DKIM/DMARC parity | Gate passes in verify suite |

**DoD:** Test email to external mailbox shows `dkim=pass`, `dmarc=pass` in headers.

### Phase 2: CalDAV/CardDAV Activation
**Goal:** Self-hosted calendar and contacts for agent scheduling

| Step | Action | Evidence |
|------|--------|----------|
| 2.1 | Enable CalDAV endpoint in Stalwart config | `/.well-known/caldav` responds 200 |
| 2.2 | Enable CardDAV endpoint in Stalwart config | `/.well-known/carddav` responds 200 |
| 2.3 | Create `spine-ops` calendar on `ops@spine.mintprints.co` | Calendar accessible via CalDAV client |
| 2.4 | Register `calendar.caldav.status` capability | Cap exists in capabilities.yaml + capability_map.yaml |
| 2.5 | Wire calendar.sync.execute to CalDAV backend | Sync plan shows CalDAV as target |

**DoD:** CalDAV endpoint responds, calendar created, basic event CRUD works via curl.

### Phase 3: Agent Email Ingestion Pipeline
**Goal:** Agents can read and process inbound mail via IMAP

| Step | Action | Evidence |
|------|--------|----------|
| 3.1 | Build `communications.inbox.poll` capability | IMAP poll reads from ops@ mailbox |
| 3.2 | Define inbox processing contract (`communications.inbox.contract.yaml`) | Contract in ops/bindings/ |
| 3.3 | Wire poll output to mailroom bridge enqueue | Messages appear in mailroom inbox |
| 3.4 | Add ManageSieve rules for auto-routing (alerts→alerts@, ops→ops@) | Sieve scripts active |
| 3.5 | Register drift gate for inbox health | Gate passes — mailbox accessible, no stale messages |

**DoD:** Email sent to `ops@spine.mintprints.co` is polled, parsed, and enqueued to mailroom within 60s.

### Phase 4: Governance & Verification
**Goal:** All new surfaces covered by drift gates and verified

| Step | Action | Evidence |
|------|--------|----------|
| 4.1 | Register all new capabilities in capabilities.yaml + capability_map.yaml | D67 passes |
| 4.2 | Register all new gaps filed during execution | Gaps in operational.gaps.yaml |
| 4.3 | Run full verify.core.run — clean | Receipt shows 0 failures |
| 4.4 | Run verify.pack.run hygiene-weekly — clean | Receipt shows 0 failures |
| 4.5 | Update communications.stack.contract.yaml with new endpoints | Contract reflects CalDAV/CardDAV/IMAP-poll |
| 4.6 | Close loop | Status → closed, all gaps resolved |

**DoD:** All verification passes, all gaps closed, loop status → closed.

## Success Criteria

1. DKIM/DMARC pass on all outbound Stalwart email
2. CalDAV/CardDAV endpoints live and accessible
3. Agent IMAP ingestion pipeline operational (poll → parse → enqueue)
4. All new capabilities registered with drift gates
5. Full verify suite passes clean

## Gaps (to be filed as work begins)

Gaps will be filed per-phase using `gaps.file` as issues are discovered.
