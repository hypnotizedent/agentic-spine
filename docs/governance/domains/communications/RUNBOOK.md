---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: communications-live-pilot-runbook
domain: communications
---

# Communications Live Pilot Runbook

## Purpose

Define the canonical live-pilot operating flow for communications surfaces in spine.

## Contract Authority

- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.stack.contract.yaml`

Live pilot requires:

- `pilot.send_test.mode: live-pilot`
- `pilot.execution_backend: microsoft-graph`
- Active mailbox rows in `pilot.mailboxes[]`

## Surfaces

- `communications.stack.status`
  - Validates contract + infra target parity.
  - In live mode, runs Graph probe and fails on non-JSON/no-response payload.
- `communications.mailboxes.list`
  - Shows stage/mode/backend and pilot mailbox roster.
- `communications.mail.search`
  - Simulation mode: searches mailbox catalog in contract.
  - Live mode: executes Graph mailbox query via governed Graph helper.
- `communications.mail.send.test`
  - Manual approval required.
  - Simulation mode: writes simulated artifact under runtime outbox.
  - Live mode: sends real pilot test message via Graph and writes receipt artifact under runtime outbox.

## Required Preconditions

Communications live surfaces rely on Graph and therefore require:

- `secrets.binding`
- `secrets.auth.status`

## Canonical Commands

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run communications.stack.status
./bin/ops cap run communications.mailboxes.list
./bin/ops cap run communications.mail.search --query "*" --top 5
echo "yes" | ./bin/ops cap run communications.mail.send.test --to ronny@mintprints.com --subject "pilot test" --body "hello" --execute
```

## Evidence Pattern

- Send-test artifact path:
  - `$SPINE_OUTBOX/communications/communications-send-test-last.yaml`
- Delivery confirmation pattern:
  - Query `graph.mail.search` for unique send-test subject token.
