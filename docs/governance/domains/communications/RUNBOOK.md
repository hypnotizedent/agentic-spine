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
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.providers.contract.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.policy.contract.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.templates.catalog.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/communications.delivery.contract.yaml`

Live pilot requires:

- `pilot.send_test.mode: live-pilot`
- `pilot.execution_backend: microsoft`
- Active mailbox rows in `pilot.mailboxes[]`
- Transactional provider and policy contracts present and parseable

## Surfaces

- `communications.stack.status`
  - Validates contract + infra target parity.
  - In live mode, runs Microsoft probe and fails on non-JSON/no-response payload.
- `communications.mailboxes.list`
  - Shows stage/mode/backend and pilot mailbox roster.
- `communications.mail.search`
  - Simulation mode: searches mailbox catalog in contract.
  - Live mode: executes Microsoft mailbox query via governed Microsoft helper.
- `communications.mail.send.test`
  - Manual approval required.
  - Simulation mode: writes simulated artifact under runtime outbox.
  - Live mode: sends real pilot test message via Microsoft and writes receipt artifact under runtime outbox.
- `communications.mailarchiver.import.monitor`
  - Single-flight wrapper for import status checks.
  - Classifies interactive auth URL/check responses as `BLOCKED_AUTH`.
  - Writes monitor lane state artifact and sets `retry_allowed=false` in blocked-auth state.
- `communications.provider.status`
  - Shows Microsoft/Resend/Twilio route status, cutover phase, and env-readiness for live execution.
- `communications.policy.status`
  - Shows canonical consent/compliance policy (opt-in, quiet-hours, STOP footer rules).
- `communications.templates.list`
  - Lists template catalog by channel/message type.
- `communications.send.preview`
  - Resolves message_type + channel to canonical provider and renders message under policy gates.
  - Writes preview receipt artifact and returns `preview_id` linkage for execute boundary.
- `communications.send.execute`
  - Manual approval required.
  - Enforces preview linkage (`--preview-id` or `--preview-receipt`) for `--execute`.
  - Revalidates preview against current policy/routing before send.
  - Simulation-first transactional execution with optional live provider dispatch when contract mode is `live` and cutover phase allows live mode for the provider.
- `communications.delivery.log`
  - Read-only query of normalized communications delivery artifacts.
- `communications.delivery.anomaly.status`
  - Evaluates delivery log anomaly metrics (failure rate, policy-block rate, timeout spikes) against contract thresholds.
- `communications.delivery.anomaly.dispatch`
  - Manual-approval alert artifact + dispatch surface with cooldown control.

## Incident Bundle

One-command incident triage for the alert intent pipeline:

```bash
# Dry summary
./bin/ops cap run communications.alerts.incident.bundle.create

# JSON output
./bin/ops cap run communications.alerts.incident.bundle.create --json

# Write bundle artifact
./bin/ops cap run communications.alerts.incident.bundle.create --write
```

Bundle artifact: `mailroom/outbox/alerts/communications/incidents/BUNDLE-<timestamp>.json`

## Drift Lock

- `D147 communications-canonical-routing-lock`
  - Blocks direct Twilio/Resend provider calls outside canonical communications surface.
  - Scans active runtime/agent code surfaces across spine + workbench.
- `D151 communications-boundary-lock`
  - No Outlook as automated sender, no stale domains, stack-provider mode parity.
- `D160 communications-queue-pipeline-lock`
  - V1-V6 queue pipeline integrity: required capabilities, contracts, safety/approval invariants, alerting channel guard.

## Required Preconditions

Communications dispatch preconditions are scoped to communications-critical routes:

- Provider contract + route policy parseability (`communications.providers.contract.yaml`, `communications.policy.contract.yaml`)
- Provider credentials for the active live route (for example `RESEND_API_KEY` or `TWILIO_*`)
- No global `secrets.namespace.status` dependency for queue flush/dispatch surfaces

## Canonical Commands

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run communications.stack.status
./bin/ops cap run communications.mailboxes.list
./bin/ops cap run communications.mail.search --query "*" --top 5
./ops/plugins/communications/bin/communications-mail-archiver-import-monitor --json
echo "yes" | ./bin/ops cap run communications.mail.send.test --to ronny@mintprints.com --subject "pilot test" --body "hello" --execute
./bin/ops cap run communications.provider.status
./bin/ops cap run communications.policy.status
./bin/ops cap run communications.templates.list --channel sms
./bin/ops cap run communications.alerts.dispatcher.status
echo "yes" | ./bin/ops cap run communications.alerts.dispatcher.start
preview_json="$(./bin/ops cap run communications.send.preview --channel sms --message-type payment_needed --to +15551234567 --consent-state opted-in --vars-json '{\"customer_name\":\"Test\",\"order_number\":\"30020\",\"balance_amount\":\"150.00\",\"payment_link\":\"https://example.com/pay\"}' --json)"
preview_id="$(echo \"$preview_json\" | jq -r '.data.preview_id')"
echo "yes" | ./bin/ops cap run communications.send.execute --preview-id "$preview_id" --execute
./bin/ops cap run communications.delivery.log --limit 10
./bin/ops cap run communications.delivery.anomaly.status
echo "yes" | ./bin/ops cap run communications.delivery.anomaly.dispatch --dry-run
echo "yes" | ./bin/ops cap run communications.alerts.deadletter.replay --limit 10
```

## Lifecycle Runbook

Cross-domain Tailscale + SSH lifecycle SOP (auth incident, onboarding checklist, monitor behavior, tombstones):

- `docs/governance/TAILSCALE_SSH_LIFECYCLE_OPERATIONS_RUNBOOK.md`

## Evidence Pattern

- Send-test artifact path:
  - `$SPINE_OUTBOX/communications/communications-send-test-last.yaml`
- Transactional execution artifact path:
  - `$SPINE_OUTBOX/communications/communications-transaction-last.yaml`
- Transactional append-only delivery log:
  - `$SPINE_OUTBOX/communications/communications-delivery-log.jsonl`
- Preview linkage receipts:
  - `$SPINE_OUTBOX/communications/previews/*.json`
- Delivery anomaly alerts:
  - `mailroom/outbox/alerts/communications/ALERT-*.yaml`
- Delivery confirmation pattern:
  - Query `microsoft.mail.search` for unique send-test subject token.
