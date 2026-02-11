## mailroom/ — governed runtime

**Architecture:** Ledger-driven with file-queue lanes. The append-only ledger
(`state/ledger.csv`) is the audit trail for every run transition. Files move through
inbox lanes (`queued/ → running/ → done/failed/parked`) as the operational surface,
but the ledger is the source of truth for run history and status.

- **Queues (file lanes):** `inbox/queued` (pending), `inbox/running` (in-flight), `inbox/done`, `inbox/failed`, `inbox/parked` (manual unblock), `inbox/archived`.
- **Ledger:** `state/ledger.csv` — append-only CSV recording all run transitions (created, started, finished). Every status change adds a row. Query with `./bin/ops cap run spine.status`.
- **Results:** `outbox/` (`<run_key>__RESULT.md`), logs in `logs/`, loop scopes in `state/loop-scopes/`.
- **Receipts:** canonical path is `receipts/sessions/R<run_key>/receipt.md` (per `docs/core/RECEIPTS_CONTRACT.md`). The former `mailroom/receipts/` location has been removed to avoid split-brain.
- **Components:** Watcher (daemon, processes queued prompts) + Bridge (optional HTTP API for remote access). See `docs/governance/MAILROOM_RUNBOOK.md` for details.
- **Watcher:** launchd `com.ronny.agent-inbox`; never run watcher directly — use `./bin/ops cap run spine.watcher.status` or `spine.status`.
