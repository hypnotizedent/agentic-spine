## mailroom/ — governed runtime

- Queues: `inbox/queued` (pending), `inbox/running` (in-flight), `inbox/done`, `inbox/failed`, `inbox/parked` (manual unblock), `inbox/archived`.
- Results: `outbox/` (`<run_key>__RESULT.md`), logs in `logs/`, ledger + loop scopes in `state/`.
- Receipts: **canonical** path is `receipts/sessions/RCAP-*/receipt.md` (per `docs/core/RECEIPTS_CONTRACT.md`). The former `mailroom/receipts/` location has been removed to avoid split-brain.
- Canonical operations/runbook: `docs/governance/MAILROOM_RUNBOOK.md`.
- Watcher: launchd `com.ronny.agent-inbox`; never run watcher directly—use `./bin/ops cap run spine.watcher.status` or `spine.status`.
