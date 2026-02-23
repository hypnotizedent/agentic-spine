# DECISION MEMO (ARCH-COMMS-01, READ-ONLY)

## Coordination Context

From allowed read-only checks:

- proposals.status: 37 total, 9 pending, 10 applied, 18 superseded, 0 SLA breaches.
- loops.status: 10 open, 116 closed.
- gaps.status: 3 open, 0 orphaned.

## Current State

- Current human email environments are Outlook (mint), iCloud (personal), and Gmail (archive/misc/legacy).
- Mail Archiver runs as a finance-bundled service on VM 211 (`finance-stack`), not as a dedicated communications environment.
- Email automation is split across:
  - Microsoft Graph governed capabilities (`graph.mail.*`, `graph.calendar.*`) for the Outlook lane.
  - Resend-based transactional sending in workbench scripts.
- No first-class `communications` domain exists yet with dedicated VM, capabilities, and verify lane.

## Options Compared

### Stalwart

- Pros: SMTP/IMAP/JMAP, API-friendly automation surface, lighter single-node footprint, strong fit for agent-driven routing/aliases.
- Cons: smaller ecosystem/community than older suite stacks, less turnkey all-in-one admin UX.

### Mailcow

- Pros: mature and feature-rich full mail suite, broad docs/community usage, strong admin UX.
- Cons: heavier operational footprint and moving parts; over-scoped for "agentic hub + controlled growth".

### Mailu

- Pros: modular Docker-native stack, lighter than Mailcow, flexible composition.
- Cons: more assembly/ops burden than Stalwart for API-first agent workflows.

## Scored Decision Matrix (This Environment)

Scale: 1-5, weighted.

Weights:

- API/agent automation: 25
- single-VM simplicity: 20
- resource footprint: 15
- governance fit: 15
- mail/security baseline: 15
- operator UX: 10

| Option | API (25) | Simplicity (20) | Footprint (15) | Governance Fit (15) | Mail/Security (15) | UX (10) | Weighted Total |
|---|---:|---:|---:|---:|---:|---:|---:|
| Stalwart | 5 | 4 | 5 | 5 | 4 | 3 | 445/500 (89/100) |
| Mailu | 3 | 3 | 3 | 3 | 4 | 3 | 315/500 (63/100) |
| Mailcow | 2 | 2 | 2 | 2 | 5 | 4 | 265/500 (53/100) |

Decision: **Stalwart** is the best fit for this environment.

## Recommended Target Architecture

- Provision dedicated `communications-stack` VM (shop site, `pve`, new VMID).
- Run Stalwart as core mail platform for new agentic/work accounts only.
- Keep Mail Archiver as legacy/history system (no migration requirement).
- Keep Outlook/iCloud/Gmail unchanged; communications stack is additive.
- Add a workbench-owned intake/normalization worker that converts mailbox events into governed spine flows.
- Add `communications.*` capabilities with manual approval on mutating actions.

## Phased Rollout

1. Preflight
- Confirm DNS/MX/SPF/DKIM/DMARC strategy, outbound relay approach, port/reverse-DNS realities.
- Define mailbox/alias taxonomy (`alerts`, `accounts`, `auth`, `vendors`, `receipts`, `ai`).

2. Bootstrap
- Provision `communications-stack` VM.
- Deploy Stalwart (+ optional webmail/admin UI) via workbench compose.
- Establish persistent storage and backup policy.

3. Governance Wiring
- Register VM, SSH target, compose target, services, routing, secrets runway, capabilities, domain topology.
- Add domain docs routes and capability catalog entries.

4. Pilot
- Route only new AI/service signups and internal alerts through communications mailboxes.
- Validate read/search/send flows with manual mutation approvals.

5. Expand
- Add per-agent mailbox patterns and alias standards.
- Add retention tiers, routing policy, and audit/reporting controls.
- Scale capacity and HA only after stable single-node operations.

## Explicit Non-Goals

- No migration/import of existing personal mail history.
- No replacement of Outlook or iCloud.
- No forced cutover from Gmail archive/misc setup.
- No disruption of Mail Archiver historical role.
